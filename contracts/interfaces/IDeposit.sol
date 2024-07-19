// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDeposit {
    struct StakingData {
        uint256 freezed;
        uint256 locked;
        uint256 actived;
        uint256 dividendCorrection;
        uint256 unlockedCorrection;
    }

    struct DepositPool {
        uint256 total;
        uint256 unlocked;
        uint256 totalDividend;
        mapping(address => StakingData) userStakings;
    }

    /**
     * @dev Event emitted when tokens are deposited.
     * @param chainId Chain ID
     * @param pool Pool identifier
     * @param user Address of the user
     * @param amount Amount of tokens deposited
     */
    event TokenDeposit(
        uint16 chainId,
        bytes32 pool,
        address user,
        uint256 amount
    );

    /**
     * @dev Event emitted when a token release schedule is created.
     * @param chainId Chain ID
     * @param pool Pool identifier
     * @param user Address of the user
     * @param amount Amount of tokens scheduled for release
     */
    event TokenReleaseSchedule(
        uint16 chainId,
        bytes32 pool,
        address user,
        uint256 amount
    );

    /**
     * @dev Event emitted when tokens are released.
     * @param chainId Chain ID
     * @param pool Pool identifier
     * @param user Address of the user
     * @param amount Amount of tokens released
     */
    event TokenRelease(
        uint16 chainId,
        bytes32 pool,
        address user,
        uint256 amount
    );

    /**
     * @dev Event emitted when reward are retrieved.
     * @param chainId Chain ID
     * @param pool Pool identifier
     * @param user Address of the user
     * @param amount Amount of reward retrieved
     */
    event GetReward(
        uint16 chainId,
        bytes32 pool,
        address user,
        uint256 amount
    );

    /**
     * @notice deposit tokens to a specific pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param amount The amount of tokens to deposit.
     */
    function depositTokenToPool(
        uint16 chainId,
        bytes32 pool,
        uint256 amount
    ) external;

    /**
     * @notice release tokens from a specific pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param amount The amount of tokens to release.
     */
    function releaseTokenFromPool(
        uint16 chainId,
        bytes32 pool,
        uint256 amount
    ) external;

    /**
     * @notice withdraw reward from a specific pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     */
    function withdrawReward(uint16 chainId, bytes32 pool) external;

    /**
     * @notice Public view function to get the deposit pool data for a specific chain and pool address.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @return The deposit pool data.
     */
    function getPoolDeposit(uint16 chainId, bytes32 pool) external view returns (uint256, uint256, uint256);

    /**
     * @notice Public view function to get the staking data for a specific user in a specific pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param owner The address of the user.
     * @return The staking data for the user.
     */
    function getUserStaking(uint16 chainId, bytes32 pool, address owner) external view returns (StakingData memory);
}
