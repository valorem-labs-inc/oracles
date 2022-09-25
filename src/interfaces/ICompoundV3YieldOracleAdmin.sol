// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./IYieldOracle.sol";

interface ICompoundV3YieldOracleAdmin is IYieldOracle {
    /**
     * /////////// EVENTS //////////////
     */

    /**
     * @notice Emitted when the comet contract address is set.
     * @param token The token address of the base asset for the comet contract.
     * @param comet The address of the set comet contract.
     */
    event CometSet(address indexed token, address indexed comet);

    /**
     * //////////// ERRORS ////////////
     */

    /**
     * @notice Emitted when the token supplied from getTokenYield had not
     * been previously registered with setCometAddresss.
     * @param token The token address requested.
     */
    error CometAddressNotSpecifiedForToken(address token);

    /// @notice Emitted for invalid token addresses supplied to setCometAddress
    error InvalidTokenAddress();

    /// @notice Emitted for invalid comet addresses supplied to setCometAddress
    error InvalidCometAddress();

    /**
     * ///////// ADMIN /////////
     */

    /**
     * @notice Adds the base asset erc20 address, comet contract pair for getting yield on the
     * base asset. Must be called before IYieldOracle.getTokenYield.
     * @param baseAssetErc20 The address of the underlying ERC20 contract
     * @param comet The address of the compound III/comet contract
     * @return The base asset's erc 20 address, the set comet address
     */
    function setCometAddress(address baseAssetErc20, address comet) external returns (address, address);
}
