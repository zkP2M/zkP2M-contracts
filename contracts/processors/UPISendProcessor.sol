//SPDX-License-Identifier: MIT

// import { StringUtils } from "@zk-email/contracts/utils/StringUtils.sol";

import { DateTime } from "../external/DateTime.sol";

import { BaseProcessor } from "./BaseProcessor.sol";
// import { Groth16Verifier } from "../verifiers/upi_send_verifier.sol";
import { INullifierRegistry } from "./nullifierRegistries/INullifierRegistry.sol";
import { IUPISendProcessor } from "../interfaces/IUPISendProcessor.sol";
// import { StringConversionUtils } from "../lib/StringConversionUtils.sol";

pragma solidity ^0.8.18;

contract UPISendProcessor is  IUPISendProcessor, BaseProcessor {
    
    // using StringUtils for uint256[];
    // using StringConversionUtils for string;

    /* ============ Constants ============ */
    uint256 constant PACK_SIZE = 7;
    uint256 constant IST_OFFSET = 19800;

    /* ============ Constructor ============ */
    constructor(
        address _ramp,
        INullifierRegistry _nullifierRegistry
    )
        BaseProcessor(_ramp, _nullifierRegistry)
    {}
    
    /* ============ External Functions ============ */
    function processProof(
        IUPISendProcessor.SendProof calldata _proof
    )
        public
        override
        onlyRamp
        returns(
            uint256 amount,
            uint256 timestamp,
            bytes32 intentHash
        )
    {
        // require(this.verifyProof(_proof.a, _proof.b, _proof.c, _proof.signals), "Invalid Proof"); // checks effects iteractions, this should come first

        amount = _proof.signals[0];

        // string memory rawTimestamp = _parseSignalArray(_proof.signals, 6, 11);
        timestamp = _proof.signals[1];

        
        // Check if email has been used previously, if not nullify it so it can't be used again
        // _validateAndAddNullifier(bytes32(_proof.signals[2]));

        // Signals [4] is intentHash
        intentHash = bytes32(_proof.signals[2]);
    }
    
}
