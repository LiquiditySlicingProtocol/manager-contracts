// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IDeposit.sol";
import "./utils/FullMath.sol";

/// @title DepositV2
/// @notice This abstract contract provides the basic functionality for managing deposits and user staking data across multiple chains and pools.
abstract contract DepositV2 is IDeposit {
    /// @custom:storage-location erc7201:lsp.storage.DepositStorage
    struct DepositStorage {
        // chainID => (pool => DepositPool)
        mapping(uint16 => mapping(bytes32 => DepositPool)) poolDeposits;
    }

    // for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
    uint256 internal constant magnitude = 0x100000000000000000000000000000000;

    // keccak256(abi.encode(uint256(keccak256(bytes("lsp.storage.DepositStorage"))) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DEPOSIT_STORAGE_SLOT =
        0x8d494d8bd56e466f414578baf4271b27051ec449142aa48cd12c575c949ec300;

    function getDepositStorage()
        internal
        pure
        returns (DepositStorage storage $)
    {
        assembly ("memory-safe") {
            $.slot := DEPOSIT_STORAGE_SLOT
        }
    }

    /**
     * @dev Transfers shares from one user to another within a pool.
     * @param $p Pool data storage
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param amount Amount of shares to transfer
     * @param restake Whether to restake the shares
     */
    function _transfer(
        DepositPool storage $p,
        address from,
        address to,
        uint256 amount,
        bool restake
    ) internal {
        _unlock($p, from, amount);
        // Calculate current earnings for the user and move to available balance
        _release($p, from, amount, restake, true);
        _deposit($p, to, amount, restake, true);
    }

    /**
     * @dev Deposits shares for a user within a pool.
     * @param $p Pool data storage
     * @param owner Address of the user
     * @param amount Amount of shares to deposit
     * @param restake Whether to restake the shares
     * @param isTransfer Whether the deposit is a result of a transfer
     */
    function _deposit(
        DepositPool storage $p,
        address owner,
        uint256 amount,
        bool restake,
        bool isTransfer
    ) internal {
        StakingData storage $u = $p.userStakings[owner];
        _addDividend($p, owner, restake, isTransfer);
        $u.freezed += amount;
        if (!isTransfer) {
            $p.total += amount;
        }
    }

    /**
     * @dev Releases shares for a user within a pool.
     * @param $p Pool data storage
     * @param owner Address of the user
     * @param amount Amount of shares to release
     * @param restake Whether to restake the shares
     * @param isTransfer Whether the release is a result of a transfer
     */
    function _release(
        DepositPool storage $p,
        address owner,
        uint256 amount,
        bool restake,
        bool isTransfer
    ) internal {
        StakingData storage $u = $p.userStakings[owner];
        _addDividend($p, owner, restake, isTransfer);
        // The actual staked amount equals $u.freezed - $u.locked
        require($u.freezed - $u.locked >= amount, "!Insufficient");
        $u.freezed -= amount;
        if (!isTransfer) {
            $p.total -= amount;
        }
    }

    /**
     * @dev Locks shares for a user within a pool for trading purposes.
     * @param $p Pool data storage
     * @param owner Address of the user
     * @param amount Amount of shares to lock
     */
    function _lock(
        DepositPool storage $p,
        address owner,
        uint256 amount
    ) internal {
        StakingData storage $u = $p.userStakings[owner];
        _cancel($p, owner);
        if ($u.locked < amount) {
            require($u.locked + amount <= $u.freezed, "!Insufficient");
            $u.locked += amount;
        }
    }

    /**
     * @dev Unlocks shares for a user within a pool.
     * @param $p Pool data storage
     * @param owner Address of the user
     * @param amount Amount of shares to unlock
     */
    function _unlock(
        DepositPool storage $p,
        address owner,
        uint256 amount
    ) internal {
        StakingData storage $u = $p.userStakings[owner];
        _cancel($p, owner);
        require($u.locked >= amount, "!Insufficient");
        $u.locked -= amount;
    }

    /**
     * @dev Withdraws available balance for a user within a pool.
     * @param $p Pool data storage
     * @param owner Address of the user
     * @return amount Amount of available balance withdrawn
     */
    function _withdraw(
        DepositPool storage $p,
        address owner
    ) internal returns (uint256 amount) {
        StakingData storage $u = $p.userStakings[owner];
        amount = $u.actived;
        $u.actived = 0;
    }

    /**
     * @dev Cancels and adjusts user's locked shares based on pool's unlocked shares.
     * @param $p Pool data storage
     * @param owner Address of the user
     */
    function _cancel(DepositPool storage $p, address owner) internal {
        StakingData storage $u = $p.userStakings[owner];
        uint256 unlocked = FullMath.mulDiv(
            $u.locked,
            $p.unlocked - $u.unlockedCorrection,
            magnitude
        );
        require($u.locked >= unlocked);
        $u.locked -= unlocked;
        $u.unlockedCorrection = $p.unlocked;
        // Transfer to user's available balance
        $u.actived += unlocked;
    }

    /**
     * @dev Adds dividends to a user's balance within a pool.
     * @param $p Pool data storage
     * @param owner Address of the user
     * @param restake Whether to restake the dividends
     * @param isTransfer Whether the addition is a result of a transfer
     */
    function _addDividend(
        DepositPool storage $p,
        address owner,
        bool restake,
        bool isTransfer
    ) internal {
        StakingData storage $u = $p.userStakings[owner];
        // Calculate current earnings
        uint256 amount = FullMath.mulDiv(
            $u.freezed,
            $p.totalDividend - $u.dividendCorrection,
            magnitude
        );
        $u.dividendCorrection = $p.totalDividend;
        if (restake) {
            $u.freezed += amount;
            if (!isTransfer) {
                $p.total += amount;
            }
        } else {
            $u.actived += amount;
        }
    }

    /**
     * @dev Refunds shares for a user within a pool.
     * @param $p Pool data storage
     * @param amount Amount of shares to refund
     */
    function _refund(
        DepositPool storage $p,
        uint256 amount
    ) internal {
        // Calculate the amount of shares to release based on the current pool shares
        uint256 unlocked = FullMath.mulDiv(amount, magnitude, $p.total);
        $p.unlocked += unlocked; // User's released tokens = current unlocked amount * (user's current stake / total stake)
    }

    /**
     * @dev Updates the total dividend for a pool.
     * @param $p Pool data storage
     * @param amount Amount of dividend to add
     */
    function _updateDividend(DepositPool storage $p, uint256 amount) internal {
        uint256 dividend = FullMath.mulDiv(amount, magnitude, $p.total);
        $p.totalDividend += dividend;
    }

    /**
     * @notice get the deposit pool data for a specific chain and pool address.
     * @dev Internal function
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @return The deposit pool data.
     */
    function _getPoolDeposit(uint16 chainId, bytes32 pool) internal view returns (DepositPool storage) {
        DepositStorage storage $ = getDepositStorage();
        return $.poolDeposits[chainId][pool];
    }

    /**
     * @notice get the deposit pool data for a specific chain and pool address.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @return The deposit pool data.
     */
    function getPoolDeposit(uint16 chainId, bytes32 pool) public view returns (uint256, uint256, uint256) {
        DepositStorage storage $ = getDepositStorage();
        DepositPool storage p = $.poolDeposits[chainId][pool];
        return (p.total, p.totalDividend, p.unlocked);
    }

    /**
     * @notice get the staking data for a specific user in a specific pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param owner The address of the user.
     * @return The staking data for the user.
     */
    function getUserStaking(uint16 chainId, bytes32 pool, address owner) public view returns (StakingData memory) {
        DepositStorage storage $ = getDepositStorage();
        DepositPool storage p = $.poolDeposits[chainId][pool];

        return p.userStakings[owner];
    }
}
