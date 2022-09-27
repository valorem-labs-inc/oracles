// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/interfaces/ICompoundV3YieldOracleAdmin.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IComet.sol";

import "../src/CompoundV3YieldOracle.sol";

contract CompoundV3YieldOracleTest is Test {
    event LogString(string topic);
    event LogAddress(string topic, address info);
    event LogUint(string topic, uint256 info);
    event LogInt(string topic, int256 info);

    event CometSet(address indexed token, address indexed comet);

    IComet public constant COMET_USDC = IComet(0xc3d688B66703497DAA19211EEdff47f25384cdc3);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    CompoundV3YieldOracle public oracle;

    function setUp() public {
        oracle = new CompoundV3YieldOracle();
    }

    function testConstructor() public {
        assertEq(address(COMET_USDC), address(oracle.tokenAddressToComet(USDC)));
        assertEq(address(0), address(oracle.tokenAddressToComet(IERC20(address(0)))));
    }

    function testSetComet() public {
        vm.expectRevert(ICompoundV3YieldOracleAdmin.InvalidTokenAddress.selector);
        oracle.setCometAddress(address(0), address(COMET_USDC));

        vm.expectRevert(ICompoundV3YieldOracleAdmin.InvalidCometAddress.selector);
        oracle.setCometAddress(address(this), address(0));

        // e.g. if 'this' were an ERC20
        vm.expectEmit(true, true, false, false);
        emit CometSet(address(this), address(COMET_USDC));
        oracle.setCometAddress(address(this), address(COMET_USDC));
        assertEq(address(COMET_USDC), address(oracle.tokenAddressToComet(IERC20(address(this)))));
    }

    function testGetYield() public {
        vm.expectRevert(
            abi.encodeWithSelector(ICompoundV3YieldOracleAdmin.CometAddressNotSpecifiedForToken.selector, address(this))
        );
        oracle.getTokenYield(address(this));

        uint256 yield = oracle.getTokenYield(address(USDC));
        emit LogUint("usdc yield", yield);

        // blockno 15441384
        assertEq(yield, 723951975);
    }
}
