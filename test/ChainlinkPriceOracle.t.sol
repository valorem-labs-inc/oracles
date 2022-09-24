// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "forge-std/Test.sol";

import "../src/ChainlinkPriceOracle.sol";

/// for writeBalance
interface IERC20 {
    function balanceOf(address) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);
}

contract ChainlinkPriceOracleTest is Test {
    event LogString(string topic);
    event LogAddress(string topic, address info);
    event LogUint(string topic, uint256 info);
    event LogInt(string topic, int256 info);

    event AdminSet(address indexed admin);
    event PriceFeedSet(address indexed token, address indexed priceFeed);

    address private constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address private constant DAI_USD_FEED = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;

    ChainlinkPriceOracle public oracle;

    function setUp() public {
        oracle = new ChainlinkPriceOracle();
    }

    function testAdmin() public {
        // some random addr
        vm.prank(address(1));
        vm.expectRevert(bytes("!ADMIN"));
        oracle.setAdmin(address(this));

        vm.expectEmit(true, false, false, false);
        emit AdminSet(address(1));
        oracle.setAdmin(address(1));

        // address changes back to this, instead of 1
        vm.expectRevert(bytes("!ADMIN"));
        oracle.setAdmin(address(this));

        // test that setting price feed fails if not admin
        vm.expectRevert(bytes("!ADMIN"));
        address fakeErc20 = address(2);
        address fakeFeed = address(3);
        oracle.setPriceFeed(fakeErc20, fakeFeed);

        // succeeds if admin
        vm.prank(address(1));
        oracle.setPriceFeed(fakeErc20, fakeFeed);
    }

    function testSetPriceFeeds() public {
        vm.expectEmit(true, true, false, false);
        emit PriceFeedSet(DAI_ADDRESS, DAI_USD_FEED);
        oracle.setPriceFeed(DAI_ADDRESS, DAI_USD_FEED);

        // TODO: assert revert invalid feed/erc20
    }

    function testPriceFeeds() public {
        oracle.setPriceFeed(DAI_ADDRESS, DAI_USD_FEED);
        (uint256 price, uint8 scale) = oracle.getPriceUSD(DAI_ADDRESS);
        // TODO: assert revert if feed not initialized
        emit LogUint("dai price:", price);
        emit LogUint("dai scale:", uint256(scale));
    }
}
