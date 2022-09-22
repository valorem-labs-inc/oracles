// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./IKeep3rV2Job.sol";
import "./IAdmin.sol";
import "./IVolatilityOracle.sol";

interface IUniswapV3VolatilityOracle is IKeep3rV2Job, IVolatilityOracle {
    enum UniswapV3FeeTier {
        PCT_POINT_01,
        PCT_POINT_05,
        PCT_POINT_3,
        PCT_1
    }

    /**
     * ////////// STRUCTS /////////////
     */
    struct UniswapV3PoolInfo {
        address tokenA;
        address tokenB;
        UniswapV3FeeTier feeTier;
    }

    /**
     * /////////// EVENTS /////////////
     */

    /**
     * @notice Emitted when the implied volatility cache is updated.
     * @param timestamp The timestamp of when the cache is updated.
     */
    event VolatilityOracleCacheUpdated(uint256 timestamp);

    /**
     * @notice Emitted when the implied volatility for a given token is updated.
     * @param tokenA The ERC20 contract address of the token.
     * @param tokenB The ERC20 contract address of the token.
     * @param feeTier The UniswapV3 fee tier.
     * @param volatility The implied volatility of the token.
     * @param timestamp The timestamp of the refresh.
     */
    event TokenVolatilityUpdated(
        address indexed tokenA, address indexed tokenB, uint24 feeTier, uint256 volatility, uint256 timestamp
    );

    /// @notice Emitted when the token refresh list is set.
    event TokenRefreshListSet();

    /// @notice Thrown when the passed v3 factory address is invalid.
    error InvalidUniswapV3Factory();

    /// @notice Thrown when invalid parameters are passed to setUniswapV3Pool.
    error InvalidUniswapV3Pool();

    /// @notice Thrown when the passed volatility oracle address is invalid.
    error InvalidVolatilityOracle();

    /**
     * ////////// HELPERS ///////////
     */

    /**
     * @notice Retrieves the uniswap v3 pool for passed ERC20 address plus arguments
     * from setUniswapV3Pool.
     * @param tokenA The contract address of the ERC20 for which to retrieve the v3 pool.
     * @param tokenB The contract address of the ERC20 for which to retrieve the v3 pool.
     * @param fee The fee tier for the pool in 1/100ths of a bip.
     * @return pool The uniswap v3 pool for the supplied token.
     */
    function getV3PoolForTokensAndFee(address tokenA, address tokenB, uint24 fee)
        external
        view
        returns (IUniswapV3Pool pool);

    /**
     * @notice Retrieves the uniswap fee in 1/100ths of a bip.
     * @param tier The fee tier enum.
     * @return The fee in 1/100ths of a bip.
     */
    function getUniswapV3FeeInHundredthsOfBip(UniswapV3FeeTier tier) external pure returns (uint24);

    /**
     * @notice Updates the cached implied volatility for the tokens in the refresh list.
     * @return timestamp The timestamp of the cache refresh.
     */
    function refreshVolatilityCache() external returns (uint256 timestamp);

    /**
     * @notice Updates the cached implied volatility for the supplied pool info.
     * @return timestamp The timestamp of the cache refresh.
     */
    function refreshVolatilityCacheAndMetadataForPool(UniswapV3PoolInfo calldata info)
        external
        returns (uint256 timestamp);

    /**
     * ////////// TOKEN REFRESH LIST //////////
     */

    /**
     * @notice Sets the list of tokens and fees to periodically refresh for implied volatility.
     * @param list The token refresh list.
     * @return The token refresh list.
     */
    function setTokenFeeTierRefreshList(UniswapV3PoolInfo[] calldata list)
        external
        returns (UniswapV3PoolInfo[] memory);

    /**
     * @notice Gets the list of tokens and fees to periodically refresh for implied volatility.
     * @return The token refresh list.
     */
    function getTokenFeeTierRefreshList() external view returns (UniswapV3PoolInfo[] memory);

    // The below was heavily inspired by Aloe Finance's Blend

    /**
     * @notice Accesses the most recently stored metadata for a given Uniswap pool
     * @dev These values may or may not have been initialized and may or may not be
     * up to date. `tickSpacing` will be non-zero if they've been initialized.
     * @param pool The Uniswap pool for which metadata should be retrieved
     * @return maxSecondsAgo The age of the oldest observation in the pool's oracle
     * @return gamma0 The pool fee minus the protocol fee on token0, scaled by 1e6
     * @return gamma1 The pool fee minus the protocol fee on token1, scaled by 1e6
     * @return tickSpacing The pool's tick spacing
     */
    function cachedPoolMetadata(IUniswapV3Pool pool)
        external
        view
        returns (uint32 maxSecondsAgo, uint24 gamma0, uint24 gamma1, int24 tickSpacing);

    /**
     * @notice Accesses any of the 25 most recently stored fee growth structs
     * @dev The full array (idx=0,1,2...24) has data that spans *at least* 24 hours
     * @param pool The Uniswap pool for which fee growth should be retrieved
     * @param idx The index into the storage array
     * @return feeGrowthGlobal0X128 Total pool revenue in token0, as of timestamp
     * @return feeGrowthGlobal1X128 Total pool revenue in token1, as of timestamp
     * @return timestamp The time at which snapshot was taken and stored
     */
    function feeGrowthGlobals(IUniswapV3Pool pool, uint256 idx)
        external
        view
        returns (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128, uint32 timestamp);

    /**
     * @notice Returns indices that the contract will use to access `feeGrowthGlobals`
     * @param pool The Uniswap pool for which array indices should be fetched
     * @return read The index that was closest to 24 hours old last time `estimate24H` was called
     * @return write The index that was written to last time `estimate24H` was called
     */
    function feeGrowthGlobalsIndices(IUniswapV3Pool pool) external view returns (uint8 read, uint8 write);

    /**
     * @notice Updates cached metadata for a Uniswap pool. Must be called at least once
     * in order for volatility to be determined. Should also be called whenever
     * protocol fee changes
     * @param pool The Uniswap pool to poke
     */
    function cacheMetadataFor(IUniswapV3Pool pool) external;

    /**
     * @notice Provides multiple estimates of IV using all stored `feeGrowthGlobals` entries for `pool`
     * @dev This is not meant to be used on-chain, and it doesn't contribute to the oracle's knowledge.
     * Please use `estimate24H` instead.
     * @param pool The pool to use for volatility estimate
     * @return impliedVolatility The array of volatility estimates, scaled by 1e18
     */
    function lens(IUniswapV3Pool pool) external view returns (uint256[25] memory impliedVolatility);

    /**
     * @notice Estimates 24-hour implied volatility for a Uniswap pool.
     * @param pool The pool to use for volatility estimate
     * @return impliedVolatility The estimated volatility, scaled by 1e18
     */
    function estimate24H(IUniswapV3Pool pool) external returns (uint256 impliedVolatility);
}
