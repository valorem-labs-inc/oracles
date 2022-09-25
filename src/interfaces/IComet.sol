// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

/// @dev Taken from https://github.com/compound-developers/compound-3-developer-faq/blob/master/contracts/MyContract.sol

interface IComet {
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    struct UserBasic {
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        uint8 _reserved;
    }

    struct TotalsBasic {
        uint64 baseSupplyIndex;
        uint64 baseBorrowIndex;
        uint64 trackingSupplyIndex;
        uint64 trackingBorrowIndex;
        uint104 totalSupplyBase;
        uint104 totalBorrowBase;
        uint40 lastAccrualTime;
        uint8 pauseFlags;
    }

    struct UserCollateral {
        uint128 balance;
        uint128 _reserved;
    }

    struct RewardOwed {
        address token;
        uint256 owed;
    }

    struct TotalsCollateral {
        uint128 totalSupplyAsset;
        uint128 _reserved;
    }

    function supply(address asset, uint256 amount) external;
    function supplyTo(address dst, address asset, uint256 amount) external;
    function supplyFrom(address from, address dst, address asset, uint256 amount) external;

    function transfer(address dst, uint256 amount) external returns (bool);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function transferAsset(address dst, address asset, uint256 amount) external;
    function transferAssetFrom(address src, address dst, address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;
    function withdrawTo(address to, address asset, uint256 amount) external;
    function withdrawFrom(address src, address to, address asset, uint256 amount) external;

    function approveThis(address manager, address asset, uint256 amount) external;
    function withdrawReserves(address to, uint256 amount) external;

    function absorb(address absorber, address[] calldata accounts) external;
    function buyCollateral(address asset, uint256 minAmount, uint256 baseAmount, address recipient) external;
    function quoteCollateral(address asset, uint256 baseAmount) external view returns (uint256);

    function getAssetInfo(uint8 i) external view returns (AssetInfo memory);
    function getAssetInfoByAddress(address asset) external view returns (AssetInfo memory);
    function getReserves() external view returns (int256);
    function getPrice(address priceFeed) external view returns (uint256);

    function isBorrowCollateralized(address account) external view returns (bool);
    function isLiquidatable(address account) external view returns (bool);

    function totalSupply() external view returns (uint256);
    function totalBorrow() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function borrowBalanceOf(address account) external view returns (uint256);

    function pause(bool supplyPaused, bool transferPaused, bool withdrawPaused, bool absorbPaused, bool buyPaused)
        external;
    function isSupplyPaused() external view returns (bool);
    function isTransferPaused() external view returns (bool);
    function isWithdrawPaused() external view returns (bool);
    function isAbsorbPaused() external view returns (bool);
    function isBuyPaused() external view returns (bool);

    function accrueAccount(address account) external;
    function getSupplyRate(uint256 utilization) external view returns (uint64);
    function getBorrowRate(uint256 utilization) external view returns (uint64);
    function getUtilization() external view returns (uint256);

    function governor() external view returns (address);
    function pauseGuardian() external view returns (address);
    function baseToken() external view returns (address);
    function baseTokenPriceFeed() external view returns (address);
    function extensionDelegate() external view returns (address);
}
