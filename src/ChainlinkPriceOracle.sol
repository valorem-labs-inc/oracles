// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/IPriceOracle.sol";

import "solmate/auth/authorities/MultiRolesAuthority.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IAdmin.sol";

abstract contract ENS {
    function resolver(bytes32 node) public virtual view returns (Resolver);
}

abstract contract Resolver {
    function addr(bytes32 node) public virtual view returns (address);
}

/**
 * @notice This contract adapts the chainlink price oracle
 */
contract ChainlinkPriceOracle is IPriceOracle {
    ENS ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    /**
     * ///////////// IPriceOracleAdapter ////////////
     */

    /**
     * @notice Returns the price against USD for a specific ERC20, sourced from chainlink.
     * @param token The ERC20 token to retrieve the USD price for
     * @return price The price of the token in USD, scale The power of 10 by which the return is scaled
     */
    function getPriceUSD(address token) external view returns (uint256 price, uint8 scale) {
        address aggregator = _getAggregator(token);
        (int256 rawPrice, scale) = _getPrice(aggregator);
        price = uint256(rawPrice);
    }

    /**
     * @notice Returns the scaling factor for the price
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint8) {
        return chainlinkPriceOracle.decimals();
    }

    /**
     * @notice Internal resolver for getting token symbol .
     * @param address ERC20 address.
     * @return symbol Token symbol.
     */
    function getTokenSymbol(address token) public view returns(string symbol) {

    }

    /**
    /////////// INTERNAL ////////////
     */

    function _getPrice(address aggregator) internal view returns (int256 price, uint8 decimals) {
        (, int256 price,,,) = AggregatorV3Interface(aggregator).latestRoundData();
        decimals = AggregatorV3Interface(aggregator).decimals();
    }

    function _getAggregator(address token) internal view returns (address aggregator) {

    }

    /**
     * @notice Resolve ENS address to contract address.
     * @param node The ENS node to resolve.
     * @return The resolved contract address.
     */
    function resolve(bytes32 node) public view returns(address) {
        Resolver resolver = ens.resolver(node);
        return resolver.addr(node);
    }
}
