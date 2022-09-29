// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/interfaces/ICompoundV3YieldOracleAdmin.sol";
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
        oracle = new CompoundV3YieldOracle();
    }

    function testConstructor() public {
        assertEq(address(COMET_USDC), address(oracle.tokenAddressToComet(USDC)));
        assertEq(address(0), address(oracle.tokenAddressToComet(IERC20(address(0)))));
    }

    function testSetComet() public {
        vm.expectRevert(ICompoundV3YieldOracleAdmin.InvalidTokenAddress.selector);
        oracle.setCometAddress(address(0), address(COMET_USDC));

        vm.expectRevert(ICompoundV3YieldOracleAdmin.InvalidCometAddress.selector);
        oracle.setCometAddress(address(this), address(0));

        // e.g. if 'this' were an ERC20
        vm.expectEmit(true, true, false, false);
        emit CometSet(address(this), address(COMET_USDC));
        oracle.setCometAddress(address(this), address(COMET_USDC));
        assertEq(address(COMET_USDC), address(oracle.tokenAddressToComet(IERC20(address(this)))));
    }

    function testGetYield() public {
        vm.expectRevert(
            abi.encodeWithSelector(ICompoundV3YieldOracleAdmin.CometAddressNotSpecifiedForToken.selector, address(this))
        );
        oracle.getTokenYield(address(this));

        uint256 yield = oracle.getTokenYield(address(USDC));
        emit LogUint("usdc yield", yield);

        // blockno 15441384
        assertEq(yield, 723951975);
    }

    function testMaxRateSwing() public {
        // grant a lot of ETH
        _writeTokenBalance(address(this), address(WETH), 1_000_000_000 ether);
        WETH.approve(address(COMET_USDC), 1_000_000_000 ether);

        (
            int256 reserve,
            uint256 totalSupply,
            uint128 totalSuppliedWETH,
            uint128 wethSupplyCap,
            uint256 amountToSupplyCap
        ) = _getAndLogCometInfo();

        (uint256 supplyRate,) = _logAndValidateYieldAgainstOracle();
        COMET_USDC.supply(address(WETH), amountToSupplyCap);
        _getAndLogCometInfo();
        (uint256 supplyRate2,) = _logAndValidateYieldAgainstOracle();

        assertEq(supplyRate, supplyRate2);
        assertTrue(COMET_USDC.isBorrowCollateralized(address(this)));

        uint256 toBorrow = 2_000_000;
        uint256 usdcScale = 10 ** 6;

        // flex utilization limits
        COMET_USDC.withdraw(address(USDC), toBorrow * usdcScale);
        (uint256 supplyRate3,) = _logAndValidateYieldAgainstOracle();
        assertGt(supplyRate3, supplyRate2);
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

    function _getAndLogUtilization()
        internal
        returns (
            uint256 utilization
        )
    {
        utilization = COMET_USDC.getUtilization();
        emit LogUint("cUSDCv3 utilization", utilization);
    }

    function _getAndLogSupplyRate()
        internal 
        returns (
            uint256 supplyRate
        )
    {
        uint256 utilization = _getAndLogUtilization();
        supplyRate = COMET_USDC.getSupplyRate(utilization);
        emit LogUint("cUSDCv3 supply rate (apr)", _perSecondRateToApr(supplyRate));
    }

    function _getAndLogOracleYield()
        internal 
        returns (
            uint256 yield
        )
    {
        yield =oracle.getTokenYield(address(USDC));
        emit LogUint("USDC oracle yield (apr)", _perSecondRateToApr(yield));
    }

    function _logAndValidateYieldAgainstOracle() internal returns (uint256 supplyRate, uint256 yield) {
        supplyRate = _getAndLogSupplyRate();
        yield = _getAndLogOracleYield();
        assertEq(supplyRate, yield);
    }

    function _perSecondRateToApr(uint256 perSecondRate) internal pure returns (uint256 apr) {
        uint256 secondsPerYear = 60 * 60 * 24 * 365;
        apr = perSecondRate * secondsPerYear;
    }
}
