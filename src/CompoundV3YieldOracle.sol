// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/ICompoundV3YieldOracle.sol";
import "./interfaces/IComet.sol";
import "./interfaces/IERC20.sol";
import "./utils/Keep3rV2Job.sol";

contract CompoundV3YieldOracle is ICompoundV3YieldOracle, Keep3rV2Job {
    /**
     * /////////// CONSTANTS ///////////////
     */
    address public constant COMET_USDC_ADDRESS = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /**
     * ///////////// STATE ///////////////
     */

    // token to array index mapping
    mapping(IERC20 => uint16) public tokenToSnapshotIndex;

    mapping(IERC20 => SupplyRateSnapshot[]) public tokenToSnapshotArray;

    mapping(IERC20 => IComet) public tokenAddressToComet;

    constructor(address _keep3r) {
        admin = msg.sender;
        setCometAddress(USDC_ADDRESS, COMET_USDC_ADDRESS);
        keep3r = _keep3r;
    }

    /**
     * ////////// IYieldOracle //////////
     */

    /// @dev compound III / comet is currently deployed/implemented only on USDC
    /// @inheritdoc IYieldOracle
    function getTokenYield(address token) public view returns (uint256 yield) {
        IComet comet = tokenAddressToComet[IERC20(token)];
        if (address(comet) == address(0)) {
            revert CometAddressNotSpecifiedForToken(token);
        }

        uint256 utilization = comet.getUtilization();
        uint64 supplyRate = comet.getSupplyRate(utilization);
        yield = uint256(supplyRate);
    }

    /// @inheritdoc IYieldOracle
    function scale() public pure returns (uint8) {
        return 18;
    }

    /**
     * //////////// Keep3r ////////////
     */

    function work() external validateAndPayKeeper(msg.sender) {
        revert();
    }

    /**
     * //////////// ICompoundV3YieldOracle //////////////
     */

    /// @inheritdoc ICompoundV3YieldOracle
    function setCometAddress(address baseAssetErc20, address comet)
        public
        requiresAdmin(msg.sender)
        returns (address, address)
    {
        if (baseAssetErc20 == address(0)) {
            revert InvalidTokenAddress();
        }
        if (comet == address(0)) {
            revert InvalidCometAddress();
        }

        tokenAddressToComet[IERC20(baseAssetErc20)] = IComet(comet);

        emit CometSet(baseAssetErc20, comet);
        return (baseAssetErc20, comet);
    }

    /// @inheritdoc ICompoundV3YieldOracle
    function latchCometRate(address token) external requiresAdmin(msg.sender) returns (uint256) {
        return _latchSupplyRate(token);
    }

    /// @inheritdoc ICompoundV3YieldOracle
    function getCometSnapshots(address token) public view returns (uint16 idx, SupplyRateSnapshot[] memory snapshots) {
        IERC20 _token = IERC20(token);
        idx = tokenToSnapshotIndex[_token];
        snapshots = tokenToSnapshotArray[_token];
    }

    /// @inheritdoc ICompoundV3YieldOracle
    function setCometSnapshotBufferSize(address token, uint16 newSize)
        external
        requiresAdmin(msg.sender)
        returns (uint16)
    {
        return _setCometSnapShotBufferSize(token, newSize);
    }

    /**
     * /////////// Internal ///////////
     */

    function _setCometSnapShotBufferSize(address token, uint16 newSize) internal returns (uint16) {
        SupplyRateSnapshot[] storage snapshots = tokenToSnapshotArray[IERC20(token)];
        if (newSize <= snapshots.length) {
            return uint16(snapshots.length);
        }
        // increase array size
        for (uint16 i = 0; i < newSize - uint16(snapshots.length); i++) {
            // add uninitialized snapshot to extend length of array
            snapshots.push(SupplyRateSnapshot(0, 0));
        }

        emit CometSnapshotArraySizeSet(token, newSize);
        return newSize;
    }

    function _latchSupplyRate(address token) internal returns (uint256 supplyRate) {
        IComet comet;
        IERC20 _token = IERC20(token);
        uint16 idx = tokenToSnapshotIndex[_token];
        SupplyRateSnapshot[] storage snapshots = tokenToSnapshotArray[_token];
        uint16 idxNext = (idx + 1) % uint16(snapshots.length);

        (supplyRate, comet) = _getSupplyRateYieldForUnderlyingAsset(token);

        // update the cached rate
        snapshots[idxNext].timestamp = block.timestamp;
        snapshots[idxNext].supplyRate = supplyRate;

        emit CometRateLatched(token, address(comet), supplyRate);
    }

    function _getSupplyRateYieldForUnderlyingAsset(address token) public view returns (uint256 yield, IComet comet) {
        comet = tokenAddressToComet[IERC20(token)];
        if (address(comet) == address(0)) {
            revert CometAddressNotSpecifiedForToken(token);
        }

        uint256 utilization = comet.getUtilization();
        uint64 supplyRate = comet.getSupplyRate(utilization);
        yield = uint256(supplyRate);
    }
}
