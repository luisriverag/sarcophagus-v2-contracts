import * as dotenv from "dotenv";

import { extendEnvironment, HardhatUserConfig, task } from "hardhat/config";
import { generateHistory } from "./tasks/generate-history";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-deploy";
import "@nomiclabs/hardhat-solhint";
import "hardhat-contract-sizer";

dotenv.config();

/**
 * Generates fake historical data on the app for testing.
 *
 * Config for this task can be found in tasks/generate-history/config.ts
 *
 * IMPORTANT: If you are running a node on localhost using `npx hardhat node` then you must run this
 * task with `--network localhost`.
 * ```
 * npx hardhat generate-history --network localhost
 * ```
 *
 * The purpose of generating this data is so that we can have some metrics on the archaeologists on
 * chain. This task is expensive and modifies the block timestamps and therefore cannot be run
 * anywhere other than localhost.
 *
 * Note that since this task modifies the block timestamps it will only work once, since subsequent
 * attempts to create a sarcophagus will cause the contract to think a sarcophagus is being created in
 * the past. To run this command again, simply restart the node.
 *
 * Also note that the archaeologists being registered here will NOT appear on the list of
 * archaeologists in the web app. This is because each archaeologist must have an archaeologist
 * service running in order to appear on the list. The web app may be modified temporarily to show
 * offline archaeologists for testing purposes, in which case these archaeologists will appear on
 * the list.
 */
task("generate-history", "Generates fake historical data for testing")
  .addOptionalParam(
    "archaeologistCount",
    "The number of archaeologists to register. Defaults to 20."
  )
  .addOptionalParam(
    "sarcophagusCount",
    "The number of sarcophagi to create. This uses a random number of archaeologists that have been registered. Defaults to 10."
  )
  .addOptionalParam(
    "accusedSarcophagusCount",
    "The number of sarcophagi to accuse. All archaeologists on each sarcophagus will be accused. Defaults to 2 sarcophagi."
  )
  .addOptionalParam(
    "archaeologistUnwrapChance",
    "The probability that an archaeologist will unwrap the sarcpohagi they are associated with. Defaults to 0.85."
  )
  .setAction(generateHistory);

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: "0.8.18",
  namedAccounts: {
    deployer: {
      default: 0,
      mainnet: `privatekey://${process.env.MAINNET_DEPLOYER_PRIVATE_KEY}`,
      polygon: `privatekey://${process.env.POLYGON_DEPLOYER_PRIVATE_KEY}`,
      base: `privatekey://${process.env.BASE_DEPLOYER_PRIVATE_KEY}`,
      baseGoerli: `privatekey://${process.env.BASE_GOERLI_DEPLOYER_PRIVATE_KEY}`,
      polygonMumbai: `privatekey://${process.env.POLYGON_MUMBAI_DEPLOYER_PRIVATE_KEY}`,
      goerli: `privatekey://${process.env.GOERLI_DEPLOYER_PRIVATE_KEY}`,
      sepolia: `privatekey://${process.env.SEPOLIA_DEPLOYER_PRIVATE_KEY}`,
    },
  },
  networks: {
    mainnet: {
      chainId: 1,
      url: process.env.MAINNET_PROVIDER || "",
      accounts: process.env.MAINNET_DEPLOYER_PRIVATE_KEY
        ? [process.env.MAINNET_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    arbitrum: {
      chainId: 42161,
      url: process.env.ARBITRUM_PROVIDER || "",
      accounts: process.env.ARBITRUM_DEPLOYER_PRIVATE_KEY
        ? [process.env.ARBITRUM_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    base: {
      chainId: 8453,
      url: process.env.BASE_PROVIDER || "",
      accounts: process.env.BASE_DEPLOYER_PRIVATE_KEY
        ? [process.env.BASE_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    polygon: {
      chainId: 137,
      url: process.env.POLYGON_PROVIDER || "",
      accounts: process.env.POLYGON_DEPLOYER_PRIVATE_KEY
        ? [process.env.POLYGON_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    polygonMumbai: {
      chainId: 80001,
      url: process.env.POLYGON_MUMBAI_PROVIDER || "",
      accounts: process.env.POLYGON_MUMBAI_DEPLOYER_PRIVATE_KEY
        ? [process.env.POLYGON_MUMBAI_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    sepolia: {
      chainId: 11155111,
      url: process.env.SEPOLIA_PROVIDER || "",
      accounts: process.env.SEPOLIA_DEPLOYER_PRIVATE_KEY
        ? [process.env.SEPOLIA_DEPLOYER_PRIVATE_KEY]
        : [],
    },
    hardhat: {
      accounts: {
        count: 25,
      },
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COIN_MARKET_CAP_API_KEY,

    // Uncomment to override gas price
    // gasPrice: 20,
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      base: process.env.BASESCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "arbitrum",
        chainId: 8453,
        urls: {
          apiURL: "https://api.arbiscan.io/",
          browserURL: "https://arbiscan.io/",
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
      {
        network: "baseGoerli",
        chainId: 84531,
        urls: {
          apiURL: "https://api-goerli.basescan.org/api",
          browserURL: "https://goerli.basescan.org/",
        },
      },
    ],
  },
};

extendEnvironment(async (hre) => {
  hre["loadContracts"] = async (suppliedDiamondAddress) => {
    const diamondAddress =
      suppliedDiamondAddress ||
      require(`./deployments/${hre.network.name}/Sarcophagus_V2_DiamondProxy.json`)
        .address;
    console.log(
      `Initializing HRE on network ${hre.network.name} with diamond address ${diamondAddress}`
    );

    if (
      !diamondAddress ||
      (await hre.ethers.provider.getCode(diamondAddress)) === "0x"
    )
      throw Error(
        `No code exists at the supplied diamond address: ${process.env.DIAMOND_ADDRESS}`
      );

    hre["embalmerFacet"] = await hre.ethers.getContractAt(
      "EmbalmerFacet",
      diamondAddress
    );
    hre["archaeologistFacet"] = await hre.ethers.getContractAt(
      "ArchaeologistFacet",
      diamondAddress
    );
    hre["thirdPartyFacet"] = await hre.ethers.getContractAt(
      "ThirdPartyFacet",
      diamondAddress
    );
    hre["viewStateFacet"] = await hre.ethers.getContractAt(
      "ViewStateFacet",
      diamondAddress
    );
    hre["adminFacet"] = await hre.ethers.getContractAt(
      "AdminFacet",
      diamondAddress
    );
  };

  hre["connectSigner"] = async (suppliedPrivateKey) => {
    const privateKey = suppliedPrivateKey;
    const signer = new hre.ethers.Wallet(privateKey, hre.ethers.provider);
    console.log(
      `Connecting HRE contracts to signer with address ${signer.address}`
    );

    hre["embalmerFacet"] = hre["embalmerFacet"].connect(signer);
    hre["archaeologistFacet"] = hre["archaeologistFacet"].connect(signer);
    hre["thirdPartyFacet"] = hre["thirdPartyFacet"].connect(signer);
    hre["viewStateFacet"] = hre["viewStateFacet"].connect(signer);
    hre["adminFacet"] = hre["adminFacet"].connect(signer);
  };
});

export default config;
