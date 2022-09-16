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
    /////////// EVENTS /////////////
     */

    /**
     * @notice Emitted when the uniswap v3 factory contract address is set.
     * @param v3Factory The address of the uniswap v3 factory contract.
     */
    event UniswapV3FactorySet(address v3Factory);

    /**
     * @notice Emitted when the fee and comparison token for the v3 pool are set.
     * @param token One of the ERC20 token addresses for the v3 pool.
     * @param fee The fee rate for the uniswap v3 pool.
     */
    event UniswapV3PoolSet(address token, uint24 fee);

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
     * @param token The ERC20 contract address of the token.
     * @param volatility The implied volatility of the token.
     * @param timestamp The timestamp of the refresh.
     */
    event TokenVolatilityUpdated(address token, uint256 volatility, uint256 timestamp);

    /// @notice Thrown when the passed v3 factory address is invalid.
    error InvalidUniswapV3Factory();

    /// @notice Thrown when invalid parameters are passed to setUniswapV3Pool.
    error InvalidUniswapV3Pool();

    /// @notice Thrown when the passed Aloe volatility oracle address is invalid.
    error InvalidAloeOracle();

    /**
    ////////// HELPERS ///////////
     */

    /**
     * @notice Retrieves the uniswap v3 pool for passed ERC20 address plus arguments 
        from setUniswapV3Pool.
     * @param token The contract address of the ERC20 for which to retrieve the v3 pool.
     * @return pool The uniswap v3 pool for the supplied token.
     */
    function getV3PoolForTokenAddress(address token) external view returns (IUniswapV3Pool pool);

    /**
     * @notice Updates the cached implied volatility for the tokens in the refresh list. 
     * @return timestamp The timestamp of the cache refresh.
     */
    function refreshVolatilityCache() external returns (uint256 timestamp); 

    /**
    ////////// TOKEN REFRESH LIST //////////
     */

    /**
     * @notice Sets the list of tokens to periodically refresh for implied volatility.
     * @param list The token refresh list.
     * @return The token refresh list.
     */
    function setTokenRefreshList(address[] memory list) external returns(address[] memory);

    /**
     * @notice Gets the list of tokens to periodically refresh for implied volatility.
     * @param list The token refresh list.
     * @return The token refresh list.
     */
    function getTokenRefreshList(address[] memory list) external view returns(address[] memory);

    function addTokenToRefreshList(address token) external returns(address);

    /**
    /////////////// ADMIN FUNCTIONS ///////////////
     */
    
    /**
     * @notice Sets the comparison token (e.g. DAI) and fee rate for the uniswap v3 pool.
     * @param token The ERC20 contract address for the comparison token.
     * @param fee The uniswap v3 pool fee rate.
     * @return The token address and fee.
     */
    function setUniswapV3Pool(address token, uint24 fee) external returns (address, uint24);

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