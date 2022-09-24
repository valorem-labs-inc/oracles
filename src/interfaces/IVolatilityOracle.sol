// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

/**
 * @notice This is an interface for contracts providing historical volatility,
 * implied volatility, or both.
 * This is used internally in order to provide a uniform way of interacting with
 * various volatility oracles. An external volatility oracle can be used seamlessly
 * by being wrapped in a contract implementing this interface.
 */
interface IVolatilityOracle {
    /**
     * @notice Retrieves the historical volatility of a ERC20 token.
     * @param token The ERC20 token for which to retrieve historical volatility.
     * @return historicalVolatility The historical volatility of the token, scaled by 1e18
     */
    function getHistoricalVolatility(address token) external view returns (uint256 historicalVolatility);

    /**
     * @notice Retrieves the implied volatility of a ERC20 token.
     * @param tokenA The ERC20 token for which to retrieve historical volatility.
     * @param tokenB The ERC20 token for which to retrieve historical volatility.
     * @return impliedVolatility The implied volatility of the token, scaled by 1e18
     */
    function getImpliedVolatility(address tokenA, address tokenB) external view returns (uint256 impliedVolatility);

    /**
     * @notice Returns the scaling factor for the volatility
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint16 scale);
}
