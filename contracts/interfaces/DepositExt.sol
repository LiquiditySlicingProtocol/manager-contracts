// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DepositExt
 * @notice Interface for external deposit and release operations.
 */
interface DepositExt {
    /**
     * @notice Checks if staking is allowed.
     * @param node The identifier of the node.
     * @param owner The address of the user.
     * @param amount The amount of tokens to stake.
     * @return bool Returns true if staking is allowed, otherwise false.
     */
    function canDeposit(
        bytes32 node,
        address owner,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Completes the staking process.
     * @param node The identifier of the node.
     * @param owner The address of the user.
     * @param amount The amount of tokens staked.
     */
    function completeDeposit(
        bytes32 node,
        address owner,
        uint256 amount
    ) external;

    /**
     * @notice Checks if unstaking is allowed.
     * @param node The identifier of the node.
     * @param owner The address of the user.
     * @param amount The amount of tokens to unstake.
     * @return bool Returns true if unstaking is allowed, otherwise false.
     */
    function canRelease(
        bytes32 node,
        address owner,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Completes the unstaking process.
     * @param node The identifier of the node.
     * @param owner The address of the user.
     * @param amount The amount of tokens unstaked.
     */
    function completeRelease(
        bytes32 node,
        address owner,
        uint256 amount
    ) external;
}
