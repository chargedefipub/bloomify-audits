// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

import '../lib/StrategySettings.sol';
import '@openzeppelin/contracts/utils/introspection/IERC165.sol';

/** 
 * @dev For interaction directly with blocks in the strategy
 */
interface IBlock is IERC165 {

    function initialize(address _strategyConfig) external;

    function tag() external view returns (uint256);

    function setTag(uint256 _strategyTag) external;

    function setDepositAdaptors(StrategySettings.Adaptor[] memory _adaptors) external;

    function depositPush(address _token, uint256 _amount, uint256 _minOutAmount) external returns (bool);

    function depositPull(address _token, uint256 _amount, uint256 _minOutAmount) external returns (bool);

    function depositPullFrom(address _sender, address _token, uint256 _amount, uint256 _minOutAmount) external returns (bool);

    function depositEther(uint256 _minOutAmount) external payable returns (bool);

    function depositEtherSelf(uint256 _amount, uint256 _minOutAmount) external returns (bool);
    
    function transferEther(uint256 _amount) external;

    function withdrawAll() external returns (bool);

    function withdraw(uint256 _amount) external returns (bool);

    function run() external returns (bool);

    function getDepositToken() external view returns (address);

    function getOutTokens() external view returns (address[] memory);

    function getAllTokens() external view returns (address[] memory);

    function isLPToken(address _token) external view returns (bool);
    
    function balance() external view returns (uint256);

    function approveTokens() external;

    function approveSpendIfNoAllowance(address _spender, address _token, uint256 _amount) external;
}