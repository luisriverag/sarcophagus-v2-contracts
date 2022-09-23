import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  let sarcoTokenAddress: string;
  let cursesAddress: string;

  const { deploy, diamond } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();
  // TODO: Find a way to pass this in as an argument
  const network = "develop";

  // Get the address of the SarcoToken contract
  if (["develop", "test", "soliditycoverage"].includes(network)) {
    const sarcoTokenMock = await deploy("SarcoTokenMock", {
      from: deployer,
      log: true,
    });
    sarcoTokenAddress = sarcoTokenMock.address;
    const cursesMock = await deploy("CursesMock", {
      from: deployer,
      log: true,
    });
    cursesAddress = cursesMock.address;
  } else if (["goerli", "goerli-fork"].includes(network)) {
    sarcoTokenAddress = process.env.SARCO_TOKEN_ADDRESS_GOERLI || "";
    cursesAddress = process.env.CURSES_ADDRESS_GOERLI || "";
  } else if (["mainnet", "mainnet-fork"].includes(network)) {
    sarcoTokenAddress = process.env.SARCO_TOKEN_ADDRESS_MAINNET || "";
    cursesAddress = process.env.CURSES_ADDRESS_MAINNET || "";
  } else {
    throw Error(`Sarcophagus is not set up for this network: ${network}`);
  }

  // Deploy the facets. Note that running diamond.deploy again will not redeploy
  // the diamond. It will resuse the diamond contracts that have already been
  // deployed.
  // The only reason for doing diamond.deploy again is so we can execute
  // AppStorageInit. This is pretty much just just a convenience.
  // Protocol fee defaults to 1% (100bps)
  const protocolFee = "1";

  await diamond.deploy("Diamond", {
    from: deployer,
    owner: deployer,
    facets: [
      "EmbalmerFacet",
      "ArchaeologistFacet",
      "ThirdPartyFacet",
      "ViewStateFacet",
      "AdminFacet",
    ],
    execute: {
      contract: "AppStorageInit",
      methodName: "init",
      args: [sarcoTokenAddress, process.env.PROTOCOL_FEE || protocolFee, cursesAddress],
    },
    log: true,
  });
};

export default func;
