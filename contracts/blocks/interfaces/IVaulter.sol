// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

/** 
 * @title Common vault functions
 * @dev Use this if the block "is a" Vault
 */
interface IVaulter {

    /**
     * @dev Returns input type of the blocks withawal function.
     * 
     * Underlying vaults usually accept share tokens, however we have some block
     * implementations that take the want as input and converts it into shares.
     * 
     * Accepted return values
     * 0 = Want
     * 1 = Share
     */
    function withdrawalInputType() external view returns (uint256);

    /**
     * @dev Returns the balance in the vault's want token
     */
    function wantBalance() external view returns (uint256);

    /**
     * @dev Returns the balance in Shares rather than the underlying want token value
     */
    function shareBalance() external view returns (uint256);

    /**
     * @dev Converts the Share amount into the Want amount
     */
    function sharesToWant(uint256 _shareAmount) external view returns (uint256);

    /**
     * @dev Converts the Want amount into the Share amount
     */
    function wantToShares(uint256 _wantAmount) external view returns (uint256);

}