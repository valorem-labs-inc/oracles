// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IPriceOracleAdapter.sol";

import "solmate/auth/authorities/MultiRolesAuthority.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @notice This contract adapts the chainlink price oracle
 */
contract ChainlinkPriceOracleAdapter is IPriceOracleAdapter, MultiRolesAuthority {
    AggregatorV3Interface public chainlinkPriceOracle;

    constructor (address priceOracleAddress) 
        MultiRolesAuthority(msg.sender, Authority(address(0))) 
    {
        setRoleCapability(0, ChainlinkPriceOracleAdapter.setChainlinkOracle.selector, true);
        chainlinkPriceOracle = AggregatorV3Interface(priceOracleAddress);
    }

    /**
    ///////////// IPriceOracleAdapter ////////////
     */

    /**
     * @notice
     * @param token The ERC20 token to retrieve the USD price for
     * @return price The price of the token in USD
     */
    function getPriceUSD(address token) external view returns (int256 price) {
        (, price,,,) = chainlinkPriceOracle.latestRoundData();
        return price;
    }

    /**
     * @notice Returns the scaling factor for the price
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint16) {
        uint8 decimals = chainlinkPriceOracle.decimals();
        return uint16(decimals);
    }

    /**
    /////////////// ADMIN FUNCTIONS /////////////////
     */
    function setChainlinkOracle(address priceOracleAddress) external requiresAuth {
        chainlinkPriceOracle = AggregatorV3Interface(priceOracleAddress);
    }
}