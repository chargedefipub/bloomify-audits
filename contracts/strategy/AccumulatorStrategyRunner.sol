// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

import './StrategyConfig.sol';
import '../interfaces/IStrategyRunner.sol';
import '../interfaces/IBlock.sol';
import '../lib/StrategySettings.sol';
import '../lib/StratConfigLookUpKeys.sol';
import '../common/access/OwnableClone.sol';
import '../common/util/CallUtils.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '../blocks/interfaces/IVaulter.sol';

/**
 * @title Accumulator Strategy Runner
 * @dev A specific implementation of a strategy runner that takes 100% yield
 * from DEPOSIT block and invests it into ACCUMULATOR blocks that are vault banks aka banks
 *
 * ==========  Strategy Block Requirements ==========
 * All blocks in this strategy must make use of farms
 * - Farms accept an deposit
 * - Farms give out a yield token in return for the farm deposit
 * - Farm yield is harvestable
 *
 * ========== Terminology ==========
 * - Deposit = The input token into the strategy - i.e. block 0's deposit token
 * - Accumulator = The target token to generate from the deposit token. i.e. block 1+ 's deposit token
 * - Yield = The share tokens of the banks. The underlying farm reward tokens of the deposit block is converted to
 *          share tokens of a bank and this is share tokens is treated as yield.
 *
 * ========== Conditions ==========
 * - Block 0: DEPOSIT BLOCK
 *   > This is the only block that accepts user deposits.
 *   > Yield from this block is invested into the accumulator blocks
 *
 * - Blocks 1 and above: ACCUMULATOR blocks
 *   > No user deposits allowed.
 *
 * - Withdrawals
 *   > Withdrawal from deposit block is allowed - Partial or Full
 *   > Withdrawal from accumulator block is allowed but must be full amount
 */
contract AccumulatorStrategyRunner is
	IStrategyRunner,
	OwnableClone,
	ReentrancyGuard,
	AccessControlEnumerable
{
	using SafeMath for uint256;

	bytes32 public constant RUNNER_ROLE = keccak256('RUNNER_ROLE');

	IBlock[] public blocks;

	// Initialization only happens once which means blocks cannot
	// be changed after creation
	bool initialized;
	bool public vaultInitialized;
	uint256 public tag;

	// ========== Vault State ==========
	struct BlockShareInfo {
		// The accumulated yield to be distributed for each user's deposit token
		uint256 accYieldPerToken;
	}

	struct UserInfo {
		// The amount to exclude from the final yield earned by a user
		uint256 yieldDebt;
		// The amount banked by the user
		uint256 bankedAmount;
	}

	// Tracks the amounts state for each block
	mapping(uint256 => BlockShareInfo) public blockInfo;

	// Tracks deposit amounts
	uint256 public totalDeposits;
	mapping(address => uint256) public userDeposits;

	// Deposit precision for eack Block Index => Precision
	mapping(uint256 => uint256) public depositPrecision;

	// Tracks user's earnings info for each accumulator block
	mapping(uint256 => mapping(address => UserInfo)) public userInfo;

	// ========== Action Settings ==========
	// Block index => Actions
	mapping(uint256 => StrategySettings.Action[]) public settings;

	// ========== Runner Historic Info ==========
	uint256 public lastRunTime;
	uint256 public lastRunBlock;
	uint256 public numRuns;

	struct RunSnapshot {
		// Time snapshot was taken
		uint256 timestamp;
		// The balance of each block
		uint256[] blockBalance;
		// The total value of deposits since the last run.
		uint256[] deposits;
		// The total value of withdrawals since the last run.
		uint256[] withdrawals;
	}

	// Keeps track of the running deposit and withdrawals totals for each block
	uint256[] runningDeposits;
	uint256[] runningWithdrawals;

	// Stores the balance data snaphots of each run.
	// The new snaphots are appended to the end of the array.
	RunSnapshot[] snapshots;

	// The number of snapshots saved
	uint256 public numSnapshots = 0;

	uint256 constant ONE_HUNDRED_PERCENT = 10000;

	// ========== Fees ==========
	address public treasury;
	uint256 public performanceFee = 0;

	// ========== Events ==========
	event Deposit(
		address indexed user,
		uint256 timestamp,
		address token,
		uint256 amount,
		uint256 convertedAmount,
		uint256 blockIndex
	);
	event WithdrawDeposit(
		address indexed user,
		uint256 timestamp,
		uint256 amount
	);
	event WithdrawEarnings(
		address indexed user,
		uint256 timestamp,
		uint256 blockIndex,
		uint256 amount
	);
	event BlockWithdrawalFailed(
		address indexed user,
		uint256 timestamp,
		uint256 blockIndex
	);
	event WithdrawEarningsFailed(
		address indexed user,
		uint256 timestamp,
		uint256 blockIndex
	);
	event RunStrategy(address indexed user, uint256 timestamp, address runner);
	event BlockFailedToRun(
		address indexed user,
		uint256 blockIndex,
		StrategySettings.Action action,
		uint256 amount,
		string reason
	);

	// =================== Modifiers ===================
	/**
	 * @dev Modifier to make a function callable only by a certain role. In
	 * addition to checking the sender's role, `address(0)` 's role is also
	 * considered. Granting a role to `address(0)` is equivalent to enabling
	 * this role for everyone.
	 */
	modifier onlyRoleOrOpenRole(bytes32 role) {
		if (!hasRole(role, address(0))) {
			_checkRole(role, _msgSender());
		}
		_;
	}

	constructor() {
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(RUNNER_ROLE, msg.sender);
	}

	/**
	 * @dev Initialization function to be called after cloning by the StrategyFactory.
	 * This sets up the Runner and all the blocks in the strategy.
	 *
	 * ******** NOTE ********
	 * - Hack: Block 0 MUST BE THE DEPOSIT BLOCK!!!
	 * Block 0 - Can only accept REINVEST actions only
	 * Blocks 1+ - Can only accept a single NONE action
	 */
	function initialize(
		uint256 _tag,
		StrategyConfig,
		IBlock[] memory _blocks,
		StrategySettings.Adaptor[][] memory _adaptors,
		StrategySettings.Action[][] memory _settings
	) external nonReentrant {
		require(!initialized, 'Already initialized');
		require(_blocks.length > 0, 'No blocks provided');
		require(_blocks.length == _adaptors.length, 'Invalid adaptors length');

		// all blocks from 1, should be a bank
		for (uint8 i = 1; i < _blocks.length; i++) {
			require(
				IBlock(address(_blocks[i])).supportsInterface(
					type(IVaulter).interfaceId
				),
				'Bank block not IVaulter'
			);
		}
		initialized = true;
		tag = _tag;

		// Init first snapshot data for block
		snapshots.push(
			RunSnapshot(
				block.timestamp,
				new uint256[](_blocks.length),
				new uint256[](_blocks.length),
				new uint256[](_blocks.length)
			)
		);
		numSnapshots = numSnapshots.add(1);

		runningDeposits = new uint256[](_blocks.length);
		runningWithdrawals = new uint256[](_blocks.length);

		// Setup blocks data
		for (uint256 i = 0; i < _blocks.length; i++) {
			blocks.push(_blocks[i]);

			// Set tag
			_blocks[i].setTag(_tag);

			// Setup adaptors
			if (_adaptors.length > 0) {
				_blocks[i].setDepositAdaptors(_adaptors[i]);
			}

			// Approve blocks to be spenders of strat runner
			address blockInToken = _blocks[i].getDepositToken();
			if (blockInToken != address(0)) {
				SafeERC20.safeApprove(
					IERC20(blockInToken),
					address(_blocks[i]),
					type(uint256).max
				);
			}

			// Approve runner to spend tokens from blocks.
			// This is For withdrawals
			_blocks[i].approveTokens();

			//
			snapshots[0].blockBalance[i] = 0;
			snapshots[0].deposits[i] = 0;
			snapshots[0].withdrawals[i] = 0;
		}

		//Initialize the settings for each block
		_initSettings(_settings);
	}

	/**
	 * @dev Additional initialization required for Vamp Vaults
	 */
	function initializeVaultStrat(
		address _strategyOwner,
		uint256[] calldata _depositTokenPrecision
	) external nonReentrant onlyOwner {
		require(!vaultInitialized, 'Already initialized');

		transferOwnership(_strategyOwner);

		_grantRole(DEFAULT_ADMIN_ROLE, _strategyOwner);
		_grantRole(RUNNER_ROLE, _strategyOwner);

		require(
			_depositTokenPrecision.length == blocks.length,
			'Num precisions must match block length'
		);

		for (uint256 i = 0; i < _depositTokenPrecision.length; i++) {
			require(_depositTokenPrecision[i] > 0, 'Precision cannot be zero');
			depositPrecision[i] = _depositTokenPrecision[i];
		}

		vaultInitialized = true;
	}

	/* ==========================================
	 * STRATEGY EXECUTION FUNCTIONS
	 * ==========================================
	 */

	/**
	 * @notice Gets the settings of the strategy
	 */
	function getSettings()
		external
		view
		override
		returns (StrategySettings.Action[][] memory _settingsOut)
	{
		_settingsOut = new StrategySettings.Action[][](blocks.length);
		for (uint256 i = 0; i < blocks.length; i++) {
			_settingsOut[i] = settings[i];
		}
		return _settingsOut;
	}

	/**
	 * @notice Deposits tokens into the strategy.
	 * @dev Accepted tokens depends on the blocks in the strategy.
	 */
	function deposit(
		address _token, // Hack: Fixed to the Deposit Blocks input token type
		uint256 _amount,
		uint256 _blockIndex, // Hack: _blockIndex Ignored - always deposits into block 0 (deposit block)
		uint256 _minOutAmount
	) external override nonReentrant {
		require(vaultInitialized, 'Initialization incomplete');
		require(_amount > 0, 'Amount must be > 0');
		require(_blockIndex == 0, 'Deposits allowed only in block 0');

		_bankEarnings(msg.sender);

		uint256 amtBefore = IERC20(_token).balanceOf(address(this));
		SafeERC20.safeTransferFrom(
			IERC20(_token),
			msg.sender,
			address(this),
			_amount
		);
		uint256 actualAmount = IERC20(_token).balanceOf(address(this)).sub(
			amtBefore
		); // Handle reflect tokens

		// Approve the block to spend tokens if they have no allowance
		_approveIfNoAllowance(
			actualAmount,
			_token,
			address(blocks[_blockIndex])
		);

		uint256 blockBalBef = blocks[_blockIndex].balance();
		bool deposited = blocks[_blockIndex].depositPull(
			_token,
			actualAmount,
			_minOutAmount
		);
		require(deposited, 'Cannot deposit');

		uint256 amtAfterConversion = blocks[_blockIndex].balance().sub(
			blockBalBef
		);
		_updateDeposits(msg.sender, amtAfterConversion, _blockIndex);

		emit Deposit(
			msg.sender,
			block.timestamp,
			_token,
			actualAmount,
			amtAfterConversion,
			_blockIndex
		);
	}

	/**
	 * @notice Deposits native ether into the strategy.
	 */
	function depositEther(uint256 _blockIndex, uint256 _minOutAmount)
		external
		payable
		override
		nonReentrant
	{
		require(vaultInitialized, 'Initialization incomplete');
		require(msg.value > 0, 'Amount must be > 0');
		require(_blockIndex == 0, 'Deposits allowed only in block 0');

		_bankEarnings(msg.sender);

		uint256 blockBalBef = blocks[_blockIndex].balance();
		bool deposited = blocks[_blockIndex].depositEther{value: msg.value}(
			_minOutAmount
		);
		require(deposited, 'Cannot deposit');

		uint256 amtAfterConversion = blocks[_blockIndex].balance().sub(
			blockBalBef
		);
		_updateDeposits(msg.sender, amtAfterConversion, _blockIndex);

		emit Deposit(
			msg.sender,
			block.timestamp,
			address(0),
			msg.value,
			amtAfterConversion,
			_blockIndex
		);
	}

	/**
	 * @notice Withdraws full deposit amounts and all earnings from
	 * the accumulators
	 */
	function withdrawAll() external override nonReentrant {
		// ----- 1. Withdraw from deposit block
		if (userDeposits[msg.sender] > 0) {
			_withdraw(msg.sender, 0, userDeposits[msg.sender]);
		}

		// ----- 2. Withdraw accumulators from all blocks
		for (uint256 i = 1; i < blocks.length; i++) {
			_withdraw(msg.sender, i, 0);
		}
	}

	/**
	 * @dev Withdraw from the deposit block only
	 */
	function withdraw(
		uint256 _blockIndex,
		uint256 _amount // Only used for block 0
	) external override nonReentrant {
		_withdraw(msg.sender, _blockIndex, _amount);
	}

	function _withdraw(
		address _user,
		uint256 _blockIndex,
		uint256 _amount
	) private {
		require(_blockIndex < blocks.length, 'Invalid block index');

		// ----- Block 0 - Withdraw from deposit block
		if (_blockIndex == 0) {
			_withdrawDepositOnly(_user, _amount);
		}
		// ----- Blocks 1 and above -  Withdraw from accumulator block
		// Hack : Amount is ignored. The full amount must be withdrawn to avoid handling
		// additional yield tracking state due to past history and compounding share
		else {
			// b) Withdraw accumulated saved in the bank blocks
			IVaulter bankBlock = IVaulter(address(blocks[_blockIndex]));
			uint256 shareAmt = _blockEarnings(_user, _blockIndex).add(
				userInfo[_blockIndex][_user].bankedAmount
			);

			if (shareAmt > 0) {
				uint256 wantBalBef = bankBlock.wantBalance();
				uint256 amtInput = bankBlock.withdrawalInputType() == 0
					? bankBlock.sharesToWant(shareAmt)
					: shareAmt;
				bool bankSuccess = IBlock(address(bankBlock)).withdraw(
					amtInput
				);

				require(bankSuccess, 'unable to withdraw earnings');
				uint256 actualWantAmtWithdrawn = wantBalBef.sub(
					bankBlock.wantBalance()
				);

				_transferBlockTokens(
					_user,
					IBlock(address(bankBlock)),
					actualWantAmtWithdrawn
				);

				// > Reset debt & banked amounts
				_resetUserYieldDebt(_user, _blockIndex);
				userInfo[_blockIndex][_user].bankedAmount = 0;
				runningWithdrawals[_blockIndex] = runningWithdrawals[
					_blockIndex
				].add(actualWantAmtWithdrawn);

				emit WithdrawEarnings(
					_user,
					block.timestamp,
					_blockIndex,
					actualWantAmtWithdrawn
				);
			}
		}
	}

	function _withdrawDepositOnly(address _user, uint256 _amount) private {
		require(_amount > 0, 'Amount cannot be 0');
		require(_amount <= userDeposits[_user], 'Amount more than deposits');

		_bankEarnings(_user);

		uint256 blockBalBef = _getWithdrawBalBeforeAfter(
			blocks[0],
			blocks[0].getDepositToken()
		);
		bool success = blocks[0].withdraw(_amount);
		uint256 actualAmount = _getWithdrawBalBeforeAfter(
			blocks[0],
			blocks[0].getDepositToken()
		).sub(blockBalBef);
		if (success) {
			// Transfer token back to the user
			_transferBlockTokens(_user, blocks[0], actualAmount);
			totalDeposits = actualAmount < totalDeposits
				? totalDeposits.sub(actualAmount)
				: 0;
			userDeposits[_user] = actualAmount < userDeposits[_user]
				? userDeposits[_user].sub(actualAmount)
				: 0;

			_resetUserYieldDebtAllBlocks(_user);

			runningWithdrawals[0] = runningWithdrawals[0].add(actualAmount);

			emit WithdrawDeposit(_user, block.timestamp, actualAmount);
		} else {
			emit BlockWithdrawalFailed(_user, block.timestamp, 0);
		}
	}

	/**
	 * @notice Executes the strategy according to the actions supplied by the
	 *  owner when creating the strategy.
	 */
	function run()
		external
		override
		nonReentrant
		onlyRoleOrOpenRole(RUNNER_ROLE)
	{
		require(vaultInitialized, 'Initialization incomplete');

		for (uint256 i = 0; i < blocks.length; i++) {
			// ------ 1. Run the block's underlying farm - e.g. harvest reward
			blocks[i].run();

			bool processNextToken = true;
			uint256 tokenBalance;
			for (uint256 j = 0; j < settings[i].length; j++) {
				StrategySettings.Action memory action = settings[i][j];

				if (action.action == StrategySettings.NONE) {
					continue;
				}

				// Used for tracking a token change. Assumes actions are ordered
				// by tokens per block. This is enforced by the setSettings() function
				if (processNextToken) {
					tokenBalance = _getActionTokenBalance(
						blocks[i],
						action.token
					);

					if (treasury != address(0) && performanceFee > 0) {
						uint256 feeToTake = tokenBalance
							.mul(performanceFee)
							.div(ONE_HUNDRED_PERCENT);
						tokenBalance = tokenBalance.sub(feeToTake);
						SafeERC20.safeTransferFrom(
							IERC20(action.token),
							address(blocks[i]),
							treasury,
							feeToTake
						);
					}

					processNextToken = false;
				}

				if (tokenBalance == 0) {
					//Skip action processing if there was no rewards from the run
					continue;
				}

				// ------ 2(a). Calculate the amount based on the percentage set in Action
				uint256 transferAmount = (tokenBalance.mul(action.percent)).div(
					ONE_HUNDRED_PERCENT
				);
				if (
					// Means a token change coming and this is the last action to process
					(((j + 1) < settings[i].length) &&
						action.token != settings[i][j + 1].token) ||
					// If last action in array
					(j + 1) >= settings[i].length
				) {
					// Get the remaining balance
					//transferAmount = _getActionTokenBalance(blocks[i], action.token);
					processNextToken = true;
				}

				// Ensure the calculated amount doesn't exceed the remaining block balance
				uint256 remainingBalance = _getActionTokenBalance(
					blocks[i],
					action.token
				);
				if (transferAmount > remainingBalance) {
					transferAmount = remainingBalance;
				}

				// ------ 2(b). Apply the Action
				if (transferAmount > 0) {
					_handleBlockAction(i, action, transferAmount);
				}
			}
		}

		lastRunTime = block.timestamp;
		lastRunBlock = block.number;
		numRuns = numRuns.add(1);

		// Take a snapshot of the balance data
		snapshots.push(
			RunSnapshot(
				block.timestamp,
				new uint256[](blocks.length),
				new uint256[](blocks.length),
				new uint256[](blocks.length)
			)
		);
		numSnapshots = numSnapshots.add(1);

		for (uint256 i = 0; i < blocks.length; i++) {
			snapshots[numSnapshots.sub(1)].blockBalance[i] = blocks[i]
				.balance();
			snapshots[numSnapshots.sub(1)].deposits[i] = runningDeposits[i].sub(
				snapshots[numSnapshots.sub(2)].deposits[i]
			);
			snapshots[numSnapshots.sub(1)].withdrawals[i] = runningWithdrawals[
				i
			].sub(snapshots[numSnapshots.sub(2)].withdrawals[i]);
		}

		emit RunStrategy(msg.sender, block.timestamp, msg.sender);
	}

	/* ==========================================
	 * STRATEGY INFORMATION
	 * ==========================================
	 */

	/**
	 * @notice Gets the block addresses of the strategy
	 */
	function getBlocks() external view override returns (IBlock[] memory) {
		return blocks;
	}

	/**
	 * @notice Gets the total number of blocks used in this strategy
	 */
	function numBlocks() external view override returns (uint256) {
		return blocks.length;
	}

	/**
	 * @dev For receiving ether
	 */
	receive() external payable {}

	/* ==========================================
	 * BLOCK SHARE HANDLING
	 * ==========================================
	 */

	/**
	 * @dev Saves the current earnings amount so the
	 * yield debt can be reset. All earnings are saved in bank shares.
	 */
	function _bankEarnings(address _user) private {
		// Hack: Ignore first block as it's the DEPOSIT block
		for (uint256 i = 1; i < blocks.length; i++) {
			uint256 earnings = _blockEarnings(_user, i);
			if (earnings > 0) {
				userInfo[i][_user].bankedAmount = userInfo[i][_user]
					.bankedAmount
					.add(earnings);
			}
		}
	}

	/**
	 * @dev Gets the current earnings. Earnings are returned in bank shares
	 */
	function _blockEarnings(address _user, uint256 _blockIndex)
		private
		view
		returns (uint256)
	{
		if (userDeposits[_user] > 0) {
			uint256 earningsBeforeDebt = userDeposits[_user]
				.mul(blockInfo[_blockIndex].accYieldPerToken)
				.div(depositPrecision[_blockIndex]);
			if (userInfo[_blockIndex][_user].yieldDebt < earningsBeforeDebt) {
				return
					earningsBeforeDebt.sub(
						userInfo[_blockIndex][_user].yieldDebt
					);
			}
		}
		return 0;
	}

	/**
	 * @dev Resets the yield debt to start a fresh. I.e. zeros out all earnings in the block
	 */
	function _resetUserYieldDebt(address _user, uint256 _blockIndex) private {
		require(_blockIndex != 0, 'Yield Debt - Block 0 not allowed');
		userInfo[_blockIndex][_user].yieldDebt = userDeposits[_user]
			.mul(blockInfo[_blockIndex].accYieldPerToken)
			.div(depositPrecision[_blockIndex]);
	}

	/**
	 * @dev Resets the yield debt on all accumulator blocks
	 */
	function _resetUserYieldDebtAllBlocks(address _user) private {
		for (uint256 i = 1; i < blocks.length; i++) {
			_resetUserYieldDebt(_user, i);
		}
	}

	/* ==========================================
	 * BALANCES INFO
	 * ==========================================
	 */

	/**
	 * @dev Returns the balances of each block in the strategy
	 * for the msg.sender
	 */
	function getUserBalances(address _user)
		external
		view
		returns (uint256[] memory userBalances)
	{
		userBalances = new uint256[](blocks.length);
		userBalances[0] = userDeposits[_user];

		for (uint256 i = 1; i < blocks.length; i++) {
			userBalances[i] = IVaulter(address(blocks[i])).sharesToWant(
				_blockEarnings(_user, i).add(userInfo[i][_user].bankedAmount)
			);
		}
	}

	/* ==========================================
	 * SNAPSHOT INFO
	 * ==========================================
	 */

	/**
	 * @dev Returns the running total of deposits for each block.
	 */
	function getRunningDeposits() external view returns (uint256[] memory) {
		return runningDeposits;
	}

	/**
	 * @dev Returns the running total of withdrawals for each block.
	 */
	function getRunningWithdrawals() external view returns (uint256[] memory) {
		return runningWithdrawals;
	}

	/**
	 * @dev Returns the snapshots up to the limit specified in the parameter
	 * Results are ordered from oldest to newest
	 */
	function getSnapshots(uint256 _limit)
		external
		view
		returns (RunSnapshot[] memory _snapshotsData)
	{
		require(_limit > 0, 'limit cannot be zero');

		_snapshotsData = new RunSnapshot[](_limit);
		for (uint256 i = 1; i <= _limit; i++) {
			_snapshotsData[_limit.sub(i)] = snapshots[
				snapshots.length.sub((i))
			];
		}
		return _snapshotsData;
	}

	/* ==========================================
	 * ADMIN EXTERNAL CONTRACT INTERACTIONS
	 * ==========================================
	 */

	/**
	 * @notice Sets the performance fee
	 */
	function setPerformanceFee(uint256 _fee)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		performanceFee = _fee;
	}

	/**
	 * @notice Sets the treasury to collect the fees
	 */
	function setTreasury(address _treasury)
		external
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		treasury = _treasury;
	}

	/* ==========================================
	 * PRIVATE FUNCTIONS
	 * ==========================================
	 */

	/**
	 * @notice Initialises the settings in storage
	 * @dev Settings storage must be empty otherwise the new settings will be
	 *  added on top of the current ones
	 */
	function _initSettings(StrategySettings.Action[][] memory _settings)
		private
	{
		require(blocks.length == _settings.length, 'Invalid settings length');

		for (uint256 i = 0; i < _settings.length; i++) {
			uint256 numOutTokens = blocks[i].getOutTokens().length;
			if (numOutTokens > 0) {
				uint256 changes = 0;
				uint256 accumPercent = 0;
				for (uint256 j = 0; j < _settings[i].length; j++) {
					settings[i].push(_settings[i][j]);

					require(
						_settings[i][j].toBlockId < blocks.length,
						'Invalid toBlockId'
					);

					// Enforce strict setting rules for simple Vamp Vault logic
					if (i == 0) {
						require(
							_settings[i][j].action == StrategySettings.REINVEST,
							'Deposit block must use REINVEST only'
						);
					} else {
						require(
							_settings[i][j].action == StrategySettings.NONE,
							'Accumulators must use NONE only, as they are banks'
						);
						require(
							_settings[i].length == 1,
							'Accumulators only allowed 1 setting'
						);
						require(
							_settings[i][j].percent == ONE_HUNDRED_PERCENT,
							'Accumulators percentage must be 100%'
						);
					}

					// Approve blocks and runners to spend tokens based on actions.
					// Nothing needed for NONE because the tokens stays in the same block
					if (_settings[i][j].token != address(0)) {
						if (
							_settings[i][j].action == StrategySettings.REINVEST
						) {
							blocks[i].approveSpendIfNoAllowance(
								address(blocks[_settings[i][j].toBlockId]),
								_settings[i][j].token,
								type(uint256).max
							);
						}
					}

					accumPercent += _settings[i][j].percent;

					// Count the token changes. Too many or too few means
					// the tokens are not ordered
					if (
						(j + 1) < _settings[i].length &&
						_settings[i][j].token != _settings[i][(j + 1)].token
					) {
						changes++;

						// Extra percentages checks for multi out token blocks
						require(
							accumPercent == ONE_HUNDRED_PERCENT,
							'Bad percentages'
						);
						accumPercent = 0;
					}
				}
				require(changes == numOutTokens.sub(1), 'Bad token ordering');
				require(accumPercent == ONE_HUNDRED_PERCENT, 'Bad percentages');
			}
		}
	}

	/**
	 * @dev Handles an action for an block
	 *
	 * Low level calls used to prevent any block from reverting the whole run.
	 */
	function _handleBlockAction(
		uint256 _blockIndex,
		StrategySettings.Action memory _action,
		uint256 _amount
	) private returns (bool) {
		bool success;
		bytes memory result;

		IVaulter bankBlock = IVaulter(address(blocks[_action.toBlockId]));

		uint256 sharesBefore = bankBlock.shareBalance();

		// ----- This should only apply to block 0 and is a reinvest action
		if (_action.token != address(0)) {
			blocks[_blockIndex].approveSpendIfNoAllowance(
				address(blocks[_action.toBlockId]),
				_action.token,
				_amount
			);
			(success, result) = address(blocks[_action.toBlockId]).call(
				abi.encodeWithSignature(
					'depositPullFrom(address,address,uint256,uint256)',
					address(blocks[_blockIndex]),
					_action.token,
					_amount,
					0
				)
			);
		} else {
			blocks[_blockIndex].transferEther(_amount);
			(success, result) = address(blocks[_action.toBlockId]).call{
				value: _amount
			}(abi.encodeWithSignature('depositEther(uint256)', 0));

			// Send ether back to the block if failed
			if (!success) {
				(bool sent, ) = address(blocks[_blockIndex]).call{
					value: _amount
				}('');
				require(sent, 'Failed to send ether back to block');
			}
		}

		uint256 sharesIncrease = bankBlock.shareBalance().sub(sharesBefore);

		// Update the yield per share with the increase in bank shares
		// NOTE: Need to handle divide by 0 total deposit issue if allowing accumulator
		// blocks to use REINVEST function in future.
		blockInfo[_action.toBlockId].accYieldPerToken = blockInfo[
			_action.toBlockId
		].accYieldPerToken.add(
				sharesIncrease.mul(depositPrecision[_action.toBlockId]).div(
					totalDeposits
				)
			);

		if (success) {
			return abi.decode(result, (bool));
		} else {
			emit BlockFailedToRun(
				msg.sender,
				_blockIndex,
				_action,
				_amount,
				CallUtils.getRevertMsg(result)
			);
			return false;
		}
	}

	/**
	 * @dev Helper function to get the balance of a token
	 *  which could be ERC20 or native BNB/ether
	 */
	function _getActionTokenBalance(IBlock _block, address _token)
		private
		view
		returns (uint256)
	{
		if (_token != address(0)) {
			return IERC20(_token).balanceOf(address(_block));
		} else {
			return address(_block).balance;
		}
	}

	/**
	 * @dev A helper function for token approvals between the blocks and
	 *  deposit adaptors
	 */
	function _approveIfNoAllowance(
		uint256 amountToSpend,
		address _token,
		address _spender
	) private {
		uint256 allowance = IERC20(_token).allowance(address(this), _spender);
		if (allowance < amountToSpend) {
                        SafeERC20.safeApprove(IERC20(_token), _spender, 0);
			SafeERC20.safeApprove(IERC20(_token), _spender, type(uint256).max);
		}
	}

	/**
	 * @dev A helper function to transfer block tokens back to the user.
	 * Handles the ether and non ether token cases.
	 */
	function _transferBlockTokens(
		address _receiver,
		IBlock _block,
		uint256 _amount
	) private {
		// ----- Handle non ether deposit token case
		if (_block.getDepositToken() != address(0)) {
			SafeERC20.safeTransferFrom(
				IERC20(_block.getDepositToken()),
				address(_block),
				_receiver,
				_amount
			);
		}
		// ----- Handle ether deposit token case
		else {
			(bool sent, ) = payable(_receiver).call{value: _amount}('');
			require(sent, 'Failed to send Ether');
		}
	}

	/**
	 * @dev Helper function to get the balance of a token
	 *  which could be ERC20 or native BNB/ether
	 */
	function _getWithdrawBalBeforeAfter(IBlock _block, address _token)
		private
		view
		returns (uint256)
	{
		if (_token != address(0)) {
			return IERC20(_token).balanceOf(address(_block));
		} else {
			return address(this).balance;
		}
	}

	/**
	 * @dev Recalculates the user's tracked earnings and updates the
	 * general deposit state of the runner
	 */
	function _updateDeposits(
		address _user,
		uint256 _depositAmount,
		uint256 _blockIndex
	) private {
		totalDeposits = totalDeposits.add(_depositAmount);
		userDeposits[_user] = userDeposits[_user].add(_depositAmount);
		runningDeposits[_blockIndex] = runningDeposits[_blockIndex].add(
			_depositAmount
		);
		_resetUserYieldDebtAllBlocks(_user);
	}

	/* ==========================================
	 * NOT USED INTERFACE FUNCTIONS
	 * ==========================================
	 */

	// These only exists to adhere to IStrategyRunner interface

	function setSettings(StrategySettings.Action[][] memory)
		external
		pure
		override
	{
		revert('Function not supported');
	}

	function getFailedSetting(uint256)
		external
		pure
		override
		returns (StrategySettings.FailAction memory)
	{
		revert('Function not supported');
	}

	function setFailedSetting(uint256, StrategySettings.FailAction memory)
		external
		pure
		override
	{
		revert('Function not supported');
	}

	function withdrawProfit() external pure override {
		revert('Function not supported');
	}

	function profitBalance() external pure override returns (uint256) {
		revert('Function not supported');
	}
}
