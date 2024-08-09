// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMarket {
    enum ListStatus {
        Canceled,
        Paused,
        OnSale,
        Processing,
        Finished
    }

    struct List {
        uint8 status; // State of the listing
        uint16 chainId; // ID of the blockchain
        bytes32 pool; // Pool address
        uint256 amount; // Amount of the asset
        uint256 unitPrice; // Unit price of the asset
        uint256 minUnit; // Minimum unit to buy
        uint256 listFee; // Listing fee
        uint256 buyFee; // Buying fee
        address seller; // Address of the seller
    }

    struct ListRequest {
        uint16 chainId; // ID of the blockchain
        bytes32 pool; // Pool address
        uint256 amount; // Amount of the asset
        uint256 unitPrice; // Unit price of the asset
        uint256 minUnit; // Minimum unit to buy
    }

    // Event emitted when a new listing is created
    event NewList(address indexed maker, bytes32 indexed pool, uint256 id);

    // Event emitted when a listing is canceled
    event CancelList(uint256 indexed id);

    // Event emitted when an order is made
    event MakeOrder(
        address indexed buyer,
        uint256 indexed id,
        uint256 amount
    );

    /**
     * @notice Adds a new listing.
     * @param data The listing request data.
     */
    function addList(ListRequest calldata data) external;

    /**
     * @notice Cancels a listing.
     * @param id The index of the listing to cancel.
     */
    function cancelList(uint256 id) external;

    /**
     * @notice Makes an order for a listing.
     * @param id The index of the listing.
     * @param amount The amount to buy.
     */
    function makeOrder(
        uint256 id,
        uint256 amount
    ) external;
}
