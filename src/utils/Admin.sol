// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IAdmin.sol";

abstract contract Admin is IAdmin {
    address internal admin;

    modifier requiresAdmin() {
        require(msg.sender == admin, "!ADMIN");
        _;
    }

    function setAdmin(address _admin) external requiresAdmin {
        require(_admin != address(0x0), "INVALID ADMIN");
        admin = _admin;
        emit AdminSet(_admin);
    }
}
