// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "../interfaces/IAloeVolatilityOracleAdapter.sol";

import "../libraries/aloe/interfaces/IVolatilityOracle.sol";
import "../libraries/aloe/VolatilityOracle.sol";

import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "../utils/Keep3rV2Job.sol";

/**
 * @notice This contract adapts the Aloe capital volatility oracle
 * contract from https://github.com/aloelabs/aloe-blend.
 */
contract AloeVolatilityOracleAdapter is IAloeVolatilityOracleAdapter, Keep3rV2Job {
    /**
     * /////////// STATE ////////////
     */
    IUniswapV3Factory private uniswapV3Factory;
    IVolatilityOracle private aloeVolatilityOracle;

    // comparison token, e.g. DAI
    address private v3PoolTokenB;
    uint24 private v3PoolRate;

    // MultiRolesAuthority inehrited from Keep3rV2Job
    constructor(address v3Factory, address aloeOracle, address keep3r)
        MultiRolesAuthority(msg.sender, Authority(address(0)))
    {
        setRoleCapability(0, AloeVolatilityOracleAdapter.setUniswapV3Pool.selector, true);
        setRoleCapability(0, AloeVolatilityOracleAdapter.setAloeOracle.selector, true);
        setRoleCapability(0, Keep3rV2Job.setKeep3r.selector, true);

        uniswapV3Factory = IUniswapV3Factory(v3Factory);
        aloeVolatilityOracle = IVolatilityOracle(aloeOracle);
    }

    /// @inheritdoc IVolatilityOracleAdapter
    function getHistoricalVolatility(address) external view returns (uint256) {
        revert("not implemented");
    }

    /// @inheritdoc IVolatilityOracleAdapter
    function getImpliedVolatility(address token) external view returns (uint256 impliedVolatility) {
        IUniswapV3Pool pool = getV3PoolForTokenAddress(token);
        uint256[25] memory lens = aloeVolatilityOracle.lens(pool);

        // todo: return ts
        return lens[0];
    }

    /// @inheritdoc IVolatilityOracleAdapter
    function scale() external pure returns (uint16) {
        return 18;
    }

    /// @inheritdoc IAloeVolatilityOracleAdapter
    function getV3PoolForTokenAddress(address token) public view returns (IUniswapV3Pool) {
        address pool = uniswapV3Factory.getPool(token, v3PoolTokenB, v3PoolRate);
        return IUniswapV3Pool(pool);
    }

    /// @inheritdoc IAloeVolatilityOracleAdapter
    function refreshVolatilityCache() external validateAndPayKeeper(msg.sender) returns (uint256) {
        revert();
    }

    /**
     * ////////////// TOKEN REFRESH LIST ///////////////
     */

    // inheritdoc IAloeVolatilityOracleAdapter
    function setTokenRefreshList(address[] memory list) external returns (address[] memory) {
        revert();
    }

    // inheritdoc IAloeVolatilityOracleAdapter
    function getTokenRefreshList(address[] memory list) external view returns (address[] memory) {
        revert();
    }

    function addTokenToRefreshList(address token) external returns (address) {
        revert();
    }

    /**
     * /////////////// ADMIN FUNCTIONS ///////////////
     */

    // TODO: Handle if token is invalid/no pool available?
    /// @inheritdoc IAloeVolatilityOracleAdapter
    function setUniswapV3Pool(address token, uint24 fee) external requiresAuth returns (address, uint24) {
        v3PoolTokenB = token;
        v3PoolRate = fee;
        emit UniswapV3PoolSet(token, fee);
        return (token, fee);
    }

    /// @inheritdoc IAloeVolatilityOracleAdapter
    function setAloeOracle(address oracle) external requiresAuth returns (address) {
        aloeVolatilityOracle = IVolatilityOracle(oracle);
        emit AloeOracleSet(oracle);
        return oracle;
    }

    /// @inheritdoc IAloeVolatilityOracleAdapter
    function setV3Factory(address factory) external requiresAuth returns (address) {
        uniswapV3Factory = IUniswapV3Factory(factory);
        emit UniswapV3FactorySet(factory);
        return factory;
    }
}
