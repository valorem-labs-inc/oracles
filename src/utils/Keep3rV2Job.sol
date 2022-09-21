// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IKeep3rV2Job.sol";

import "keep3r/solidity/interfaces/IKeep3r.sol";

abstract contract Keep3rV2Job is IKeep3rV2Job {
    address public keep3r;
    address internal admin;

    // taken from https://docs.keep3r.network/core/jobs#simple-keeper
    modifier validateAndPayKeeper(address _keeper) {
        _isValidKeeper(_keeper);
        _;
        IKeep3r(keep3r).worked(_keeper);
    }

    modifier requiresAdmin(address sender) {
        require(sender == admin, "!ADMIN");
        _;
    }

    function setKeep3r(address _keep3r) public requiresAdmin(msg.sender) {
        _setKeep3r(_keep3r);
    }

    function getKeep3r() public view returns (address) {
        return keep3r;
    }

    function _setKeep3r(address _keep3r) internal {
        keep3r = _keep3r;
        emit Keep3rSet(_keep3r);
    }

    function _isValidKeeper(address _keeper) internal {
        if (!IKeep3r(keep3r).isKeeper(_keeper)) {
            revert InvalidKeeper();
        }
    }
}
