// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IRewardPool {
    function notifyRewardAmount(uint256 amount) external;
    function transferOwnership(address owner) external;
}