// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

interface IChainlinkPriceOracleAdmin {
    /**
     * @notice Emitted when a price feed for an ERC20 token is set.
     * @param token The contract address for the ERC20.
     * @param priceFeed The price feed address.
     */
    event PriceFeedSet(address indexed token, address indexed priceFeed);

    /**
     * /////////////// ADMIN FUNCTIONS ///////////////
     */

    /**
     * @notice Sets the oracle contract address.
     * @param oracle The contract address for the oracle adapter.
     * @return The set token and price feed.
     */
    function setPriceFeed(address token, address priceFeed) external returns (address, address);
}
