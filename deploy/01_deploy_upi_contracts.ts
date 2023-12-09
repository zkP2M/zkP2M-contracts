import "module-alias/register";

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

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

  const [deployer] = await hre.getUnnamedAccounts();
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

  // Check that owner of the contract can call the function
  // const nullifierOwner = await nullifierRegistryContract.owner();
  // if ((await hre.getUnnamedAccounts()).includes(nullifierOwner)) {
  //   await hre.deployments.rawTx({
  //     from: nullifierOwner,
  //     to: nullifierRegistryContract.address,
  //     data: nullifierRegistryContract.interface.encodeFunctionData("addWritePermission", [sendProcessor.address]),
  //   });
  // } else {
  //   console.log(
  //     `NullifierRegistry owner is not in the list of accounts, must be manually added with the following calldata:
  //     ${nullifierRegistryContract.interface.encodeFunctionData("addWritePermission", [sendProcessor.address])}
  //     `
  //   );
  // }
  // console.log("NullifierRegistry permissions added...");

  // console.log("Transferring ownership of contracts...");
  // await setNewOwner(hre, upiRampContract, multiSig);
  // await setNewOwner(
  //   hre,
  //   await ethers.getContractAt("HDFCRegistrationProcessor", registrationProcessor.address),
  //   multiSig
  // );
  // await setNewOwner(
  //   hre,
  //   await ethers.getContractAt("HDFCSendProcessor", sendProcessor.address),
  //   multiSig
  // );

  console.log("Deploy finished...");
};

export default func;
