require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 module.exports = {
	defaultNetwork: "hardhat",
	networks: {
		hardhat: {
			forking: {
				enabled : false,
				url: "http://127.0.0.1:8545"
			},
			gasPrice: 20000000000,
			blockGasLimit: 30000000,
			allowUnlimitedContractSize: true
		},
		localhost: {
			url: 'http://127.0.0.1:8545',
		},

		localhost_bsc: {
			url: 'http://127.0.0.1:8545',
		},
		forked_mainnet_bsc: {
			url: 'http://127.0.0.1:8545',
			accounts: process.env.bsc_forked_mainnet_private_keys.split(",")
		},
		
		tenderly_mainnet_bsc: {
			url: process.env.tenderly_bsc_mainnet_rpc,
			accounts: process.env.bsc_forked_mainnet_private_keys.split(",")
		},

		localhost_ftm: {
			url: 'http://127.0.0.1:8545',
		},

		testnet_bsc: {
			url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
			chainId: 97,
			gasPrice: 200000000000,
			accounts: process.env.testnet_private_keys.split(",")
		},
		mainnet_bsc: {
			url: 'https://bsc-dataseed.binance.org/',
			chainId: 56,
			gasPrice: 20000000000,
			accounts: process.env.mainnet_private_keys.split(","),
		}
	},
	solidity: {
		version: '0.8.9',
		settings: {
			optimizer: {
				enabled: true,
			},
			outputSelection: {
				'*': {
					'*': ['storageLayout'],
				},
			},
		},
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts',
	},
	mocha: {
		timeout: 200000000,
	},
};