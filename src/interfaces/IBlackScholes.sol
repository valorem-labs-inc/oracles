// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

/**
 * @notice Interface for pricing strategies via Black Scholes method. Volatility
 * is derived from the Uniswap pool.
 * Risk free rate can be estimated as Aave's USDC deposit rate (see 
 * https://linen.app/interest-rates/earn/historical).
 * 
 */
interface IBlackScholes {
    function getPutPremium(
        IUniswapV3Pool pool,
        uint256 assetPrice,
        uint256 exercisePrice,
        uint256 timeToExpiry,
        uint256 riskFreeRate
    )
    external
    view
    returns (uint256 putPremium);

    function getCallPremium(
        IUniswapV3Pool pool,
        uint256 assetPrice,
        uint256 exercisePrice,
        uint256 timeToExpiry,
        uint256 riskFreeRate
    )
    external
    view 
    returns (uint256 callPremium);

    function setVolatilityOracle(IVolatilityOracle oracle);

    // TODO: find an on-chain source for the USDC yield in e.g. compound, Aave
    // function setRiskFreeRateOracle(IRiskFreeRateOracle oracle);
}