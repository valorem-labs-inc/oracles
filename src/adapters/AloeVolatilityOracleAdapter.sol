// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IVolatilityOracleAdapter.sol";

import "../libraries/aloe/interfaces/IVolatilityOracle.sol";
import "../libraries/aloe/VolatilityOracle.sol";

/**
 * @notice This contract adapts the Aloe capital volatility oracle 
 * contract from https://github.com/aloelabs/aloe-blend.
 */
contract AloeVolatilityOracleAdapter is IVolatilityOracleAdapter {
    /**
     * @notice Retrieves the historical volatility of a ERC20 token.
     * @param token The ERC20 token for which to retrieve historical volatility.
     * @return historicalVolatility The historical volatility of the token, scaled by 1e18
     */
    function getHistoricalVolatility(address token) external view returns (uint256 historicalVolatility) {
        revert("AloeVolatilityOracle does not implement historical volatility");
        return 0;
    }

    /**
     * @notice Retrieves the implied volatility of a ERC20 token.
     * @param token The ERC20 token for which to retrieve historical volatility.
     * @return impliedVolatility The implied volatiltiy of the token, scaled by 1e18
     */
    function getImpliedVolatility(address token) external view returns (uint256 impliedVolatility) {
        IUniswapV3Pool pool = getV3PoolForTokenAddress(token);
        return 0;
    }

    /**
     * @notice Returns the scaling factor for the volatility
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint16 scale) {
        return 0;
    }

    function getV3PoolForTokenAddress(address token) public view returns (IUniswapV3Pool pool) {

    }
}