require('dotenv').config();
const yargs = require('yargs/yargs');
const argv = yargs(process.argv).argv;
const HDWalletProvider = require('@truffle/hdwallet-provider');

/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

// const HDWalletProvider = require('@truffle/hdwallet-provider');
//
// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */
  migrations_directory: argv.migrations,
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    testnet_bsc: {
		provider: () =>
			new HDWalletProvider(
				process.env.testnet_private_keys.split(","),
				'https://data-seed-prebsc-1-s1.binance.org:8545/',
				process.env.account || 0
			),
		network_id: 97,
		confirmations: 5,
		timeoutBlocks: 200,
		skipDryRun: true,
		gas: 6721975,
		gasPrice: 10000000000,
	},
	mainnet_bsc: {
		provider: () =>
			new HDWalletProvider(
				process.env.mainnet_private_keys.split(","),
				process.env.bsc_mainnet_rpc,
				process.env.account || 0
			),
			network_id: 56,
			confirmations: 5,
			timeoutBlocks: 200,
			skipDryRun: true,
			gas: 6721975,
			gasPrice: 5000000000,
	},
	forked_mainnet_bsc: {
		provider: () =>
			new HDWalletProvider(
				process.env.localhost_private_keys.split(","),
				'http://127.0.0.1:8545',
				process.env.account || 0
			),
			network_id: '*',
			gas: 6721970,
	},
	localhost: {
		provider: () =>
			new HDWalletProvider(
				process.env.localhost_private_keys.split(","),
				'http://127.0.0.1:8545',
				process.env.account || 0
			),
		network_id: '*',
		gas: 6721970,
	},

    localhost_bsc: {
		provider: () =>
			new HDWalletProvider(
				process.env.localhost_private_keys.split(","),
				'http://127.0.0.1:8545',
				process.env.account || 0
			),
			network_id: '*',
			gas: 6721970,
		},

    localhost_ftm: {
			provider: () =>
				new HDWalletProvider(
					process.env.localhost_private_keys.split(","),
					'http://127.0.0.1:8545',
					process.env.account || 0
				),
			network_id: '*',
      gas: 6721970,
		}
    
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.9",    // Fetch exact version from solc-bin (default: truffle's version)
      docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: true,
         runs: 200
       },
    //    evmVersion: "byzantium"
	   evmVersion: "constantinople"
      }
    }
  },

  plugins: ['truffle-plugin-verify'],

  api_keys: {
    bscscan: process.env.bsc_mainnet_api_key
  }

};