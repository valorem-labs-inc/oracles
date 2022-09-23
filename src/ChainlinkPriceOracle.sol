// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/IPriceOracle.sol";

import "solmate/auth/authorities/MultiRolesAuthority.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IAdmin.sol";

/**
 * @notice This contract adapts the chainlink price oracle
 */
contract ChainlinkPriceOracle is IPriceOracle {
    /**
     * //////////// STATE /////////////
     */

    mapping(address => address) public tokenToUSDPriceFeed;


    /**
     * ///////////// IPriceOracle ////////////
     */

    /// IPriceOracle
    function getPriceUSD(address token) external view returns (uint256 price, uint8 scale) {
        address aggregator = _getAggregator(token);
        (int256 rawPrice, scale) = _getPrice(aggregator);
        price = uint256(rawPrice);
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
