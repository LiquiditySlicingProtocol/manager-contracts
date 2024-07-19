// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShare {
    /**
     * @notice lock amount of user's staked shares for trading.
     * @dev This function must be called by the market contract.
     * @param chainId The ID of the blockchain.
     * @param node The address of the pool.
     * @param owner The address of the user.
     * @param amount The amount of shares to lock.
     */
    function lockShareToMarket(
        uint16 chainId,
        bytes32 node,
        address owner,
        uint256 amount
    ) external;

    /**
     * @notice unlock user's locked shares for transfer.
     * @dev This function must be called by the market contract.
     * @param chainId The ID of the blockchain.
     * @param node The address of the pool.
     * @param owner The address of the user.
     * @param amount The amount of shares to unlock.
     */
    function unlockShareFromMarket(
        uint16 chainId,
        bytes32 node,
        address owner,
        uint256 amount
    ) external;

    /**
     * @notice transfer user's locked shares to another.
     * @dev This function must be called by the market contract.
     * @param chainId The ID of the blockchain.
     * @param node The address of the pool.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param amount The amount of shares to transfer.
     */
    function transferShare(
        uint16 chainId,
        bytes32 node,
        address from,
        address to,
        uint256 amount
    ) external;
}
