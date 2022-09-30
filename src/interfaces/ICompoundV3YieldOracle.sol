// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./IYieldOracle.sol";

interface ICompoundV3YieldOracle is IYieldOracle {
    /**
     * /////////// STRUCTS /////////////
     */

    struct SupplyRateSnapshot {
        uint256 timestamp;
        uint256 supplyRate;
    }

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
     * @notice Emitted when the supply rate is latched in the given comet pool.
     * @param token The token address of the base asset for the comet contract.
     * @param comet The address of the comet contract.
     * @param supplyRate The latched supply rate of the comet contract.
     */
    event CometRateLatched(address indexed token, address indexed comet, uint256 supplyRate);

    /**
     * @notice Emitted when the comet snapshot array size is increased for a given token.
     * @param token The token address of the base asset for which we're increasing the comet 
     * snapshot array size.
     * @param newSize The new size of the array.
     */
     event CometSnapshotArraySizeSet(address indexed token, uint16 newSize);

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

    /**
     * @notice Latches the current supply rate for the provided erc20 base asset.
     * @dev Reverts if setCometAddress was not preiously called with the supplied token.
     * @param token The address of the erc20 base asset.
     * @return The latched supply rate.
     */
    function latchCometRate(address token) external returns (uint256);

    /**
     * @notice Gets the current list of snapshots of compound v3 supply rates
     * @param token The address of the erc20 base asset for which to return the supply
     * rate snapshots.
     * @return The snapshots currently stored in the oracle, along with associated 'next' index.
     */
    function getCometSnapshots(address token) external view returns (uint16, SupplyRateSnapshot[] memory);

    /**
     * @notice Increases the size of the supply rate buffer. Caller must pay the associated
     * gas costs for increasing the size of the array.
     * @dev Reverts if newSize is less than current size. Max size is 2^16/~65k
     * @param token The erc20 underlying asset for which to increase the size of the comet buffer.
     * @param newSize The new size of the array.
     * @return New size of the array.
     */
    function setCometSnapshotBufferSize(address token, uint16 newSize) external returns (uint16);
}
