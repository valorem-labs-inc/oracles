// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../src/libraries/aloe/VolatilityOracle.sol";
import "../src/adapters/AloeVolatilityOracleAdapter.sol";

contract AloeVolatilityOracleAdapterTest is Test {
    event LogString(string topic, uint256 info);
    event LogAddress(string topic, address info);


    VolatilityOracle public volatilityOracle;
    address private constant UNISWAP_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address private constant KEEP3R_ADDRESS = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;

    address private constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant MATIC_ADDRESS = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;
    address private constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant SNX_ADDRESS = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;

    uint24 private constant POINT_ZERO_ONE_PCT_FEE = 1 * 100;
    uint24 private constant POINT_THREE_PCT_FEE = 3 * 100 * 10;
    uint24 private constant POINT_ZERO_FIVE_PCT_FEE = 5 * 100;

    AloeVolatilityOracleAdapter public aloeAdapter;

    address[] private defaultTokenRefreshList;

    function setUp() public {
        volatilityOracle = new VolatilityOracle();

        aloeAdapter = new AloeVolatilityOracleAdapter(
            UNISWAP_FACTORY_ADDRESS, 
            address(volatilityOracle),
            KEEP3R_ADDRESS);

        defaultTokenRefreshList = new address[](4);
        defaultTokenRefreshList[0] = USDC_ADDRESS;
        defaultTokenRefreshList[1] = MATIC_ADDRESS;
        defaultTokenRefreshList[2] = LINK_ADDRESS;
        defaultTokenRefreshList[3] = WETH_ADDRESS;
    }

    modifier defaultPool() {
        aloeAdapter.setUniswapV3Pool(DAI_ADDRESS, POINT_ZERO_ONE_PCT_FEE);
        _;
    }

    function testSetUniswapV3Pool() public defaultPool {
        IUniswapV3Pool pool = aloeAdapter.getV3PoolForTokenAddress(USDC_ADDRESS);
        assertEq(address(pool), 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);

        aloeAdapter.setUniswapV3Pool(DAI_ADDRESS, POINT_ZERO_FIVE_PCT_FEE);
        pool = aloeAdapter.getV3PoolForTokenAddress(USDC_ADDRESS);
        assertEq(address(pool), 0x6c6Bc977E13Df9b0de53b251522280BB72383700);
    }

    function testSetRefreshTokenList() public {
        // TODO: assert event emission
        aloeAdapter.setTokenRefreshList(defaultTokenRefreshList);

        address[] memory returnedRefreshList = aloeAdapter.getTokenRefreshList();
        assertEq(defaultTokenRefreshList, returnedRefreshList);

        defaultTokenRefreshList[3] = SNX_ADDRESS;

        aloeAdapter.setTokenRefreshList(defaultTokenRefreshList);

        returnedRefreshList = aloeAdapter.getTokenRefreshList();
        assertFalse(returnedRefreshList[3] == WETH_ADDRESS);
        assertEq(defaultTokenRefreshList, returnedRefreshList);
    }

    function testTokenVolatilityRefresh() public defaultPool {
        // TODO: Add error if v3 pool not set
        aloeAdapter.setTokenRefreshList(defaultTokenRefreshList);
        emit LogAddress("aloeVolatilityOracle", address(volatilityOracle));
        uint256 ts = aloeAdapter.refreshVolatilityCache();
        assertEq(ts, block.timestamp);
    }
}