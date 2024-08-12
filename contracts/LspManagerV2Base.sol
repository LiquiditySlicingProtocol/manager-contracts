// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract LspManagerV2Base {
    /// @custom:storage-location erc7201:lsp.storage.Manager
    struct ManagerStorage {
        address _relayer;
        address _market;
        bool _paused;
        mapping(uint16 => uint256) _withdrawFee;
    }

    /// @notice Mask for decimals extraction
    uint8 internal constant _decimalsMask = 0xff;

    // keccak256(abi.encode(uint256(keccak256("lsp.storage.Manager")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant MANAGER_STORAGE_SLOT =
        0x6e5988dd1a2ada360f78da280a0bca20acc5d5c7f19ba9338d5c8c36f50bc200;

    /**
     * @dev Event emitted when tokens are increased.
     * @param chainId Chain ID
     * @param recipient Address of the recipient
     * @param amount Amount of tokens increased
     */
    event TokenIncrease(
        uint16 indexed chainId,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @dev Event emitted when a withdrawal is made.
     * @param chainId Chain ID
     * @param owner Address of the user
     * @param target Target identifier
     * @param fee Fee amount
     * @param amount Amount withdrawn
     */
    event Withdrawal(
        uint16 indexed chainId,
        address indexed owner,
        bytes32 target,
        uint256 fee,
        uint256 amount
    );

    error NonDelegatedPool(uint16 chainId, bytes32 pool);
    error NonCollator(uint16 chainId, bytes32 pool);

    modifier isRelayer() {
        require(msg.sender == getRelayer(), "!Non-relayer");
        _;
    }

    modifier isMarket() {
        require(msg.sender == getMarket(), "!Non-market");
        _;
    }

    modifier whenNotPaused() {
        require(paused(), "!Paused");
        _;
    }

    /**
     * @notice Increases the token balance of a user.
     * @param chainId The ID of the blockchain.
     * @param owner The address of the user.
     * @param amount The amount of tokens to increase.
     */
    function increaseToken(
        uint16 chainId,
        address owner,
        uint256 amount
    ) external virtual;

    /**
     * @notice Withdraws tokens from a pool.
     * @param chainId The ID of the blockchain.
     * @param host The host address of the pool.
     * @param target The target address for withdrawal.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(
        uint16 chainId,
        bytes32 host, // TODO remove host parameters
        bytes32 target,
        uint256 amount
    ) external virtual;

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        ManagerStorage storage $ = _getManagerStorage();
        return $._paused;
    }

    function _getManagerStorage()
        internal
        pure
        returns (ManagerStorage storage $)
    {
        assembly ("memory-safe") {
            $.slot := MANAGER_STORAGE_SLOT
        }
    }

    /**
     * @notice Computes the withdraw fee based on the stored fee and decimals.
     * @dev Internal function.
     * @param chainId The ID of the blockchain.
     * @param value The amount to compute the fee on.
     * @return The computed withdraw fee.
     */
    function _computeWithdrawFee(
        uint16 chainId,
        uint256 value
    ) internal view returns (uint256) {
        (uint256 fee, uint8 decimals) = withdrawFee(chainId);
        if (decimals > 0) {
            return (value * fee) / (10 ** decimals);
        } else {
            return fee;
        }
    }

    function _setRelayer(address relayer) internal {
        ManagerStorage storage $ = _getManagerStorage();
        $._relayer = relayer;
    }

    function _setMarket(address market) internal {
        ManagerStorage storage $ = _getManagerStorage();
        $._market = market;
    }

    function _setPause(bool status) internal {
        ManagerStorage storage $ = _getManagerStorage();
        $._paused = status;
    }

    function _setWithdrawFee(uint16 chainId, uint256 value) internal {
        uint8 decimals = uint8(value & uint256(_decimalsMask));
        require(decimals <= 30, "!Large");
        if (decimals > 0) {
            uint256 fee = value >> 8;
            require(fee <= 10 ** (decimals + 2), "!Large");
        }
        ManagerStorage storage $ = _getManagerStorage();
        $._withdrawFee[chainId] = value;
    }

    function toBytes32Addr(address addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    function fromBytes32Addr(bytes32 bytesAddr) public pure returns (address) {
        if (uint256(bytesAddr) >> 160 != 0) revert("Invalid");
        return address(uint160(uint256(bytesAddr)));
    }

    function getRelayer() public view returns (address) {
        ManagerStorage storage $ = _getManagerStorage();
        return $._relayer;
    }

    function getMarket() public view returns (address) {
        ManagerStorage storage $ = _getManagerStorage();
        return $._market;
    }

    function withdrawFee(
        uint16 chainId
    ) public view returns (uint256 fee, uint8 decimals) {
        ManagerStorage storage $ = _getManagerStorage();
        uint256 value = $._withdrawFee[chainId];
        decimals = uint8(value & uint256(_decimalsMask));
        fee = value >> 8;
    }
}
