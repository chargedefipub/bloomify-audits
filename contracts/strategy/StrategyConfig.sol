// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

import '@openzeppelin/contracts/access/AccessControlEnumerable.sol';

/** 
 * @title Data for Strategy Runner and Block configuration
 * @dev This data is used to initialize the Blocks and StrategyRunner.
 *
 *  - The blocks require contract addresses where the data stored using known keys.
 *    See StratConfigLookUpKeys.sol for loop keys (identifers)
 *
 *  - The StrategyRunner default config is stored and controlled here. Use this
 *    to config the start state of clone contracts
 */
contract StrategyConfig is AccessControlEnumerable {

    // =============== Strategy Config Addresses ===============
    mapping (uint256 => address) registry;
    uint256[] public registeredIds;

    // =============== Strategy Runner Defaults ===============
    bool public onlyOwnerCanRun = false;
    bool public revertRunOnFailure = false;
    uint256 public accumFeesUsedLimit = type(uint256).max;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    
    // =============== Strategy Config Addresses Functions ===============
    /**
     * @notice Looks up an address based on the given identifier
     */
    function lookup(uint256 _identififer) external view returns(address) {
        return registry[_identififer];
    }

    /**
     * @notice To add a new record. 
     * @dev A safe way of adding records. This should always be used because it will
     *  prevent overwriting existing records by accident. Use the update function
     *  if you are fully aware you are changing an existing record
     */
    function add(uint _identifer, address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(registry[_identifer] == address(0), "Duplicate record");
        registeredIds.push(_identifer);
        registry[_identifer] = _address;
    }

    /**
     * @notice Updates a record
     * @dev No checking is perform. Records will be overwritten!
     */
    function update(uint _identifer, address _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
        registry[_identifer] = _address;
    }

    // =============== Strategy Runner Defaults Funtions ===============

    function setOnlyOwnerCanRun(bool _ownerOnly) external onlyRole(DEFAULT_ADMIN_ROLE) {
        onlyOwnerCanRun = _ownerOnly;
    }

    function setRevertRunOnFailure(bool _ownerOnly) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revertRunOnFailure = _ownerOnly;
    }

    function setAccumFeesUsedLimit(uint256 _newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        accumFeesUsedLimit = _newLimit;
    }
}