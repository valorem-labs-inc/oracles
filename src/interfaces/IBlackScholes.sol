// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./IVolatilityOracle.sol";
import "./IPriceOracle.sol";
import "./IYieldOracle.sol";

import "valorem-core/interfaces/IOptionSettlementEngine.sol";

/**
 * @notice Interface for pricing strategies via Black Scholes method. Volatility
 * is derived from the Uniswap pool.
 */
interface IBlackScholes {
    /**
     * @notice Returns the long call premium for the supplied valorem optionId
     */
    function getLongCallPremium(uint256 optionId) external view returns (uint256 callPremium);

    /**
     * @notice Returns the long call premium for the supplied valorem optionId
     */
    function getShortCallPremium(uint256 optionId) external view returns (uint256 callPremium);

    function getLongCallPremiumEx(
        uint256 optionId,
        IVolatilityOracleAdapter volatilityOracle,
        IPriceOracleAdapter priceOracle,
        IYieldOracle yieldOracle,
        IOptionSettlementEngine engine
    ) external view returns (uint256 callPremium);

    function getShortCallPremiumEx(
        uint256 optionId,
        IVolatilityOracleAdapter volatilityOracle,
        IPriceOracleAdapter priceOracle,
        IYieldOracle yieldOracle,
        IOptionSettlementEngine engine
    ) external view returns (uint256 callPremium);

    /**
     * @notice sets the oracle from which to retrieve historical or implied volatility
     */
    function setVolatilityOracle(IVolatilityOracleAdapter oracle) external;

    /**
     * @notice sets the oracle from which to retrieve the underlying asset price
     */
    function setPriceOracle(IPriceOracleAdapter oracle) external;

    /**
     * @notice sets the yield oracle for the risk free rate
     */
    function setYieldOracle(IYieldOracle oracle) external;

    /**
     * @notice sets the Valorem engine for retrieving options
     */
    function setValoremOptionSettlementEngine(IOptionSettlementEngine engine) external;
}
