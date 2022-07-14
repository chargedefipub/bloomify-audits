// SPDX-License-Identifier: Elastic-2.0
pragma solidity 0.8.9;

/** 
 * @dev These are the keys/identifiers used to look up 
 * information in the StrategyConfig contract.
 */
library StratConfigLookUpKeys {

    /*
     * NO LOOKUP KEYS WITH ZERO (0) IS ALLOWED! 
     *
     * 0 is reserved to represent no key exists.
     */
     
    // ------------------------------------------------------------------------
    // COMMMON - 0 - 1000
    // ------------------------------------------------------------------------
    uint256 constant TOKEN_DOLLAR_DEFAULT = 100;
    uint256 constant UTIL_SWAPPER_DEFAULT = 999;
    uint256 constant STRAT_STATS = 1000;
    uint256 constant STRAT_TVL = 200;

    // ------------------------------------------------------------------------
    // Convertors - Range 1000 - 100000
    // ------------------------------------------------------------------------

    // ---------- BSC
    uint256 constant UTIL_SWAPPER_PANCAKE = 1002;
    uint256 constant UTIL_SWAPPER_APESWAP = 1004;

    uint256 constant UTIL_ZAPPER_PANCAKE = 1001;
    uint256 constant UTIL_ZAPPER_APESWAP = 1003;

    uint256 constant ROUTER_PCS = 5000;
    uint256 constant ROUTER_APESWAP = 5002;

    uint256 constant DOLLAR_ORACLE_PCS = 5001;
    uint256 constant DOLLAR_ORACLE_APESWAP = 5003;

    // ---------- Fantom
    uint256 constant UTIL_ZAPPER_SPOOKYSWAP = 10001;
    uint256 constant UTIL_ZAPPER_SPIRITSWAP = 10003;

    uint256 constant UTIL_SWAPPER_SPOOKYSWAP = 10002;
    uint256 constant UTIL_SWAPPER_SPIRITSWAP = 10004;

    uint256 constant ROUTER_SPOOKYSWAP = 15000;
    uint256 constant ROUTER_SPIRITSWAP = 15002;
    
    uint256 constant DOLLAR_ORACLE_SPOOKYSWAP = 15001;
    uint256 constant DOLLAR_ORACLE_SPIRITSWAP = 15003;

    // ------------------------------------------------------------------------
    // Tokens - Range 1000000 to 2000000
    // ------------------------------------------------------------------------

    uint256 constant TOKEN_BUSD = 1000001;
    uint256 constant TOKEN_WBNB = 1000002;
    uint256 constant TOKEN_CHARGE = 1000003;
    uint256 constant TOKEN_STATIC = 1000004;
    uint256 constant TOKEN_CAKE = 1000005;
    uint256 constant TOKEN_USDC = 1000006;
    uint256 constant TOKEN_WFTM = 1000007;
    uint256 constant TOKEN_BTCB = 1000008;
    uint256 constant TOKEN_ETH = 1000009;
    uint256 constant TOKEN_USDT = 1000010;
    uint256 constant TOKEN_BSHARE = 1000011;
   
    // ------------------------------------------------------------------------
    // LPs - Range 2000000 to 3000000
    // ------------------------------------------------------------------------
    uint256 constant LP_STATIC_BUSD = 2000001;
    uint256 constant LP_CHARGE_BUSD = 2000002;

    // Pancake LPs
    uint256 constant LP_PCS_CAKE_BNB = 2000050;
    uint256 constant LP_PCS_BUSD_BNB = 2000051;
    uint256 constant LP_PCS_USDT_BNB = 2000052;
    uint256 constant LP_PCS_BTCB_BNB = 2000053;
    uint256 constant LP_PCS_ETH_BNB = 2000054;
    uint256 constant LP_PCS_CAKE_BUSD = 2000055;
    uint256 constant LP_PCS_USDC_BUSD = 2000056;
    uint256 constant LP_PCS_USDT_BUSD = 2000057;
    uint256 constant LP_PCS_USDC_USDT = 2000058;
    uint256 constant LP_PCS_BTCB_ETH = 2000059;
    uint256 constant LP_PCS_BTCB_BUSD = 2000060;
    uint256 constant LP_PCS_BTT_BUSD = 2000061;
    uint256 constant LP_PCS_MBOX_BNB = 2000062;
    uint256 constant LP_PCS_TRX_BUSD = 2000063;
    uint256 constant LP_PCS_ETH_USDC = 2000064;
    uint256 constant LP_PCS_BSHARE_BNB = 2000065;
    

    // ------------------------------------------------------------------------
    // (Spare) - Range 3000000 to 4000000
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // Adaptors - Range 4000000 to 5000000
    // ------------------------------------------------------------------------
    uint256 constant ADAPTOR_ZAPPER_PANCAKE = 4000001;
    uint256 constant ADAPTOR_SWAPPER_PANCAKE = 4000002;

    uint256 constant ADAPTOR_ZAPPER_SPOOKYSWAP = 4100001;
    uint256 constant ADAPTOR_SWAPPER_SPOOKYSWAP = 4100002;
    uint256 constant ADAPTOR_ZAPPER_SPIRITSWAP = 4100003;
    uint256 constant ADAPTOR_SWAPPER_SPIRITSWAP = 4100004;

    // ------------------------------------------------------------------------
    // Staking - Range 5000001 to 5500000
    // ------------------------------------------------------------------------
    uint256 constant STAKE_CHARGE_BR = 5000001;
    uint256 constant STAKE_STATIC_BUSD_LP_BR = 5000002;
    uint256 constant STAKE_CHARGE_BUSD_LP_FARM = 5000003;

    // Pancake Staking
    uint256 constant STAKE_PCS_CAKE_MANUAL = 5000100;
    uint256 constant STAKE_PCS_MASTERCHEF_V2 = 5000101;
    uint256 constant STAKE_BOMB_REWARD_POOL = 5000102;
    
    // ------------------------------------------------------------------------
    // Blocks meta contracts - Range 5500001 to 6000000
    // ------------------------------------------------------------------------
    uint256 constant STAKE_META_BOARDROOM_STATS = 5500001;
    uint256 constant STAKE_META_PCS_POOL_STATS = 5500002;

    // ------------------------------------------------------------------------
    // Sentries - Range 6000001 to 6010000
    // ------------------------------------------------------------------------
    uint256 constant SENTRY_FACTORY = 6000001;
    uint256 constant SENTRY_RUNNER = 6000002;

    // ------------------------------------------------------------------------
    // Banks - Range 6010001 to 6020000
    // ------------------------------------------------------------------------
    uint256 constant PCS_USDT_BUSD_STRAT_VAULT = 6010001;
    uint256 constant PCS_USDC_BUSD_STRAT_VAULT = 6010002;
    uint256 constant PCS_USDC_USDT_STRAT_VAULT = 6010003;
    uint256 constant PCS_CHARGE_BUSD_STRAT_VAULT = 6010004;
}