// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./IVolatilityOracle.sol";
import "./IPriceOracle.sol";
import "./IYieldOracle.sol";

import "valorem-core/interfaces/IOptionSettlementEngine.sol";
import "solmate/tokens/ERC20.sol";

/**
 * @notice Interface for pricing strategies via Black Scholes method. Volatility
 * is derived from the Uniswap pool.
 */
interface IBlackScholes {
    /**
     * @notice Returns the call premium for the supplied valorem optionId
     */
    function getCallPremium(
        uint256 optionId
    )
    external
    view 
    returns (uint256 callPremium);

    function getCallPremiumEx(
        uint256 optionId,
        IVolatilityOracle volatilityOracle,
        IPriceOracle priceOracle,
        IYieldOracle yieldOracle,
        IOptionSettlementEngine engine
    )
    external
    view 
    returns (uint256 callPremium);

    /**
     * @notice sets the oracle from which to retrieve historical or implied volatility
     */
    function setVolatilityOracle(IVolatilityOracle oracle);

    /**
     * @notice sets the oracle from which to retrieve the underlying asset price
     */
    function setPriceOracle(IPriceOracle oracle);

    /**
     * @notice sets the yield oracle for the risk free rate
     */
    function setYieldOracle(IYieldOracle oracle);

    /**
     * @notice sets the Valorem engine for retrieving options
     */
    function setValoremOptionSettlementEngine(IOptionSettlementEngine engine);
}