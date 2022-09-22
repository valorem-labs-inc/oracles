// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/IPriceOracle.sol";

import "solmate/auth/authorities/MultiRolesAuthority.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IOracleAdmin.sol";

/**
 * @notice This contract adapts the chainlink price oracle
 */
contract ChainlinkPriceOracle is IPriceOracle {
    AggregatorV3Interface public chainlinkPriceOracle;

    constructor(address priceOracleAddress) {
        chainlinkPriceOracle = AggregatorV3Interface(priceOracleAddress);
    }

    /**
     * ///////////// IPriceOracleAdapter ////////////
     */

    /**
     * @notice
     * @param token The ERC20 token to retrieve the USD price for
     * @return price The price of the token in USD
     */
    function getPriceUSD(address token) external view returns (uint256) {
        (, int256 price,,,) = chainlinkPriceOracle.latestRoundData();
        // get rid of warnings
        uint256 tmp = uint256(uint160(token));
        uint256 price2 = uint256(price);
        return tmp + price2;
    }

    /**
     * @notice Returns the scaling factor for the price
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint8) {
        return chainlinkPriceOracle.decimals();
    }
}
