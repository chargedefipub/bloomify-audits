// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

/** 
 * @dev Common data and variables for strategy settings
 */
library StrategySettings {

    // Avalaible Actions for Blocks
    uint256 constant NONE = 0;
    uint256 constant TAKE_PROFIT = 1;
    uint256 constant AUTOCOMPOUND = 2;
    uint256 constant REINVEST = 3;

    /**
     * Represents an action to apply to a block
     */
    struct Action { 
        // The token to apply the action to
        address token;

        // The action to apply (see constants above)
        uint256 action;

        // The percentage to use - 1% = 100
        uint256 percent;

        // The block Id to divert the action to.
        // Block Ids start from 0
        uint256 toBlockId;
    }

    /**
     * Represents a fail action to apply to a block
     */
    struct FailAction { 
        // The action to apply (see constants above)
        uint256 action;

        // The block Id to divert the action to.
        // Block Ids start from 0
        uint256 toBlockId;
    }

    /**
     * Represents an adaptor config for strategy creation
     */
    struct Adaptor {
        // The adaptor type. See the adaptors section in
        // StratConfigLookUpKeys.sol
        uint256 adaptorType;

        // The out tokens configuration. This is specific to 
        // the adaptor type
        address[] outConfig;
    }
}