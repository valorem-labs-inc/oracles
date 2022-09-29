// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/ICompoundV3YieldOracleAdmin.sol";
import "./interfaces/IComet.sol";
import "./interfaces/IERC20.sol";
import "./utils/Keep3rV2Job.sol";

contract CompoundV3YieldOracle is ICompoundV3YieldOracleAdmin, Keep3rV2Job {
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
     * //////////// ICompoundV3YieldOracleAdmin //////////////
     */

    /// @inheritdoc ICompoundV3YieldOracleAdmin
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

    /// @inheritdoc ICompoundV3YieldOracleAdmin
    function latchCometRate(address token) external returns (uint256) {
        revert();
    }

    /// @inheritdoc ICompoundV3YieldOracleAdmin
    function getCometSnapshots() external view returns (SupplyRateSnapshot[] memory snapshots) {
        revert();
    }

    /// @inheritdoc ICompoundV3YieldOracleAdmin
    function setCometSnapshotBufferSize(address token, uint16 newSize) external returns (uint16) {
        return _setCometSnapShotBufferSize(token, newSize);
    }

    /**
     * /////////// Internal ///////////
     */

    function _setCometSnapShotBufferSize(address token, uint16 newSize) internal returns (uint26) {

    }

    function _latchSupplyRate(address token) internal returns (uint256 supplyRate) {
        IComet comet = tokenAddressToComet[token];
        if (comet == address(0)) {
            revert InvalidCometAddress();
        }



        emit CometRateLatched(token, comet, supplyRate);
    }
}
