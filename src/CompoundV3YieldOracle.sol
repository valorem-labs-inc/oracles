// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/ICompoundV3YieldOracleAdmin.sol";
import "./interfaces/IComet.sol";
// import "./utils/Admin.sol";

contract CompoundV3YieldOracle is ICompoundV3YieldOracleAdmin /*, Admin */ {
    /**
     * /////////// CONSTANTS ///////////////
     */
    address public constant COMET_USDC_ADDRESS = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /**
     * ///////////// STATE ///////////////
     */

    // TODO: ERC20 interface
    mapping(address => IComet) public tokenAddressToComet;

    constructor() {
        //admin = msg.sender;
        setCometAddress(USDC_ADDRESS, COMET_USDC_ADDRESS);
    }

    /**
     * ////////// IYieldOracle //////////
     */

    /// @dev compound III / comet is currently deployed/implemented only on USDC
    /// @inheritdoc IYieldOracle
    function getTokenYield(address token) public view returns (uint256 yield) {
        IComet comet = tokenAddressToComet[token];
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
     * //////////// ICompoundV3YieldOracleAdmin //////////////
     */

    /// @inheritdoc ICompoundV3YieldOracleAdmin
    function setCometAddress(address baseAssetErc20, address comet)
        public /* requiresAdmin(msg.sender) */
        returns (address, address)
    {
        if (baseAssetErc20 == address(0)) {
            revert InvalidTokenAddress();
        }
        if (comet == address(0)) {
            revert InvalidCometAddress();
        }

        IComet _comet = IComet(comet);
        tokenAddressToComet[baseAssetErc20] = _comet;

        emit CometSet(baseAssetErc20, comet);
        return (baseAssetErc20, comet);
    }
}
