// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "solmate/tokens/ERC20.sol";

/**
 * @notice This is an interface for contracts providing the price of a token, in
 * USD.
 * This is used internally in order to provide a uniform way of interacting with
 * various price oracles. An external price oracle can be used seamlessly
 * by being wrapped in a contract implementing this interface.
 */
interface IPriceOracle {
    /**
     * @notice
     * @param token The ERC20 token to retrieve the USD price for
     * @return price The price of the token in USD
     */
    function getPriceUSD(address token) external view returns (uint256 price);

    /**
     * @notice Returns the scaling factor for the price
     * @return scale The power of 10 by which the return is scaled
     */
    function scale() external view returns (uint8 scale);
}
