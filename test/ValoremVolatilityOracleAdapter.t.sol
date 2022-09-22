// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "keep3r/solidity/interfaces/IKeep3r.sol";

import "../src/VolatilityOracle.sol";
import "../src/adapters/ValoremVolatilityOracleAdapter.sol";
import "../src/interfaces/IKeep3rV2Job.sol";
import "../src/interfaces/IVolatilityOracleAdapter.sol";

/// for writeBalance
interface IERC20 {
    function balanceOf(address) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

contract ValoremVolatilityOracleAdapterTest is Test, IUniswapV3SwapCallback {
    using stdStorage for StdStorage;

    event LogString(string topic);
    event LogAddress(string topic, address info);
    event LogUint(string topic, uint256 info);
    event LogInt(string topic, int256 info);
    event LogPoolObs(string msg, address pool, uint16 obsInd, uint16 obsCard);

    // IValoremVolatilityOracleAdapter events
    event VolatilityOracleSet(address indexed oracle);
    event VolatilityOracleCacheUpdated(uint256 timestamp);
    event TokenVolatilityUpdated(
        address indexed tokenA, address indexed tokenB, uint24 feeTier, uint256 volatility, uint256 timestamp
    );
    event AdminSet(address indexed admin);
    event TokenRefreshListSet();

    VolatilityOracle public volatilityOracle;
    address private constant KEEP3R_ADDRESS = 0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC;

    address private constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant FUN_ADDRESS = 0x419D0d8BdD9aF5e606Ae2232ed285Aff190E711b;
    address private constant LUSD_ADDRESS = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address private constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant SNX_ADDRESS = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;

    uint24 private constant POINT_ZERO_ONE_PCT_FEE = 1 * 100;
    uint24 private constant POINT_ZERO_FIVE_PCT_FEE = 5 * 100;
    uint24 private constant POINT_THREE_PCT_FEE = 3 * 100 * 10;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    ValoremVolatilityOracleAdapter public adapter;

    IValoremVolatilityOracleAdapter.UniswapV3PoolInfo[] private defaultTokenRefreshList;

    function setUp() public {
        volatilityOracle = new VolatilityOracle();

        adapter = new ValoremVolatilityOracleAdapter(
            address(volatilityOracle),
            KEEP3R_ADDRESS);

        vm.makePersistent(address(volatilityOracle), address(adapter));

        delete defaultTokenRefreshList;
        defaultTokenRefreshList.push(
            IValoremVolatilityOracleAdapter.UniswapV3PoolInfo(
                USDC_ADDRESS, DAI_ADDRESS, IVolatilityOracleAdapter.UniswapV3FeeTier.PCT_POINT_01
            )
        );
        defaultTokenRefreshList.push(
            IValoremVolatilityOracleAdapter.UniswapV3PoolInfo(
                FUN_ADDRESS, DAI_ADDRESS, IVolatilityOracleAdapter.UniswapV3FeeTier.PCT_POINT_01
            )
        );
        defaultTokenRefreshList.push(
            IValoremVolatilityOracleAdapter.UniswapV3PoolInfo(
                WETH_ADDRESS, DAI_ADDRESS, IVolatilityOracleAdapter.UniswapV3FeeTier.PCT_POINT_3
            )
        );
    }

    function testAdmin() public {
        adapter.setVolatilityOracle(address(0));

        // some random addr
        vm.prank(address(1));
        vm.expectRevert(bytes("!ADMIN"));
        adapter.setVolatilityOracle(address(this));

        vm.expectEmit(true, false, false, false);
        emit AdminSet(address(1));
        adapter.setAdmin(address(1));
        vm.expectRevert(bytes("!ADMIN"));
        adapter.setVolatilityOracle(address(this));
    }

    function testGetUniswapV3Pool() public {
        IUniswapV3Pool pool = adapter.getV3PoolForTokensAndFee(USDC_ADDRESS, DAI_ADDRESS, POINT_ZERO_ONE_PCT_FEE);
        // USDC / DAI @ .01 pct
        assertEq(address(pool), 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168);

        pool = adapter.getV3PoolForTokensAndFee(USDC_ADDRESS, DAI_ADDRESS, POINT_ZERO_FIVE_PCT_FEE);
        // USDC / DAI @ .05 pct
        assertEq(address(pool), 0x6c6Bc977E13Df9b0de53b251522280BB72383700);
    }

    function testSetRefreshTokenList() public {
        vm.expectEmit(false, false, false, false);
        emit TokenRefreshListSet();
        adapter.setTokenFeeTierRefreshList(defaultTokenRefreshList);

        IValoremVolatilityOracleAdapter.UniswapV3PoolInfo[] memory returnedRefreshList =
            adapter.getTokenFeeTierRefreshList();
        assertEq(defaultTokenRefreshList, returnedRefreshList);
    }

    function testTokenVolatilityRefresh() public {
        // move forward 1 hour to allow for aloe data requirement
        vm.warp(block.timestamp + 1 hours + 1);
        adapter.setTokenFeeTierRefreshList(defaultTokenRefreshList);

        for (uint256 i = 0; i < defaultTokenRefreshList.length; i++) {
            address tokenA = defaultTokenRefreshList[i].tokenA;
            address tokenB = defaultTokenRefreshList[i].tokenB;
            IValoremVolatilityOracleAdapter.UniswapV3FeeTier feeTier = defaultTokenRefreshList[i].feeTier;
            uint24 fee = adapter.getUniswapV3FeeInHundredthsOfBip(feeTier);
            vm.expectEmit(true, true, false, false);
            emit TokenVolatilityUpdated(tokenA, tokenB, fee, 0, 0);
        }
        vm.expectEmit(false, false, false, true);
        emit VolatilityOracleCacheUpdated(block.timestamp);
        uint256 ts = adapter.refreshVolatilityCache();
        assertEq(ts, block.timestamp);
    }

    function testGetImpliedVolatility() public {
        // move forward 1 hour to allow for aloe data requirement
        vm.warp(block.timestamp + 1 hours + 1);
        adapter.setTokenFeeTierRefreshList(defaultTokenRefreshList);
        _cache1d();
        emit LogString("cached one day");
        for (uint256 i = 0; i < defaultTokenRefreshList.length; i++) {
            IValoremVolatilityOracleAdapter.UniswapV3PoolInfo storage poolInfo = defaultTokenRefreshList[i];
            _validateCachedVolatilityForPool(poolInfo);
        }
    }

    function testKeep3r() public {
        vm.expectRevert(IKeep3rV2Job.InvalidKeeper.selector);
        adapter.work();

        vm.warp(block.timestamp + 1 hours + 1);
        adapter.setTokenFeeTierRefreshList(defaultTokenRefreshList);
        vm.mockCall(KEEP3R_ADDRESS, abi.encodeWithSelector(IKeep3rJobWorkable.isKeeper.selector), abi.encode(true));
        vm.mockCall(KEEP3R_ADDRESS, abi.encodeWithSelector(IKeep3rJobWorkable.worked.selector), abi.encode(""));
        adapter.work();
    }

    /**
     * /////////// IUniswapV3SwapCallback /////////////
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) public {
        emit LogInt("uniswap swap callback, amount0", amount0Delta);
        emit LogInt("uniswap swap callback, amount1", amount1Delta);
        // only ever transferring DAI to the pool, extend this via data
        int256 amountToTransfer = amount0Delta > 0 ? amount0Delta : amount1Delta;
        emit LogUint("uniswap swap callback, amountToTransfer", uint256(amountToTransfer));
        address poolAddr = _bytesToAddress(data);
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
        address erc20 = amount0Delta > 0 ? pool.token0() : pool.token1();
        IERC20(erc20).transfer(poolAddr, uint256(amountToTransfer));
    }

    /**
     * ///////// HELPERS //////////
     */
    function assertEq(
        IValoremVolatilityOracleAdapter.UniswapV3PoolInfo[] memory a,
        IValoremVolatilityOracleAdapter.UniswapV3PoolInfo[] memory b
    ) internal {
        // from forg-std/src/Test.sol
        if (keccak256(abi.encode(a)) != keccak256(abi.encode(b))) {
            emit log("Error: a == b not satisfied [UniswapV3PoolInfo[]]");
            fail();
        }
    }

    function _validateCachedVolatilityForPool(IValoremVolatilityOracleAdapter.UniswapV3PoolInfo storage poolInfo)
        internal
    {
        address tokenA = poolInfo.tokenA;
        address tokenB = poolInfo.tokenB;
        IVolatilityOracleAdapter.UniswapV3FeeTier feeTier = poolInfo.feeTier;
        uint256 iv = adapter.getImpliedVolatility(tokenA, tokenB, feeTier);
        assertFalse(iv == 0, "Volatility is expected to have been refreshed");
    }

    function _cache1d() internal {
        // get 24 hours
        adapter.setTokenFeeTierRefreshList(defaultTokenRefreshList);
        adapter.refreshVolatilityCache();
        for (uint256 i = 0; i < 24; i++) {
            emit LogUint("cached hour", i);
            // fuzz trades
            _simulateUniswapMovements();
            adapter.refreshVolatilityCache();
            // refresh the pool metadata
            vm.warp(block.timestamp + 1 hours + 1);
        }

        vm.warp(block.timestamp + 3 hours);
        adapter.setTokenFeeTierRefreshList(defaultTokenRefreshList);
    }

    function _simulateUniswapMovements() internal {
        // add tokens to this contract
        _writeTokenBalance(address(this), address(DAI_ADDRESS), 1_000_000_000 ether);

        // iterate pools
        for (uint256 i = 0; i < defaultTokenRefreshList.length; i++) {
            IValoremVolatilityOracleAdapter.UniswapV3PoolInfo memory poolInfo = defaultTokenRefreshList[i];
            uint24 fee = adapter.getUniswapV3FeeInHundredthsOfBip(poolInfo.feeTier);
            IUniswapV3Pool pool = adapter.getV3PoolForTokensAndFee(poolInfo.tokenA, poolInfo.tokenB, fee);
            bool zeroForOne = pool.token0() == DAI_ADDRESS;
            // swap tokens on each pool
            (int256 amount0, int256 amount1) = pool.swap(
                address(this),
                zeroForOne,
                1_000_000 ether,
                zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
                abi.encodePacked(address(pool))
            );

            vm.warp(block.timestamp + 1 hours + 1);

            // swap it back
            pool.swap(
                address(this),
                !zeroForOne,
                zeroForOne ? -amount1 : -amount0,
                !zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
                abi.encodePacked(address(pool))
            );

            // go back in time
            vm.warp(block.timestamp - 1 hours);
            (,, uint16 obsInd, uint16 obsCard,,,) = pool.slot0();
            emit LogPoolObs("number of observations in pool", address(pool), obsInd, obsCard);
        }
    }

    function _writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function _bytesToAddress(bytes memory bys) internal pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 0x14))
        }
    }
    // TODO: Keep3r tests
}
