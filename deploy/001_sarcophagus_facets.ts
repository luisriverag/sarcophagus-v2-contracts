import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import time from "../test/utils/time";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  let sarcoTokenAddress: string;

  const { deploy, diamond } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  // DAO agent address is the deployer for all networks except mainnet
  // In which case it is the Sarcophagus Aragon Agent
  const daoAgentAddress = deployer;

  // Get the address of the SarcoToken contract
  if (
    hre.hardhatArguments.network === "develop" ||
    hre.hardhatArguments.network === "localhost" ||
    !hre.hardhatArguments.network
  ) {
    const sarcoTokenMock = await deploy("SarcoTokenMock", {
      from: deployer,
      log: true,
    });
    sarcoTokenAddress = sarcoTokenMock.address;
  } else if (["sepolia"].includes(hre.hardhatArguments.network)) {
    sarcoTokenAddress = "0xfa1FA4d51FB2babf59e402c83327Ab5087441289";
  } else if (
    ["mainnet", "mainnet-fork"].includes(hre.hardhatArguments.network)
  ) {
    sarcoTokenAddress = "0x7697b462a7c4ff5f8b55bdbc2f4076c2af9cf51a";
  } else if (["polygonMumbai"].includes(hre.hardhatArguments.network)) {
    sarcoTokenAddress = "0x2BC9019e6d9e6a26D7D8d8CDDa4e5dE9B787D7bb";
  } else if (["polygon"].includes(hre.hardhatArguments.network)) {
    sarcoTokenAddress = "0x80Ae3B3847E4e8Bd27A389f7686486CAC9C3f3e8";
  } else if (["arbitrum"].includes(hre.hardhatArguments.network)) {
    sarcoTokenAddress = "0x82155Ab6b6c1113CFb352c7573B010a88f5974bD";
  } else if (["base"].includes(hre.hardhatArguments.network)) {
    sarcoTokenAddress = "0xF3907Bc0FFF5Ff5aCf1E3dD7987005779C7bf57d";
  } else {
    throw Error(
      `Sarcophagus is not set up for this network: ${hre.hardhatArguments.network}`
    );
  }

  // Default: 1% (100 / 10000)
  const protocolFeeBasePercentage = "100";

  // Default: 100% (10000 / 10000)
  const cursedBondPercentage = "10000";

  // Default: 1 Day
  const gracePeriod = time.duration.days(1);

  // Default 1 week
  const embalmerClaimWindow = time.duration.weeks(1);

  // Default 1 hour
  const expirationThreshold = time.duration.hours(1);

  await diamond.deploy("Sarcophagus_V2", {
    from: deployer,
    owner: deployer,
    facets: [
      "EmbalmerFacet",
      "ArchaeologistFacet",
      "ThirdPartyFacet",
      "ViewStateFacet",
      "AdminFacet",
    ],
    // Comment out if upgrading
    execute: {
      contract: "AppStorageInit",
      methodName: "init",
      args: [
        sarcoTokenAddress,
        daoAgentAddress,
        protocolFeeBasePercentage,
        cursedBondPercentage,
        gracePeriod,
        embalmerClaimWindow,
        expirationThreshold,
      ],
    },
    log: true,
  });
};

export default func;
