// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IPriceOracleAdapter.sol";

import "solmate/auth/authorities/MultiRolesAuthority.sol";

/**
 * @notice This contract adapts the chainlink price oracle
 */
contract ChainlinkPriceOracleAdapter is IPriceOracleAdapter, MultiRolesAuthority {
    constructor () {

    }

    /**
    ///////////// IPriceOracleAdapter ////////////
     */

    /**
     * @notice
     * @param token The ERC20 token to retrieve the USD price for
     * @return price The price of the token in USD
     */
    function getPriceUSD(address token) external view returns (uint256 price) {

    }

    /**
     * @notice Returns the scaling factor for the price
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint16 scale) {

    }

    /**
    /////////////// ADMIN FUNCTIONS /////////////////
     */
    function setChainlinkOracle() {

    }
}