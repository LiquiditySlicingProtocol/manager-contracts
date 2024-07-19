// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IRelayer
 * @notice Interface for cross-chain message and token relay operations.
 */
interface IRelayer {
    /**
     * @notice Gets the token wrapper contract address for a given chain ID.
     * @param chainId The ID of the blockchain.
     * @return address The address of the token wrapper contract.
     */
    function getTokenWrapper(uint16 chainId) external returns (address);

    /**
     * @notice Formats and stores a message on the blockchain.
     * @param targetChain The ID of the target blockchain.
     * @param targetAddress The address on the target blockchain.
     * @param payload The payload containing the function signature and arguments, encoded as 'abi.encodeWithSignature("functionName", arg);'.
     * @return sequence The sequence number of the message.
     */
    function sendMessage(
        uint32 targetChain,
        bytes32 targetAddress,
        bytes calldata payload
    ) external payable returns (uint64 sequence);

    /**
     * @notice Transfers tokens across chains and executes the payload.
     * @param targetChain The ID of the target blockchain.
     * @param targetAddress The address on the target blockchain.
     * @param targetToken The address of the target token; if zero, indicates the native token of the chain.
     * @param tokenReceiver The address to receive the tokens on the target blockchain.
     * @param payload The payload containing the function signature and arguments, encoded as 'abi.encodeWithSignature("functionName", arg);'.
     * @param amount The amount of tokens to transfer.
     * @return sequence The sequence number of the message.
     * 
     * @dev Considerations:
     * - How to pay gas fees on the target chain.
     *   Precompute gas fees and transfer an equivalent amount of ETH from the user as the gas fee for the source chain transaction.
     *   Consider how to convert to the target chain's native token to pay gas fees.
     * - Handling execution failure on the target chain.
     */
    function sendTokenWithMessage(
        uint32 targetChain,
        bytes32 targetAddress,
        bytes32 targetToken,
        bytes32 tokenReceiver,
        bytes calldata payload,
        uint256 amount
    ) external payable returns (uint64 sequence);

    /**
     * @notice Receives and verifies a cross-chain message and its signature.
     * @param message The message containing various information such as:
     *                - uint8 version;
     *                - uint32 timestamp;
     *                - uint32 nonce;
     *                - uint16 senderChainId;
     *                - bytes32 senderAddress;
     *                - uint16 targetChainId; // Check if chain ID matches.
     *                - bytes32 targetAddress; // Non-intrusive, initiates the call.
     *                - uint64 sequence;
     *                - bytes payload;
     *                - bytes[] signatures; // Signatures from validators on the sending chain.
     * @param signature The signature provided by validators on the target chain.
     * @return success Returns true if the message is successfully verified and processed, otherwise false.
     */
    function receiveMessage(
        bytes calldata message,
        bytes calldata signature
    ) external returns (bool success);

    /**
     * @notice Transfers received cross-chain tokens and executes the corresponding message.
     * @param message The message containing various information such as:
     *                - uint8 version;
     *                - uint32 timestamp;
     *                - uint32 nonce;
     *                - uint16 senderChainId;
     *                - bytes32 senderAddress;
     *                - uint16 targetChainId; // Check if chain ID matches.
     *                - bytes32 targetAddress;
     *                - bytes32 tokenAddress; // Token address; if zero, indicates native token.
     *                - bytes32 tokenRecipient; // Address to receive the tokens.
     *                - uint256 amount;
     *                - uint64 sequence;
     *                - bytes payload;
     *                - bytes[] signatures; // Signatures from validators on the sending chain.
     * @param signature The signature provided by validators on the target chain.
     * @return success Returns true if the message and token transfer are successfully verified and processed, otherwise false.
     */
    function receiveTokenAndMessage(
        bytes calldata message,
        bytes calldata signature
    ) external returns (bool success);
}
