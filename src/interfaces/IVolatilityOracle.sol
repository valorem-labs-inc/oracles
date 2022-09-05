// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @notice This is an interface for contracts providing historical volatility,
 * implied volatility, or both.
 * This is used internally in order to provide a uniform way of interacting with 
 * various volatility oracles. An external volatility oracle can be used seamlessly
 * by being wrapped in a contract implementing this interface.
 */
interface IVolatilityOracle {
    /**
     * @notice Retrieves the historical volatility of a Uniswap pool
     * @param pool The Uniswap pool to use for a volatility estimate
     * @return historicalVolatility The historical volatility of the pool, scaled by 1e18
     */
    function getHistoricalVolatility(IUniswapV3Pool pool) 
        external 
        view 
        returns (uint256 historicalVolatility);

    /**
     * @notice Retrieves the implied volatility of a Uniswap pool
     * @param pool The Uniswap pool to use for a volatility estimate
     * @return impliedVolatility The implied volatiltiy of the pool, scaled by 1e18
     */
    function getImpliedVolatility(IUniswapV3Pool pool) 
        external 
        view 
        returns (uint256 impliedVolatility);
}