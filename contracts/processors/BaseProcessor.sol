//SPDX-License-Identifier: MIT

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";

pragma solidity ^0.8.18;

contract BaseProcessor is Ownable {

    /* ============ Modifiers ============ */
    modifier onlyRamp() {
        require(msg.sender == ramp, "Only Ramp can call this function");
        _;
    }

    /* ============ State Variables ============ */
    address public immutable ramp;
    INullifierRegistry public nullifierRegistry;
    bytes public emailFromAddress;

    /* ============ Constructor ============ */
    constructor(
        address _ramp,
        INullifierRegistry _nullifierRegistry
    )
        Ownable()
    {
        ramp = _ramp;
        nullifierRegistry = _nullifierRegistry;
    }

    /* ============ External Functions ============ */

    /* ============ External Getters ============ */

    /* ============ Internal Functions ============ */

    function _validateAndAddNullifier(bytes32 _nullifier) internal {
        require(!nullifierRegistry.isNullified(_nullifier), "Nullifier has already been used");
        nullifierRegistry.addNullifier(_nullifier);
    }
}
