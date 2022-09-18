// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IVolatilityOracleAdapter.sol";

import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "../utils/Keep3rV2Job.sol";

/**
 * @notice This contract adapts the Aloe capital volatility oracle
 * contract from https://github.com/aloelabs/aloe-blend.
 */
interface IAloeVolatilityOracleAdapter is IVolatilityOracleAdapter {
    /**
     * ////////// STRUCTS /////////////
     */
    struct UniswapV3PoolInfo {
        address tokenA;
        address tokenB;
        IVolatilityOracleAdapter.UniswapV3FeeTier feeTier;
    }

    /**
     * /////////// EVENTS /////////////
     */

    /**
     * @notice Emitted when the uniswap v3 factory contract address is set.
     * @param v3Factory The address of the uniswap v3 factory contract.
     */
    event UniswapV3FactorySet(address v3Factory);

    /**
     * @notice Emitted when the Aloe volatility oracle contract address is set.
     * @param aloeOracle The contract address for the aloe oracle.
     */
    event AloeOracleSet(address aloeOracle);

    /**
     * @notice Emitted when the implied volatility cache is updated.
     * @param timestamp The timestamp of when the cache is updated.
     */
    event AloeVolatilityOracleCacheUpdated(uint256 timestamp);

    /**
     * @notice Emitted when the implied volatility for a given token is updated.
     * @param tokenA The ERC20 contract address of the token.
     * @param tokenB The ERC20 contract address of the token.
     * @param feeTier The UniswapV3 fee tier.
     * @param volatility The implied volatility of the token.
     * @param timestamp The timestamp of the refresh.
     */
    event TokenVolatilityUpdated(address tokenA, address tokenB, uint24 feeTier, uint256 volatility, uint256 timestamp);

    /// @notice Emitted when the token refresh list is set.
    event TokenRefreshListSet();

    /// @notice Thrown when the passed v3 factory address is invalid.
    error InvalidUniswapV3Factory();

    /// @notice Thrown when invalid parameters are passed to setUniswapV3Pool.
    error InvalidUniswapV3Pool();

    /// @notice Thrown when the passed Aloe volatility oracle address is invalid.
    error InvalidAloeOracle();

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

    /// function addTokenToRefreshList(address token) external returns (address);

    /**
     * /////////////// ADMIN FUNCTIONS ///////////////
     */

    /**
     * @notice Sets the uniswap v3 factory contract address.
     * @dev Used to get addresses of uniswap v3 pools for specific tokens.
     * @param factory The address of the uniswap v3 factory contract.
     * @return The address of the uniswap v3 factory contract.
     */
    function setV3Factory(address factory) external returns (address);

    /**
     * @notice Sets the aloe voltaility oracle contract address.
     * @param oracle The contract address for the aloe volatility oracle.
     * @return The contract address for the aloe volatility oracle.
     */
    function setAloeOracle(address oracle) external returns (address);
}
