// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

interface IOracleAdmin {
    /**
     * @notice Emitted when the oracle contract address is set.
     * @param oracle The contract address for the oracle.
     */
    event OracleSet(address indexed oracle);

    /**
     * @notice Emitted when a new admin address is set for the contract.
     * @param admin The new admin address.
     */
    event AdminSet(address indexed admin);

    /**
     * /////////////// ADMIN FUNCTIONS ///////////////
     */

    /**
     * @notice Sets the admin address for this contract.
     * @param _admin The new admin address for this contract. Cannot be 0x0.
     */
    function setAdmin(address _admin) external;

    /**
     * @notice Sets the oracle contract address.
     * @param oracle The contract address for the oracle adapter.
     * @return The contract address for the oracle adapter.
     */
    function setOracle(address oracle) external returns (address);
}
