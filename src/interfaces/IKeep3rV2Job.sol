// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IKeep3rV2Job {
    event Keep3rSet(address keep3rAddress);

    error InvalidKeeper();

    function getKeep3r() external view returns (address);

    function setKeep3r(address _keep3rAddress) external;
}