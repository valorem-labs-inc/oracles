// SPDX-License-Identifier: BUSL 1.1
pragma solidity 0.8.13;

import "./interfaces/IUniswapV3VolatilityOracle.sol";

import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./utils/Keep3rV2Job.sol";
import "./interfaces/IVolatilityOracle.sol";

import "./libraries/Volatility.sol";
import "./libraries/Oracle.sol";

contract UniswapV3VolatilityOracle is IUniswapV3VolatilityOracle, Keep3rV2Job {
    /**
     * /////////// CONSTANTS ////////////
     */
    uint24 private constant POINT_ZERO_ONE_PCT_FEE = 100;
    uint24 private constant POINT_THREE_PCT_FEE = 3_000;
    uint24 private constant POINT_ZERO_FIVE_PCT_FEE = 500;

    address private constant UNISWAP_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    /**
     * /////////// STATE ////////////
     */

    struct Indices {
        uint8 read;
        uint8 write;
    }

    mapping(bytes32 => UniswapV3FeeTier) private tokenPairHashToDefaultFeeTier;

    /// @inheritdoc IUniswapV3VolatilityOracle
    mapping(IUniswapV3Pool => Volatility.PoolMetadata) public cachedPoolMetadata;

    /// @inheritdoc IUniswapV3VolatilityOracle
    mapping(IUniswapV3Pool => Volatility.FeeGrowthGlobals[25]) public feeGrowthGlobals;

    /// @inheritdoc IUniswapV3VolatilityOracle
    mapping(IUniswapV3Pool => Indices) public feeGrowthGlobalsIndices;

    IUniswapV3Factory private uniswapV3Factory;

    IUniswapV3VolatilityOracle.UniswapV3PoolInfo[] private tokenFeeTierList;

    constructor(address _keep3r) {
        admin = msg.sender;
        uniswapV3Factory = IUniswapV3Factory(UNISWAP_FACTORY_ADDRESS);
        keep3r = _keep3r;
    }

    /**
     * /////////// IVolatilityOracle //////////
     */

    /// @inheritdoc IVolatilityOracle
    function getHistoricalVolatility(address) external pure returns (uint256) {
        revert("not implemented");
    }

    /// @inheritdoc IVolatilityOracle
    function getImpliedVolatility(address tokenA, address tokenB) external view returns (uint256 impliedVolatility) {
        UniswapV3FeeTier tier = getDefaultFeeTierForTokenPair(tokenA, tokenB);
        return getImpliedVolatility(tokenA, tokenB, tier);
    }

    /// @inheritdoc IVolatilityOracle
    function scale() external pure returns (uint8) {
        return 18;
    }

    /**
     * /////////// IUniswapV3VolatilityOracle //////////
     */

    /// @inheritdoc IUniswapV3VolatilityOracle
    function getImpliedVolatility(address tokenA, address tokenB, UniswapV3FeeTier tier)
        public
        view
        returns (uint256 impliedVolatility)
    {
        if (tier == UniswapV3FeeTier.RESERVED) {
            revert NoFeeTierSpecifiedForTokenPair();
        }

        uint24 fee = getUniswapV3FeeInHundredthsOfBip(tier);
        IUniswapV3Pool pool = getV3PoolForTokensAndFee(tokenA, tokenB, fee);
        uint256[25] memory loadedLens = lens(pool);
        Indices memory idxs = feeGrowthGlobalsIndices[pool];
        return loadedLens[idxs.read];
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function getV3PoolForTokensAndFee(address tokenA, address tokenB, uint24 fee)
        public
        view
        returns (IUniswapV3Pool pool)
    {
        pool = IUniswapV3Pool(uniswapV3Factory.getPool(tokenA, tokenB, fee));
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function getDefaultFeeTierForTokenPair(address tokenA, address tokenB) public view returns (UniswapV3FeeTier) {
        bytes32 tokenPairHash = keccak256(abi.encodePacked(tokenA, tokenB));
        UniswapV3FeeTier tier = tokenPairHashToDefaultFeeTier[tokenPairHash];
        return tier;
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function refreshVolatilityCache() public returns (uint256) {
        return _refreshVolatilityCache();
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function refreshVolatilityCacheAndMetadataForPool(UniswapV3PoolInfo calldata info)
        public
        requiresAdmin(msg.sender)
        returns (uint256)
    {
        _refreshPoolMetadata(info);
        (, uint256 timestamp) = _refreshTokenVolatility(info.tokenA, info.tokenB, info.feeTier);
        return timestamp;
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function setDefaultFeeTierForTokenPair(address tokenA, address tokenB, UniswapV3FeeTier tier)
        external
        requiresAdmin(msg.sender)
        returns (address, address, UniswapV3FeeTier)
    {
        if (tokenA == address(0) || tokenB == address(0)) {
            revert InvalidToken();
        }
        if (tier == UniswapV3FeeTier.RESERVED) {
            revert InvalidFeeTier();
        }

        bytes32 tokenPairHash = keccak256(abi.encodePacked(tokenA, tokenB));
        tokenPairHashToDefaultFeeTier[tokenPairHash] = tier;
        return (tokenA, tokenB, tier);
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function cacheMetadataFor(IUniswapV3Pool pool) public requiresAdmin(msg.sender) {
        _cacheMetadataFor(pool);
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function lens(IUniswapV3Pool pool) public view returns (uint256[25] memory impliedVolatility) {
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();
        Volatility.FeeGrowthGlobals[25] memory feeGrowthGlobal = feeGrowthGlobals[pool];

        for (uint8 i = 0; i < 25; i++) {
            (impliedVolatility[i],) = _estimate24H(pool, sqrtPriceX96, tick, feeGrowthGlobal[i]);
        }
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function estimate24H(IUniswapV3Pool pool) public returns (uint256 impliedVolatility) {
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();

        Volatility.FeeGrowthGlobals[25] storage feeGrowthGlobal = feeGrowthGlobals[pool];
        Indices memory idxs = _loadIndicesAndSelectRead(pool, feeGrowthGlobal);

        Volatility.FeeGrowthGlobals memory current;
        (impliedVolatility, current) = _estimate24H(pool, sqrtPriceX96, tick, feeGrowthGlobal[idxs.read]);

        // Write to storage
        if (current.timestamp - 1 hours > feeGrowthGlobal[idxs.write].timestamp) {
            idxs.write = (idxs.write + 1) % 25;
            feeGrowthGlobals[pool][idxs.write] = current;
        }
        feeGrowthGlobalsIndices[pool] = idxs;
    }

    /**
     * ////////////// KEEP3R ///////////////
     */

    function work() external validateAndPayKeeper(msg.sender) {
        _refreshVolatilityCache();
    }

    /**
     * ////////////// TOKEN REFRESH LIST ///////////////
     */

    /// @inheritdoc IUniswapV3VolatilityOracle
    function setTokenFeeTierRefreshList(UniswapV3PoolInfo[] calldata list)
        external
        requiresAdmin(msg.sender)
        returns (UniswapV3PoolInfo[] memory)
    {
        delete tokenFeeTierList;
        for (uint256 i = 0; i < list.length; i++) {
            UniswapV3PoolInfo memory info = UniswapV3PoolInfo(list[i].tokenA, list[i].tokenB, list[i].feeTier);
            // refresh pool metadata cache on first add
            _refreshPoolMetadata(info);
            tokenFeeTierList.push(info);
        }
        emit TokenRefreshListSet();
        return list;
    }

    /// @inheritdoc IUniswapV3VolatilityOracle
    function getTokenFeeTierRefreshList() public view returns (UniswapV3PoolInfo[] memory) {
        return tokenFeeTierList;
    }

    /**
     * /////////////// ADMIN FUNCTIONS ///////////////
     */

    /// @inheritdoc IUniswapV3VolatilityOracle
    function getUniswapV3FeeInHundredthsOfBip(UniswapV3FeeTier tier) public pure returns (uint24) {
        if (tier == UniswapV3FeeTier.PCT_POINT_01) {
            return 1 * 100;
        }
        if (tier == UniswapV3FeeTier.PCT_POINT_05) {
            return 5 * 100;
        }
        if (tier == UniswapV3FeeTier.PCT_POINT_3) {
            return 3 * 100 * 10;
        }
        if (tier == UniswapV3FeeTier.PCT_1) {
            return 100 * 100;
        }
        revert("unimplemented fee tier");
    }

    /**
     * ///////// INTERNAL ///////////
     */

    function _refreshPoolMetadata(UniswapV3PoolInfo memory info) internal {
        uint24 fee = getUniswapV3FeeInHundredthsOfBip(info.feeTier);
        IUniswapV3Pool pool = getV3PoolForTokensAndFee(info.tokenA, info.tokenB, fee);
        _cacheMetadataFor(pool);
    }

    function _cacheMetadataFor(IUniswapV3Pool pool) internal {
        Volatility.PoolMetadata memory poolMetadata;

        (,, uint16 observationIndex, uint16 observationCardinality,, uint8 feeProtocol,) = pool.slot0();
        poolMetadata.maxSecondsAgo = (Oracle.getMaxSecondsAgo(pool, observationIndex, observationCardinality) * 3) / 5;

        uint24 fee = pool.fee();
        poolMetadata.gamma0 = fee;
        poolMetadata.gamma1 = fee;
        if (feeProtocol % 16 != 0) {
            poolMetadata.gamma0 -= fee / (feeProtocol % 16);
        }
        if (feeProtocol >> 4 != 0) {
            poolMetadata.gamma1 -= fee / (feeProtocol >> 4);
        }

        poolMetadata.tickSpacing = pool.tickSpacing();

        cachedPoolMetadata[pool] = poolMetadata;
    }

    function _refreshVolatilityCache() internal returns (uint256) {
        for (uint256 i = 0; i < tokenFeeTierList.length; i++) {
            address tokenA = tokenFeeTierList[i].tokenA;
            address tokenB = tokenFeeTierList[i].tokenB;
            UniswapV3FeeTier feeTier = tokenFeeTierList[i].feeTier;
            _refreshTokenVolatility(tokenA, tokenB, feeTier);
        }

        emit VolatilityOracleCacheUpdated(block.timestamp);
        return block.timestamp;
    }

    function _refreshTokenVolatility(address tokenA, address tokenB, UniswapV3FeeTier feeTier)
        internal
        returns (uint256 volatility, uint256 timestamp)
    {
        uint24 fee = getUniswapV3FeeInHundredthsOfBip(feeTier);
        IUniswapV3Pool pool = getV3PoolForTokensAndFee(tokenA, tokenB, fee);

        // refresh metadata only if observation is older than xx
        // in certain cases, aloe won't have sufficient data to run estimate24h, since
        // the oldest observation for the pool oracle is under an hour. for now,
        // we're only refreshing the pool metadata cache when the token is added to the
        // refresh list, and when a manual call to refresh a token is made.
        uint256 impliedVolatility = estimate24H(pool);
        emit TokenVolatilityUpdated(tokenA, tokenB, fee, impliedVolatility, block.timestamp);
        return (impliedVolatility, block.timestamp);
    }

    function _estimate24H(
        IUniswapV3Pool _pool,
        uint160 _sqrtPriceX96,
        int24 _tick,
        Volatility.FeeGrowthGlobals memory _previous
    ) private view returns (uint256 impliedVolatility, Volatility.FeeGrowthGlobals memory current) {
        Volatility.PoolMetadata memory poolMetadata = cachedPoolMetadata[_pool];

        uint32 secondsAgo = poolMetadata.maxSecondsAgo;
        require(secondsAgo >= 1 hours, "Aloe: need more data");
        if (secondsAgo > 1 days) {
            secondsAgo = 1 days;
        }
        // Throws if secondsAgo == 0
        (int24 arithmeticMeanTick, uint160 secondsPerLiquidityX128) = Oracle.consult(_pool, secondsAgo);

        current = Volatility.FeeGrowthGlobals(
            _pool.feeGrowthGlobal0X128(), _pool.feeGrowthGlobal1X128(), uint32(block.timestamp)
        );
        impliedVolatility = Volatility.estimate24H(
            poolMetadata,
            Volatility.PoolData(
                _sqrtPriceX96, _tick, arithmeticMeanTick, secondsPerLiquidityX128, secondsAgo, _pool.liquidity()
            ),
            _previous,
            current
        );
    }

    function _loadIndicesAndSelectRead(IUniswapV3Pool _pool, Volatility.FeeGrowthGlobals[25] storage _feeGrowthGlobal)
        private
        view
        returns (Indices memory)
    {
        Indices memory idxs = feeGrowthGlobalsIndices[_pool];
        uint32 timingError = _timingError(block.timestamp - _feeGrowthGlobal[idxs.read].timestamp);

        for (uint8 counter = idxs.read + 1; counter < idxs.read + 25; counter++) {
            uint8 newReadIndex = counter % 25;
            uint32 newTimingError = _timingError(block.timestamp - _feeGrowthGlobal[newReadIndex].timestamp);

            if (newTimingError < timingError) {
                idxs.read = newReadIndex;
                timingError = newTimingError;
            } else {
                break;
            }
        }

        return idxs;
    }

    function _timingError(uint256 _age) private pure returns (uint32) {
        return uint32(_age < 24 hours ? 24 hours - _age : _age - 24 hours);
    }
}
