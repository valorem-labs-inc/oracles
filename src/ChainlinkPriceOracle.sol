// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/IPriceOracle.sol";
import "./interfaces/IChainlinkPriceOracleAdmin.sol";
import "./interfaces/IERC20.sol";

import "./utils/Admin.sol";

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @notice This contract adapts the chainlink price oracle. It stores a mapping from
 * ERC20 contract address to a chainlink price feed.
 */
contract ChainlinkPriceOracle is IPriceOracle, IChainlinkPriceOracleAdmin, Admin {
    /**
     * //////////// STATE /////////////
     */

    mapping(IERC20 => AggregatorV3Interface) public tokenToUSDPriceFeed;

    constructor() {
        admin = msg.sender;
    }

    /**
     * ///////////// IPriceOracle ////////////
     */

    /// @inheritdoc IPriceOracle
    function getPriceUSD(IERC20 token) external view returns (uint256 price, uint8 scale) {
        AggregatorV3Interface aggregator = _getAggregator(token);
        (int256 rawPrice, uint8 _scale) = _getPrice(aggregator);
        price = uint256(rawPrice);
        scale = _scale;
    }

    /**
     * ///////////// IChainlinkPriceOracleAdmin ////////////
     */

    /// @inheritdoc IChainlinkPriceOracleAdmin
    function setPriceFeed(IERC20 token, AggregatorV3Interface priceFeed)
        external
        requiresAdmin(msg.sender)
        returns (address, address)
    {
        // todo: validate token and price feed
        tokenToUSDPriceFeed[token] = priceFeed;
        emit PriceFeedSet(address(token), address(priceFeed));
        return (address(token), address(priceFeed));
    }

    /**
     * /////////// INTERNAL ////////////
     */

    function _getPrice(AggregatorV3Interface aggregator) internal view returns (int256 price, uint8 decimals) {
        /// @dev N.b. this is not a spot price from a particular dex. Using chainlink 
        /// aggregators imparts resistance to flash price movement attacks.
        (, price,,,) = aggregator.latestRoundData();
        decimals = aggregator.decimals();
        return (price, decimals);
    }

    function _getAggregator(IERC20 token) internal view returns (AggregatorV3Interface aggregator) {
        return tokenToUSDPriceFeed[token];
    }
}
