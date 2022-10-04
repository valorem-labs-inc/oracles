// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/interfaces/ICompoundV3YieldOracle.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IComet.sol";

import "../src/CompoundV3YieldOracle.sol";

contract CompoundV3YieldOracleTest is Test {
    using stdStorage for StdStorage;

    event LogString(string topic);
    event LogAddress(string topic, address info);
    event LogUint(string topic, uint256 info);
    event LogInt(string topic, int256 info);

    event CometSet(address indexed token, address indexed comet);

    IComet public constant COMET_USDC = IComet(0xc3d688B66703497DAA19211EEdff47f25384cdc3);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant KEEP3R_ADDRESS = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;
    uint16 public constant DEFAULT_SNAPSHOT_ARRAY_SIZE = 5;
    uint16 public constant MAXIMUM_SNAPSHOT_ARRAY_SIZE = 3 * 5;

    CompoundV3YieldOracle public oracle;

    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    struct TotalsCollateral {
        uint128 totalSupplyAsset;
        uint128 _reserved;
    }

    function setUp() public {
        oracle = new CompoundV3YieldOracle(KEEP3R_ADDRESS);
    }

    function testConstructor() public {
        assertEq(address(COMET_USDC), address(oracle.tokenAddressToComet(USDC)));
        assertEq(address(0), address(oracle.tokenAddressToComet(IERC20(address(0)))));
    }

    function testSetComet() public {
        vm.expectRevert(ICompoundV3YieldOracle.InvalidTokenAddress.selector);
        oracle.setCometAddress(address(0), address(COMET_USDC));

        vm.expectRevert(ICompoundV3YieldOracle.InvalidCometAddress.selector);
        oracle.setCometAddress(address(this), address(0));

        // e.g. if 'this' were an ERC20
        vm.expectEmit(true, true, false, false);
        emit CometSet(address(this), address(COMET_USDC));
        oracle.setCometAddress(address(this), address(COMET_USDC));
        assertEq(address(COMET_USDC), address(oracle.tokenAddressToComet(IERC20(address(this)))));
    }

    function testSetSnapshotArraySize() public {
        (uint16 initIdx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots) =
            oracle.getCometSnapshots(address(USDC));
        uint16 initSz = uint16(snapshots.length);
        assertEq(initSz, DEFAULT_SNAPSHOT_ARRAY_SIZE);
        assertEq(initIdx, 0);

        // assert that the snapshot array maintains the same size if a smaller size
        // is provided
        uint16 snapshotSz = oracle.setCometSnapshotBufferSize(address(USDC), initSz - 1);
        assertEq(snapshotSz, DEFAULT_SNAPSHOT_ARRAY_SIZE);

        // assert that the snapshot array can grow
        snapshotSz = oracle.setCometSnapshotBufferSize(address(USDC), initSz + 1);
        assertEq(snapshotSz, DEFAULT_SNAPSHOT_ARRAY_SIZE + 1);

        // assert a revert if the max size cap is exceeded
        vm.expectRevert(ICompoundV3YieldOracle.SnapshotArraySizeTooLarge.selector);
        oracle.setCometSnapshotBufferSize(address(USDC), MAXIMUM_SNAPSHOT_ARRAY_SIZE + 1);
    }

    function testGetSpotYield() public {
        vm.expectRevert(
            abi.encodeWithSelector(ICompoundV3YieldOracle.CometAddressNotSpecifiedForToken.selector, address(this))
        );
        oracle.getTokenYield(address(this));

        uint256 yield = oracle.latchCometRate(address(USDC));
        emit LogUint("usdc yield", yield);

        // blockno 15441384
        assertEq(yield, 723951975);
    }

    function testUninitializedSnapshots() public {
        (uint16 idx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots) =
            oracle.getCometSnapshots(address(USDC));
        assertEq(idx, 0);
        for (uint256 i = 0; i < snapshots.length; i++) {
            assertEq(snapshots[i].timestamp, 0);
            assertEq(snapshots[i].supplyRate, 0);
        }
    }

    function testSnapshotUpdate() public {
        oracle.latchCometRate(address(USDC));
        (uint16 idx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots) =
            oracle.getCometSnapshots(address(USDC));
        assertEq(idx, 1);
        assertEq(snapshots[idx - 1].timestamp, block.timestamp);
        assertFalse(snapshots[idx - 1].supplyRate == 0);
    }

    function testMaxRateSwing() public {
        oracle.latchCometRate(address(USDC));

        // grant a lot of ETH
        _writeTokenBalance(address(this), address(WETH), 1_000_000_000 ether);
        WETH.approve(address(COMET_USDC), 1_000_000_000 ether);

        (,,,, uint256 amountToSupplyCap) = _getAndLogCometInfo();

        (uint256 supplyRate,) = _logAndValidateSpotYieldAgainstOracle();
        COMET_USDC.supply(address(WETH), amountToSupplyCap);
        _getAndLogCometInfo();
        (uint256 supplyRate2,) = _logAndValidateSpotYieldAgainstOracle();

        assertEq(supplyRate, supplyRate2);
        assertTrue(COMET_USDC.isBorrowCollateralized(address(this)));

        uint256 toBorrow = 2_000_000;
        uint256 usdcScale = 10 ** 6;

        // flex utilization limits
        COMET_USDC.withdraw(address(USDC), toBorrow * usdcScale);

        oracle.latchCometRate(address(USDC));
        (uint256 supplyRate3,) = _logAndValidateSpotYieldAgainstOracle();
        assertGt(supplyRate3, supplyRate2);
    }

    function testTimeWeightedReturn() public {
        uint256 toBorrow = 2_000_000;
        uint256 usdcScale = 10 ** 6;
        (,,,, uint256 amountToSupplyCap) = _getAndLogCometInfo();

        _writeTokenBalance(address(this), address(WETH), 1_000_000_000 ether);
        WETH.approve(address(COMET_USDC), 1_000_000_000 ether);
        USDC.approve(address(COMET_USDC), 1_000_000_000 ether);
        COMET_USDC.supply(address(WETH), amountToSupplyCap);

        // withdraw, supply loop
        for (uint256 i = 0; i < 10; i++) {
            // borrow
            oracle.latchCometRate(address(USDC));
            COMET_USDC.withdraw(address(USDC), toBorrow * usdcScale);
            vm.warp(block.timestamp + i * 10_000);

            // repay
            oracle.latchCometRate(address(USDC));
            COMET_USDC.supply(address(USDC), toBorrow * usdcScale);
            vm.warp(block.timestamp + i * 10_000);
        }

        (uint16 idx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots) =
            oracle.getCometSnapshots(address(USDC));

        uint256 timeWeightedYield = oracle.getTokenYield(address(USDC));
        assertEq(idx, 0);
        assertEq(snapshots.length, 5);
        assertEq(timeWeightedYield, 2211616289);
    }

    function testExistingTokenForNewComet() public {
        oracle.setCometAddress(address(this), address(1));
        vm.expectRevert();
        oracle.tokenRefreshList(2);

        // pretend we're updating the existing comet address
        oracle.setCometAddress(address(this), address(2));
        vm.expectRevert();
        oracle.tokenRefreshList(2);
    }

    function _writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function _getAndLogCometInfo()
        internal
        returns (
            int256 reserve,
            uint256 totalSupply,
            uint128 totalSuppliedWETH,
            uint128 wethSupplyCap,
            uint256 amountToSupplyCap
        )
    {
        IComet.AssetInfo memory wethInfo = COMET_USDC.getAssetInfoByAddress(address(WETH));
        IComet.TotalsCollateral memory totalWeth = COMET_USDC.totalsCollateral(address(WETH));

        reserve = COMET_USDC.getReserves();
        totalSupply = COMET_USDC.totalSupply();
        totalSuppliedWETH = totalWeth.totalSupplyAsset;
        wethSupplyCap = wethInfo.supplyCap;
        amountToSupplyCap = wethInfo.supplyCap - totalWeth.totalSupplyAsset;

        emit LogUint("cUSDCv3 reserves    ", uint256(reserve));
        emit LogUint("cUSDCv3 total supply", totalSupply);
        emit LogUint("supplied WETH       ", uint256(totalWeth.totalSupplyAsset));
        emit LogUint("WETH supply cap     ", uint256(wethInfo.supplyCap));
        emit LogUint("Amount to supply cap", uint256(amountToSupplyCap));
    }

    function _getAndLogUtilization() internal returns (uint256 utilization) {
        utilization = COMET_USDC.getUtilization();
        emit LogUint("cUSDCv3 utilization", utilization);
    }

    function _getAndLogSupplyRate() internal returns (uint256 supplyRate) {
        uint256 utilization = _getAndLogUtilization();
        supplyRate = COMET_USDC.getSupplyRate(utilization);
        emit LogUint("cUSDCv3 supply rate", supplyRate);
    }

    function _getAndLogSpotYield() internal returns (uint256 yield) {
        (uint16 idx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots) =
            oracle.getCometSnapshots(address(USDC));
        uint16 oldestIdx = _getMostRecentIndex(idx, snapshots);
        ICompoundV3YieldOracle.SupplyRateSnapshot memory oldestSnapshot = snapshots[oldestIdx];
        yield = oldestSnapshot.supplyRate;
        emit LogUint("USDC oracle yield", yield);
    }

    function _getOldestIndex(uint16 idx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots)
        internal
        pure
        returns (uint16)
    {
        if (snapshots[idx].timestamp == 0) {
            return 0;
        }

        return uint16((idx + 1) % snapshots.length);
    }

    function _getMostRecentIndex(uint16 idx, ICompoundV3YieldOracle.SupplyRateSnapshot[] memory snapshots)
        internal
        pure
        returns (uint16)
    {
        if (idx == 0) {
            return uint16(snapshots.length - 1);
        }
        return idx - 1;
    }

    function _logAndValidateSpotYieldAgainstOracle() internal returns (uint256 supplyRate, uint256 yield) {
        supplyRate = _getAndLogSupplyRate();
        yield = _getAndLogSpotYield();
        assertEq(supplyRate, yield);
    }

    function _perSecondRateToApr(uint256 perSecondRate) internal pure returns (uint256 apr) {
        uint256 secondsPerYear = 60 * 60 * 24 * 365;
        apr = perSecondRate * secondsPerYear;
    }
}
