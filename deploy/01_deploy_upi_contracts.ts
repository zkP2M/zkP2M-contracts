import "module-alias/register";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { ether, usdc } from "@utils/common/units";

const circom = require("circomlibjs");
import {
  INTENT_EXPIRATION_PERIOD,
  MAX_ONRAMP_AMOUNT,
  MIN_DEPOSIT_AMOUNT,
  MULTI_SIG,
  ONRAMP_COOL_DOWN_PERIOD,
  SUSTAINABILITY_FEE,
  SUSTAINABILITY_FEE_RECIPIENT,
  USDC_MINT_AMOUNT,
  USDC,
} from "../deployments/parameters";
import { getDeployedContractAddress, setNewOwner } from "../deployments/helpers";
import { PaymentProviders } from "../utils/types";

// Deployment Scripts
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deploy } = await hre.deployments
  const network = hre.deployments.getNetworkName();

  const [deployer, onRamper] = await hre.getUnnamedAccounts();
  console.log('Deploying contracts with the account:', deployer);
  const multiSig = MULTI_SIG[network] ? MULTI_SIG[network] : deployer;
  const paymentProvider = PaymentProviders.UPI;

  let usdcAddress;
  if (!USDC[network]) {
    const usdcToken = await deploy("USDCMock", {
      from: deployer,
      args: [USDC_MINT_AMOUNT, "USDC", "USDC"],
    });
    usdcAddress = usdcToken.address;
    console.log("USDC deployed...");
  } else {
    usdcAddress = USDC[network];
  }

  const poseidon = await deploy("Poseidon3", {
    from: deployer,
    contract: {
      abi: circom.poseidonContract.generateABI(3),
      bytecode: circom.poseidonContract.createCode(3),
    }
  });
  console.log("Poseidon3 deployed at ", poseidon.address);

  const poseidon6 = await deploy("Poseidon6", {
    from: deployer,
    contract: {
      abi: circom.poseidonContract.generateABI(6),
      bytecode: circom.poseidonContract.createCode(6),
    }
  });
  console.log("Poseidon6 deployed at ", poseidon6.address);

  const upiRamp = await deploy("UPIRamp", {
    from: deployer,
    args: [
      deployer,
      usdcAddress,
      getDeployedContractAddress(network, "Poseidon3"),
      poseidon6.address,
      MIN_DEPOSIT_AMOUNT[paymentProvider][network],
      MAX_ONRAMP_AMOUNT[paymentProvider][network],
      INTENT_EXPIRATION_PERIOD[paymentProvider][network],
      ONRAMP_COOL_DOWN_PERIOD[paymentProvider][network],
      SUSTAINABILITY_FEE[paymentProvider][network],
      SUSTAINABILITY_FEE_RECIPIENT[paymentProvider][network] != ""
        ? SUSTAINABILITY_FEE_RECIPIENT[paymentProvider][network]
        : deployer,
      deployer    // offChainVerifier
    ],
  });
  console.log("upiRamp deployed at ", upiRamp.address);


  const nullifierRegistry = await deploy("NullifierRegistry", {
    from: deployer,
    args: [],
  });
  console.log("Nullifier deployed at ", nullifierRegistry.address);


  const registrationProcessor = await deploy("UPIRegistrationProcessor", {
    from: deployer,
    args: [upiRamp.address, nullifierRegistry.address,],
  });
  console.log("RegistrationProcessor deployed at ", registrationProcessor.address);

  const sendProcessor = await deploy("UPISendProcessor", {
    from: deployer,
    args: [upiRamp.address, nullifierRegistry.address],
  });
  console.log("SendProcessor deployed at ", sendProcessor.address);
  console.log("Processors deployed...");

  const upiRampContract = await ethers.getContractAt("UPIRamp", upiRamp.address);
  await upiRampContract.initialize(
    registrationProcessor.address,
    sendProcessor.address
  );

  console.log("upiRamp initialized...");

  const nullifierRegistryContract = await ethers.getContractAt("NullifierRegistry", nullifierRegistry.address);
  await nullifierRegistryContract.addWritePermission(sendProcessor.address);

  console.log("NullifierRegistry permissions added...");

  // Register merchant
  await upiRampContract.registerWithoutProof("c4bTc9bMwdE8xe");

  // Get Id Hash
  const accountInfo = await upiRampContract.getAccountInfo(deployer);
  console.log("On-chain RazorPay Key: ", accountInfo.idHash);

  // convert bytes32 to string
  const idHash = ethers.utils.parseBytes32String(accountInfo.idHash);
  console.log("On-chain RazorPay Key: ", idHash);

  // Appprove USDC

  // Create deposits as part of deploy script
  const usdcContract = await ethers.getContractAt("USDCMock", usdcAddress);
  await usdcContract.approve(upiRamp.address, usdc(10));
  await upiRampContract.offRamp(
    "sachin3929@paytm",
    usdc(10),
    usdc(830)
  );

  // Get deposits from the contract
  const deposits = await upiRampContract.getDeposit(0);
  console.log("Deposit 0: ", deposits);

  // // Get best rates
  const values = await upiRampContract.getBestRate("5000000");
  console.log(values)

  console.log("Deploy finished...");

  // Register user
  const onRamperSigner = ethers.provider.getSigner(onRamper);
  // await upiRampContract.connect(onRamperSigner).registerWithoutProof("sachin@zkp2m");

  // Signal intent as an on-ramper
  await upiRampContract.connect(onRamperSigner).signalIntent(
    0,
    usdc(1),
    onRamper
  );

  // Get intent hash
  const idHashBytes = ethers.utils.formatBytes32String("sachin@zkp2m");
  const intentHash = await upiRampContract.getIdCurrentIntentHash(onRamper);
  console.log(intentHash);

  // On-ramp using off-chain verifier
  const offchainVerifierSigner = ethers.provider.getSigner(deployer);
  const blockTimestamp = (await ethers.provider.getBlock('latest')).timestamp;
  await upiRampContract.connect(offchainVerifierSigner).onRampWithoutProof(
    intentHash,
    "83000000",
    blockTimestamp,
    "sachin3929@paytm"
  );
};

export default func;
