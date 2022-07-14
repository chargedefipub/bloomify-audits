// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

import "../lib/StrategySettings.sol";
import "../strategy/StrategyConfig.sol";
import "../interfaces/IBlock.sol";

/** 
 * @notice Main interaction interface with the StrategyRunner
 */
interface IStrategyRunner {	

    // ============================ Initialization ============================

    function initialize(
        uint256 _strategyTag,
        StrategyConfig _strategyConfig, 
        IBlock[] memory _blocks,
        StrategySettings.Adaptor[][] memory _adaptors,
        StrategySettings.Action[][] memory _settings) external;

    // ============================ Settings ============================

    // These are for the main block action settings
    function setSettings(StrategySettings.Action[][] memory _settings) external;
    function getSettings() external view returns (StrategySettings.Action[][] memory _settings);

    // These are for choosing what happens rewards when blocks fail accept the reward investment/compounding
    function setFailedSetting(uint256 _blockIndex, StrategySettings.FailAction memory _setting) external;
    function getFailedSetting(uint256 _blockIndex) external view returns (StrategySettings.FailAction memory);

    // ============================ Tokens In/Out ============================

    function deposit(address _token, uint256 _amount, uint256 _blockIndex, uint256 _minOutAmount) external;
    function depositEther(uint256 _blockIndex, uint256 _minOutAmount) external payable;
    function withdrawAll() external;
    function withdraw(uint256 _blockIndex, uint256 _amount) external;
    function withdrawProfit() external;
    function run() external;

    // ============================ Informational ============================

    function profitBalance() external view returns (uint256);
    function getBlocks() external view returns (IBlock[] memory);
    function numBlocks() external view returns (uint256);
    function numRuns() external view returns (uint256);
    function lastRunTime() external view returns (uint256);
    function lastRunBlock() external view returns (uint256);
}