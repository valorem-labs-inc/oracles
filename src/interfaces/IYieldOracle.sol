// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

/**
 * @notice This is an interface for contracts providing token yields.
 * This is used internally in order to provide a uniform way of interacting with
 * various yield oracles. An external yield oracle can be used seamlessly
 * by being wrapped in a contract implementing this interface.
 */
interface IYieldOracle {
    /**
     * @notice Retrieves the yield of a given token address
     * @param token The ERC20 token address for which to retrieve yield
     * @return tokenYield The yield for this given token
     */
    function getTokenYield(address token)
        external 
        view 
        returns (uint256 tokenYield);

    function decmimals() external view returns (uint256);
}