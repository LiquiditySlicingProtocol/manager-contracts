// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPoolV2 {
    // Represent the pool data imported from the target chain
    struct ImportPool {
        uint8 _type;
        uint64 exitPeriod;
        bytes32 _address; // Address of the pool
        address recipient;
        uint256 amount;
        bytes32 nativeToken;
        bool autoDeposit;
        bool asDelegator;
        bool update; // Whether to update the current imported data
    }

    struct PoolInfo {
        // Identifier for the type of the pool
        uint8 _type;
        // Pool state:
        // 0 0 0 0 |     0       |     0     |     0      |   0
        //  Unused  | Allow orders | Node/User | Auto-reinvest | Active
        uint8 _state;
        // Waiting period for withdrawing from the pool
        uint64 exitPeriod;
        // Address of the host contract in target chain
        bytes32 host;
        // Address of the native token used in the pool
        bytes32 nativeToken;
        // Total amount of tokens deposited in the pool
        uint256 totalDeposit;
        // Address of the pool extension contract
        address ext;
    }

    /**
     * @dev Pool initialization event
     * @param chainId Chain ID
     * @param pool Pool identifier
     * @param exitPeriod Exit period
     * @param autoDeposit Auto deposit flag
     * @param poolType Pool type
     */
    event PoolInitalize(
        uint16 chainId,
        bytes32 pool,
        uint64 exitPeriod,
        bool autoDeposit,
        uint8 poolType
    );

    /**
     * @dev Pool reward event
     * @param chainId Chain ID
     * @param pool Pool identifier
     * @param amount Reward amount
     */
    event PoolReward(uint16 chainId, bytes32 pool, uint256 amount);

    /**
     * @dev Error indicating that the pool is already initialized
     * @param chainId Chain ID
     * @param pool Pool identifier
     */
    error PoolInitialized(uint16 chainId, bytes32 pool);

    function getPool(
        uint16 chainId,
        bytes32 addr
    ) external view returns (PoolInfo memory);

    function checkPoolState(
        uint16 chainId,
        bytes32 addr,
        uint8 state
    ) external view returns (bool);
}
