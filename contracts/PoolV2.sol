// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPoolV2.sol";
import "./DepositV2.sol";

abstract contract PoolV2 is IPoolV2, DepositV2 {
    /// @custom:storage-location erc7201:lsp.storage.PoolStorage
    struct PoolStorage {
        // Mapping of chainId to pool information
        mapping(uint16 => mapping(bytes32 => PoolInfo)) registeredPools;
    }

    uint8 public constant POOL_ENABLED = 0x1;
    uint8 public constant AUTO_DEPOSIT = 0x2;
    uint8 public constant AS_DELEGATOR = 0x4;
    uint8 public constant ALLOW_LISTING = 0x8;

    // keccak256(abi.encode(uint256(keccak256(bytes("lsp.storage.PoolStorage"))) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant POOL_STATE_SLOT =
        0xdaab0aab04bf1773043858a031a8ecd96725dda7a65c14714556980d6a034800;

    modifier checkPool(
        uint16 chainId,
        bytes32 pool,
        uint8 state
    ) {
        require(checkPoolState(chainId, pool, state), "!State");
        _;
    }

    function getPoolStorage() internal pure returns (PoolStorage storage $) {
        assembly ("memory-safe") {
            $.slot := POOL_STATE_SLOT
        }
    }

    function _checkState(uint8 v, uint8 f) internal pure returns (bool) {
        return v & f == f;
    }

    // Internal function to initialize a pool
    function _addPool(
        uint16 chainId,
        bytes32 host,
        ImportPool memory pool
    ) internal returns (PoolInfo storage p) {
        p = getPoolStorage().registeredPools[chainId][pool._address];
        p.host = host;

        if (_checkState(p._state, POOL_ENABLED) && !pool.update) {
            return p;
        }

        // Stake to the pool
        DepositPool storage $p = getDepositStorage().poolDeposits[chainId][
            pool._address
        ];
        _deposit(
            $p,
            pool.recipient,
            pool.amount,
            _checkState(p._state, AUTO_DEPOSIT),
            false
        );
        _lock($p, pool.recipient, pool.amount);
        p.totalDeposit += pool.amount;

        p.nativeToken = pool.nativeToken;
        p.exitPeriod = pool.exitPeriod;

        p._type = pool._type;
        p._state |= POOL_ENABLED;
        if (pool.autoDeposit) {
            p._state |= AUTO_DEPOSIT;
        }
        if (pool.asDelegator) {
            p._state |= AS_DELEGATOR;
        } else {
            p._state |= ALLOW_LISTING;
        }

        emit PoolInitalize(
            chainId,
            pool._address,
            pool.exitPeriod,
            pool.autoDeposit,
            p._type
        );
    }

    function _setPoolState(PoolInfo storage p, uint8 state) internal {
        p._state ^= state;
    }

    function _setPoolExitPeriod(PoolInfo storage p, uint64 value) internal {
        p.exitPeriod = value;
    }

    function _registerPoolExt(PoolInfo storage p, address ext) internal {
        p.ext = ext;
    }

    function _getPool(
        uint16 chainId,
        bytes32 pool
    ) internal view returns (PoolInfo storage) {
        PoolStorage storage $ = getPoolStorage();
        return $.registeredPools[chainId][pool];
    }

    function getPool(
        uint16 chainId,
        bytes32 pool
    ) public view returns (PoolInfo memory) {
        PoolStorage storage $ = getPoolStorage();
        return $.registeredPools[chainId][pool];
    }

    function checkPoolState(
        uint16 chainId,
        bytes32 pool,
        uint8 state
    ) public view returns (bool) {
        return _checkState(getPool(chainId, pool)._state, state);
    }
}
