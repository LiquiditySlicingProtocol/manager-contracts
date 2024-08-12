// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMarket} from "./interfaces/IMarket.sol";

abstract contract MarketV2Base is IMarket {
    /// @custom:storage-location erc7201:lsp.market.storage.Market
    struct MarketStorage {
        address manager;
        address payment;
        uint256 listFee;
        uint256 buyFee;
        bool paused;
        List[] lists;
        mapping(address => uint256[]) userList;
    }

    // keccak256(abi.encode(uint256(keccak256("lsp.market.storage.Market")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant MARKET_STORAGE_SLOT =
        0xd8beb7d9075fcaa9c5d50bc7a7fe89b74434fbbc12c48dc2e1e590c959c62a00;

    /// @notice Mask for decimals extraction
    uint8 internal constant _decimalsMask = 0xff;

    modifier whenNotPaused() {
        require(paused(), "!Paused");
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        MarketStorage storage $ = _getMarketStorage();
        return $.paused;
    }

    function _getMarketStorage()
        internal
        pure
        returns (MarketStorage storage $)
    {
        assembly ("memory-safe") {
            $.slot := MARKET_STORAGE_SLOT
        }
    }

    function _getFee(
        uint256 base
    ) internal pure returns (uint256 fee, uint8 decimals) {
        decimals = uint8(base & uint256(_decimalsMask));
        fee = base >> 8;
    }

    function _computeFee(
        uint256 base,
        uint256 value
    ) internal pure returns (uint256) {
        (uint256 fee, uint8 decimals) = _getFee(base);
        if (decimals > 0) {
            return (value * fee) / (10 ** decimals);
        } else {
            return fee;
        }
    }

    /**
     * @dev Verifies the validity of a fee value.
     * @dev Valid decimals is 0-30 range
     * @param value The combined value containing the fee and the number of decimal places.
     */
    function _verifyFee(uint256 value) internal pure {
        // Extract the number of decimal places from the value
        uint8 decimals = uint8(value & uint256(_decimalsMask));

        // Check if the number of decimal places is within the allowed range (0-30)
        require(decimals <= 30, "!Large");

        // If the number of decimal places is greater than 0, further verify the fee value
        if (decimals > 0) {
            // Extract the actual fee value
            uint256 fee = value >> 8;

            // Check if the fee is within the allowed range
            require(fee <= 10 ** (decimals + 2), "!Large");
        }
    }

    function _getList(uint256 id) internal view returns (List storage) {
        MarketStorage storage $ = _getMarketStorage();
        return $.lists[id];
    }

    function _addList(List memory list) internal {
        MarketStorage storage $ = _getMarketStorage();

        // basic list info
        list.listFee = $.listFee;
        list.buyFee = $.buyFee;
        list.seller = msg.sender;
        list.status = uint8(ListStatus.OnSale);

        $.lists.push(list);
        uint256 id = $.lists.length;
        $.userList[msg.sender].push(id);

        emit NewList(msg.sender, list.pool, id);
    }

    function _importList(List memory list) internal {
        MarketStorage storage $ = _getMarketStorage();

        require(list.status == uint8(ListStatus.OnSale), "!OffSale");
        require(list.seller != address(0), "!Invalid");

        $.lists.push(list);
        uint256 id = $.lists.length;
        $.userList[list.seller].push(id);
    }

    function _setManager(address newManager) internal {
        require(newManager != address(0));
        MarketStorage storage $ = _getMarketStorage();
        $.manager = newManager;
    }

    function _setPayment(address token) internal {
        require(token != address(0));
        MarketStorage storage $ = _getMarketStorage();
        $.payment = token;
    }

    function _setListFee(uint256 value) internal {
        MarketStorage storage $ = _getMarketStorage();
        _verifyFee(value);
        $.listFee = value;
    }

    function _setBuyFee(uint256 value) internal {
        MarketStorage storage $ = _getMarketStorage();
        _verifyFee(value);
        $.buyFee = value;
    }

    function _setPause(bool status) internal {
        MarketStorage storage $ = _getMarketStorage();
        $.paused = status;
    }

    function getManager() public view returns (address) {
        MarketStorage storage $ = _getMarketStorage();
        return $.manager;
    }

    function getPayment() public view returns (address) {
        MarketStorage storage $ = _getMarketStorage();
        return $.payment;
    }

    function getList(uint256 id) public view returns (List memory) {
        return _getList(id);
    }

    function getUserList(
        address maker,
        uint256 index
    ) public view returns (List memory) {
        MarketStorage storage $ = _getMarketStorage();
        uint256 id = $.userList[maker][index];
        return $.lists[id];
    }

    function listFee() public view returns (uint256 fee, uint8 decimals) {
        MarketStorage storage $ = _getMarketStorage();
        return _getFee($.listFee);
    }

    function buyFee() public view returns (uint256 fee, uint8 decimals) {
        MarketStorage storage $ = _getMarketStorage();
        return _getFee($.buyFee);
    }
}
