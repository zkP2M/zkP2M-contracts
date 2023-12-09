//SPDX-License-Identifier: MIT

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Bytes32ArrayUtils } from "./external/Bytes32ArrayUtils.sol";
import { Uint256ArrayUtils } from "./external/Uint256ArrayUtils.sol";

import { IPoseidon3 } from "./interfaces/IPoseidon3.sol";
import { IPoseidon6 } from "./interfaces/IPoseidon6.sol";
import { IRegistrationProcessor } from "./interfaces/IRegistrationProcessor.sol";
import { IUPISendProcessor } from "./interfaces/IUPISendProcessor.sol";

pragma solidity ^0.8.18;

contract UPIRamp is Ownable {

    using Bytes32ArrayUtils for bytes32[];
    using Uint256ArrayUtils for uint256[];

    /* ============ Structs ============ */

    struct AccountInfo {
        bytes32 idHash;                     
        uint256[] deposits;                 
    }

    struct Deposit {
        address depositor;
        uint256[8] upiId;
        uint256 depositAmount;              
        uint256 remainingDeposits;          
        uint256 outstandingIntentAmount;    
        uint256 conversionRate;             
        bytes32[] intentHashes;             
    }

    struct DepositWithAvailableLiquidity {
        uint256 depositId;                  
        Deposit deposit;                    
        uint256 availableLiquidity;         
    }

    struct Intent {
        address onRamper;                   
        address to;                         
        uint256 deposit;                    
        uint256 amount;                     
        uint256 intentTimestamp;            
    }

    struct IntentWithOnRamperId {
        Intent intent;                      
        bytes32 onRamperIdHash;             
    }

    struct DenyList {
        bytes32[] deniedUsers;              
        mapping(bytes32 => bool) isDenied;  
    }

    struct GlobalAccountInfo {
        bytes32 currentIntentHash;          
        uint256 lastOnrampTimestamp;        
        DenyList denyList;                  
    }

    /* ============ Modifiers ============ */
    modifier onlyRegisteredUser() {
        require(accounts[msg.sender].idHash != bytes32(0), "Caller must be registered user");
        _;
    }

    /* ============ Constants ============ */
    uint256 internal constant PRECISE_UNIT = 1e18;
    uint256 internal constant MAX_DEPOSITS = 5;       // An account can only have max 5 different deposit parameterizations to prevent locking funds
    uint256 constant CIRCOM_PRIME_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant MAX_SUSTAINABILITY_FEE = 5e16;   // 5% max sustainability fee
    
    /* ============ State Variables ============ */
    IERC20 public immutable usdc;
    IPoseidon3 public immutable poseidon3;
    IPoseidon6 public immutable poseidon6;
    IRegistrationProcessor public registrationProcessor;
    IUPISendProcessor public sendProcessor;

    bool internal isInitialized;

    mapping(bytes32 => GlobalAccountInfo) internal globalAccount;
    mapping(address => AccountInfo) internal accounts;
    mapping(uint256 => Deposit) public deposits;
    mapping(bytes32 => Intent) public intents;

    uint256 public minDepositAmount;
    uint256 public maxOnRampAmount;
    uint256 public onRampCooldownPeriod;
    uint256 public intentExpirationPeriod;
    uint256 public sustainabilityFee;
    address public sustainabilityFeeRecipient;

    uint256 public depositCounter;

    /* ============ Constructor ============ */
    constructor(
        address _owner,
        IERC20 _usdc,
        IPoseidon3 _poseidon3,
        IPoseidon6 _poseidon6,
        uint256 _minDepositAmount,
        uint256 _maxOnRampAmount,
        uint256 _intentExpirationPeriod,
        uint256 _onRampCooldownPeriod,
        uint256 _sustainabilityFee,
        address _sustainabilityFeeRecipient
    )
        Ownable()
    {
        usdc = _usdc;
        poseidon3 = _poseidon3;
        poseidon6 = _poseidon6;
        minDepositAmount = _minDepositAmount;
        maxOnRampAmount = _maxOnRampAmount;
        intentExpirationPeriod = _intentExpirationPeriod;
        onRampCooldownPeriod = _onRampCooldownPeriod;
        sustainabilityFee = _sustainabilityFee;
        sustainabilityFeeRecipient = _sustainabilityFeeRecipient;

        transferOwnership(_owner);
    }

    /* ============ External Functions ============ */

    function initialize(
        IRegistrationProcessor _registrationProcessor,
        IUPISendProcessor _sendProcessor
    )
        external
        onlyOwner
    {
        require(!isInitialized, "Already initialized");

        registrationProcessor = _registrationProcessor;
        sendProcessor = _sendProcessor;

        isInitialized = true;
    }

    function register(
        uint[2] memory _a,
        uint[2][2] memory _b,
        uint[2] memory _c,
        uint[1] memory _signals
    )
        external
    {
        require(accounts[msg.sender].idHash == bytes32(0), "Account already associated with idHash");
        bytes32 idHash = _verifyRegistrationProof(_a, _b, _c, _signals);

        accounts[msg.sender].idHash = idHash;

    }

    function offRamp(
        uint256[8] memory _upiId,
        uint256 _depositAmount,
        uint256 _receiveAmount
    )
        external
        onlyRegisteredUser
    {
        require(accounts[msg.sender].deposits.length < MAX_DEPOSITS, "Maximum deposit amount reached");
        require(_depositAmount >= minDepositAmount, "Deposit amount must be greater than min deposit amount");
        require(_receiveAmount > 0, "Receive amount must be greater than 0");

        uint256 conversionRate = (_depositAmount * PRECISE_UNIT) / _receiveAmount;
        uint256 depositId = depositCounter++;

        AccountInfo storage account = accounts[msg.sender];
        account.deposits.push(depositId);

        deposits[depositId] = Deposit({
            depositor: msg.sender,
            upiId: _upiId,
            depositAmount: _depositAmount,
            remainingDeposits: _depositAmount,
            outstandingIntentAmount: 0,
            conversionRate: conversionRate,
            intentHashes: new bytes32[](0)
        });

        usdc.transferFrom(msg.sender, address(this), _depositAmount);

    }

    function signalIntent(uint256 _depositId, uint256 _amount, address _to) external onlyRegisteredUser {
        bytes32 idHash = accounts[msg.sender].idHash;
        Deposit storage deposit = deposits[_depositId];
        bytes32 depositorIdHash = accounts[deposit.depositor].idHash;

        // Caller validity checks
        require(!globalAccount[depositorIdHash].denyList.isDenied[idHash], "Onramper on depositor's denylist");
        require(
            globalAccount[idHash].lastOnrampTimestamp + onRampCooldownPeriod <= block.timestamp,
            "On ramp cool down period not elapsed"
        );
        require(globalAccount[idHash].currentIntentHash == bytes32(0), "Intent still outstanding");
        require(depositorIdHash != idHash, "Sender cannot be the depositor");

        // Intent information checks
        require(deposit.depositor != address(0), "Deposit does not exist");
        require(_amount > 0, "Signaled amount must be greater than 0");
        require(_amount <= maxOnRampAmount, "Signaled amount must be less than max on-ramp amount");
        require(_to != address(0), "Cannot send to zero address");

        bytes32 intentHash = _calculateIntentHash(idHash, _depositId);

        if (deposit.remainingDeposits < _amount) {
            (
                bytes32[] memory prunableIntents,
                uint256 reclaimableAmount
            ) = _getPrunableIntents(_depositId);

            require(deposit.remainingDeposits + reclaimableAmount >= _amount, "Not enough liquidity");

            _pruneIntents(deposit, prunableIntents);
            deposit.remainingDeposits += reclaimableAmount;
            deposit.outstandingIntentAmount -= reclaimableAmount;
        }

        intents[intentHash] = Intent({
            onRamper: msg.sender,
            to: _to,
            deposit: _depositId,
            amount: _amount,
            intentTimestamp: block.timestamp
        });

        globalAccount[idHash].currentIntentHash = intentHash;

        deposit.remainingDeposits -= _amount;
        deposit.outstandingIntentAmount += _amount;
        deposit.intentHashes.push(intentHash);

    }

    function onRamp(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[3] memory _signals
    )
        external
    {
        (
            Intent memory intent,
            Deposit storage deposit,
            bytes32 intentHash
        ) = _verifyOnRampProof(_a, _b, _c, _signals);

        _pruneIntent(deposit, intentHash);

        deposit.outstandingIntentAmount -= intent.amount;
        globalAccount[accounts[intent.onRamper].idHash].lastOnrampTimestamp = block.timestamp;
        _closeDepositIfNecessary(intent.deposit, deposit);

        _transferFunds(intentHash, intent);
    }

    /* ============ Governance Functions ============ */

    function setSendProcessor(IUPISendProcessor _sendProcessor) external onlyOwner {
        sendProcessor = _sendProcessor;
    }

    function setRegistrationProcessor(IRegistrationProcessor _registrationProcessor) external onlyOwner {
        registrationProcessor = _registrationProcessor;
    }

    function setMaxOnRampAmount(uint256 _maxOnRampAmount) external onlyOwner {
        require(_maxOnRampAmount != 0, "Max on ramp amount cannot be zero");

        maxOnRampAmount = _maxOnRampAmount;
    }


    /* ============ External View Functions ============ */

    function getDeposit(uint256 _depositId) external view returns (Deposit memory) {
        return deposits[_depositId];
    }

    function getAccountInfo(address _account) external view returns (AccountInfo memory) {
        return accounts[_account];
    }

    function getIdCurrentIntentHash(address _account) external view returns (bytes32) {
        return globalAccount[accounts[_account].idHash].currentIntentHash;
    }

    function getLastOnRampTimestamp(address _account) external view returns (uint256) {
        return globalAccount[accounts[_account].idHash].lastOnrampTimestamp;
    }

    function getDepositFromIds(uint256[] memory _depositIds) external view returns (DepositWithAvailableLiquidity[] memory depositArray) {
        depositArray = new DepositWithAvailableLiquidity[](_depositIds.length);

        for (uint256 i = 0; i < _depositIds.length; ++i) {
            uint256 depositId = _depositIds[i];
            Deposit memory deposit = deposits[depositId];
            ( , uint256 reclaimableAmount) = _getPrunableIntents(depositId);

            depositArray[i] = DepositWithAvailableLiquidity({
                depositId: depositId,
                deposit: deposit,
                availableLiquidity: deposit.remainingDeposits + reclaimableAmount
            });
        }

        return depositArray;
    }

    /* ============ Internal Functions ============ */

    function _calculateIntentHash(
        bytes32 _idHash,
        uint256 _depositId
    )
        internal
        view
        virtual
        returns (bytes32 intentHash)
    {
        // Mod with circom prime field to make sure it fits in a 254-bit field
        uint256 intermediateHash = uint256(keccak256(abi.encodePacked(_idHash, _depositId, block.timestamp)));
        intentHash = bytes32(intermediateHash % CIRCOM_PRIME_FIELD);
    }

    function _getPrunableIntents(
        uint256 _depositId
    )
        internal
        view
        returns(bytes32[] memory prunableIntents, uint256 reclaimedAmount)
    {
        bytes32[] memory intentHashes = deposits[_depositId].intentHashes;
        prunableIntents = new bytes32[](intentHashes.length);

        for (uint256 i = 0; i < intentHashes.length; ++i) {
            Intent memory intent = intents[intentHashes[i]];
            if (intent.intentTimestamp + intentExpirationPeriod < block.timestamp) {
                prunableIntents[i] = intentHashes[i];
                reclaimedAmount += intent.amount;
            }
        }
    }

    function _pruneIntents(Deposit storage _deposit, bytes32[] memory _intents) internal {
        for (uint256 i = 0; i < _intents.length; ++i) {
            if (_intents[i] != bytes32(0)) {
                _pruneIntent(_deposit, _intents[i]);
            }
        }
    }

    function _pruneIntent(Deposit storage _deposit, bytes32 _intentHash) internal {
        Intent memory intent = intents[_intentHash];

        delete globalAccount[accounts[intent.onRamper].idHash].currentIntentHash;
        delete intents[_intentHash];
        _deposit.intentHashes.removeStorage(_intentHash);

    }

    function _closeDepositIfNecessary(uint256 _depositId, Deposit storage _deposit) internal {
        uint256 openDepositAmount = _deposit.outstandingIntentAmount + _deposit.remainingDeposits;
        if (openDepositAmount == 0) {
            accounts[_deposit.depositor].deposits.removeStorage(_depositId);
            delete deposits[_depositId];
        }
    }

    function _transferFunds(bytes32 _intentHash, Intent memory _intent) internal {
        uint256 fee;
        if (sustainabilityFee != 0) {
            fee = (_intent.amount * sustainabilityFee) / PRECISE_UNIT;
            usdc.transfer(sustainabilityFeeRecipient, fee);
        }

        uint256 onRampAmount = _intent.amount - fee;
        usdc.transfer(_intent.to, onRampAmount);

    }

    function _verifyOnRampProof(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[3] memory _signals
    )
        internal
        returns(Intent memory, Deposit storage, bytes32)
    {
        (
            uint256 amount,
            uint256 timestamp,
            bytes32 intentHash
        ) = sendProcessor.processProof(
            IUPISendProcessor.SendProof({
                a: _a,
                b: _b,
                c: _c,
                signals: _signals
            })
        );

        Intent memory intent = intents[intentHash];
        Deposit storage deposit = deposits[intent.deposit];

        require(intent.onRamper != address(0), "Intent does not exist");
        require(intent.intentTimestamp <= timestamp, "Intent was not created before send");
        require(amount >= (intent.amount * PRECISE_UNIT) / deposit.conversionRate, "Payment was not enough");

        return (intent, deposit, intentHash);
    }

    function _verifyRegistrationProof(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[1] memory _signals
    )
        internal
        view
        returns(bytes32)
    {
        bytes32 idHash = registrationProcessor.processProof(
            IRegistrationProcessor.RegistrationProof({
                a: _a,
                b: _b,
                c: _c,
                signals: _signals
            })
        );

        return idHash;
    }
}