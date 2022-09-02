// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/libraries/aloe/VolatilityOracle.sol";

contract VolatilityOracleTest is Test {
    VolatilityOracle public volatilityOracle;
    IUniswapV3Pool public pool;

    function setUp() public {
        volatilityOracle = new VolatilityOracle();
        pool = IUniswapV3Pool(0x3416cF6C708Da44DB2624D63ea0AAef7113527C6);
    }

    function testCacheMetadataFor() public {
        volatilityOracle.cacheMetadataFor(pool);

        (
            uint32 maxSecondsAgo,
            uint24 gamma0,
            uint24 gamma1,
            int24 tickSpacing
        ) = volatilityOracle.cachedPoolMetadata(pool);

        assertEq(maxSecondsAgo, 472649);
        assertEq(gamma0, 100);
        assertEq(gamma1, 100);
        assertEq(tickSpacing, 1);
    }

    function testEstimate24H1() public {
        volatilityOracle.cacheMetadataFor(pool);
        uint256 iv = volatilityOracle.estimate24H(pool);
        assertEq(iv, 376869329814192);

        (
            uint256 feeGrowthGlobal0,
            uint256 feeGrowthGlobal1,
            uint256 timestamp
        ) = volatilityOracle.feeGrowthGlobals(pool, 1);
        assertEq(feeGrowthGlobal0, 11372636660945467326552285182743240);
        assertEq(feeGrowthGlobal1, 95319452585414684384167792149219305);
        assertEq(timestamp, 1661876584);
    }

    function testEstimate24H2() public {
        volatilityOracle.cacheMetadataFor(pool);
        uint256 iv1 = volatilityOracle.estimate24H(pool);
        assertEq(iv1, 376869329814192);

        vm.warp(block.timestamp + 30 minutes);

        uint256 iv2 = volatilityOracle.estimate24H(pool);
        assertEq(iv2, 0);

        (, , uint256 timestamp) = volatilityOracle.feeGrowthGlobals(pool, 1);
        assertEq(timestamp, 1661876584);
        (, , timestamp) = volatilityOracle.feeGrowthGlobals(pool, 2);
        assertEq(timestamp, 0);

        vm.warp(block.timestamp + 31 minutes);
        assertEq(block.timestamp, 1661880244);

        volatilityOracle.estimate24H(pool);

        (, , timestamp) = volatilityOracle.feeGrowthGlobals(pool, 1);
        assertEq(timestamp, 1661876584);
        (, , timestamp) = volatilityOracle.feeGrowthGlobals(pool, 2);
        assertEq(timestamp, 1661880244);
    }

    function testEstimate24H3() public {
        volatilityOracle.cacheMetadataFor(pool);

        uint256 timestamp;
        uint8 readIndex;
        uint8 writeIndex;

        for (uint8 i; i < 28; i++) {
            volatilityOracle.estimate24H(pool);
            (readIndex, writeIndex) = volatilityOracle.feeGrowthGlobalsIndices(
                pool
            );

            if (i == 0) assertEq(readIndex, 0);
            else if (i < 25) assertEq(readIndex, 1);
            else assertEq(readIndex, (i + 2) % 25);
            assertEq(writeIndex, (i + 1) % 25);

            (, , timestamp) = volatilityOracle.feeGrowthGlobals(
                pool,
                writeIndex
            );
            assertEq(timestamp, block.timestamp);

            if (i >= 24) {
                (, , timestamp) = volatilityOracle.feeGrowthGlobals(
                    pool,
                    readIndex
                );
                assertEq(block.timestamp - timestamp, 24 hours + 24 minutes);
            }

            vm.warp(block.timestamp + 61 minutes);
        }

        uint256 gas = gasleft();
        volatilityOracle.estimate24H(pool);
        assertEq(gas - gasleft(), 26349);
    }

    function testEstimate24H4() public {
        volatilityOracle.cacheMetadataFor(pool);

        volatilityOracle.estimate24H(pool);
        vm.warp(block.timestamp + 61 minutes);
        volatilityOracle.estimate24H(pool);
        vm.warp(block.timestamp + 61 minutes);
        volatilityOracle.estimate24H(pool);
        vm.warp(block.timestamp + 24 hours);
        volatilityOracle.estimate24H(pool);

        (uint8 readIndex, ) = volatilityOracle.feeGrowthGlobalsIndices(pool);
        assertEq(readIndex, 3);
    }
}
