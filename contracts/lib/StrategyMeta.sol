// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

import "../interfaces/IStrategyRunner.sol";

/** 
 * @dev Common data and variables for strategy settings
 */
library StrategyMeta {

    /**
     * @dev Used by the registry to store info on a user strategy
     */
    struct StratInfo { 
        // The strategies created by the user
        IStrategyRunner[] strats;

        // The tags to ieentify each strategy
        uint256[] stratTags;
    }
}