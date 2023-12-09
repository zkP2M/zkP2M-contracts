//SPDX-License-Identifier: MIT

// import { StringUtils } from "@zk-email/contracts/utils/StringUtils.sol";

import { BaseProcessor } from "./BaseProcessor.sol";
// import { Groth16Verifier } from "../verifiers/upi_registration_verifier.sol";
import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";
import { IRegistrationProcessor } from "../interfaces/IRegistrationProcessor.sol";

pragma solidity ^0.8.18;

contract UPIRegistrationProcessor is IRegistrationProcessor, BaseProcessor {

    // using StringUtils for uint256[];

    /* ============ Constants ============ */
    uint256 constant public PACK_SIZE = 7;
    
    /* ============ Constructor ============ */
    constructor(
        address _ramp,
        INullifierRegistry _nullifierRegistry
    )
        BaseProcessor(_ramp, _nullifierRegistry)
    {}

    /* ============ External Functions ============ */

    function processProof(
        IRegistrationProcessor.RegistrationProof calldata _proof
    )
        public
        view
        override
        onlyRamp
        returns(bytes32 userIdHash)
    {
        // require(this.verifyProof(_proof.a, _proof.b, _proof.c, _proof.signals), "Invalid Proof"); // checks effects iteractions, this should come first

        // Signals [4] is the packed onRamperIdHash
        userIdHash = bytes32(_proof.signals[0]);
    }

    /* ============ Internal Functions ============ */


}
