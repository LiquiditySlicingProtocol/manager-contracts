// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {DepositExt} from "./interfaces/DepositExt.sol";
import {IShare} from "./interfaces/IShare.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IRelayer} from "./interfaces/IRelayer.sol";
import {PoolV2} from "./PoolV2.sol";
import {LspManagerV2Base} from "./LspManagerV2Base.sol";
import {SafeERC20} from "./utils/SafeERC20.sol";
import {SafeMath} from "./utils/SafeMath.sol";

/**
 * @title LspManagerV2
 * @notice Manages deposits, withdrawals, and staking operations across multiple chains and pools.
 */
contract LspManagerV2 is
    AccessManagedUpgradeable,
    LspManagerV2Base,
    PoolV2,
    IShare
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /**
     * @notice Sets the relayer address.
     * @dev Restricted to certain roles.
     * @param relayer The address of the new relayer.
     */
    function setRelayer(address relayer) external restricted {
        require(relayer != address(0));
        _setRelayer(relayer);
    }

    /**
     * @notice Sets the market address.
     * @dev Restricted to certain roles.
     * @param market The address of the new market.
     */
    function setMarket(address market) external restricted {
        require(market != address(0));
        _setMarket(market);
    }

    /**
     * @notice Sets the withdraw fee for a specific chainId.
     * @dev Restricted to certain roles.
     * @param chainId The ID of the blockchain.
     * @param value The withdraw fee value.
     */
    function setWithdrawFee(uint16 chainId, uint256 value) external restricted {
        _setWithdrawFee(chainId, value);
    }

    /**
     * @notice Adds pools from host chain.
     * @dev Can only be called by the relayer.
     * @param chainId The ID of the blockchain.
     * @param host The host address.
     * @param pools An array of pools to be added.
     */
    function addPools(
        uint16 chainId,
        bytes32 host,
        ImportPool[] calldata pools
    ) external isRelayer {
        for (uint256 i = 0; i < pools.length; i++) {
            _addPool(chainId, host, pools[i]);
        }
    }

    /**
     * @notice Sets the state of a pool.
     * @dev Restricted to certain roles.
     * @param chainId The ID of the blockchain.
     * @param addr The address of the pool.
     * @param state The new state of the pool.
     */
    function setPoolState(
        uint16 chainId,
        bytes32 addr,
        uint8 state
    ) external restricted {
        PoolInfo storage p = _getPool(chainId, addr);
        _setPoolState(p, state);
    }

    /**
     * @notice Sets the exit period for a pool.
     * @dev Restricted to certain roles.
     * @param chainId The ID of the blockchain.
     * @param addr The address of the pool.
     * @param value The new exit period value.
     */
    function setPoolExitPeriod(
        uint16 chainId,
        bytes32 addr,
        uint64 value
    ) external restricted {
        PoolInfo storage p = _getPool(chainId, addr);
        _setPoolExitPeriod(p, value);
    }

    /**
     * @notice Registers an external address for a pool.
     * @dev Restricted to certain roles.
     * @param chainId The ID of the blockchain.
     * @param addr The address of the pool.
     * @param ext The external address to register.
     */
    function registerPoolExt(
        uint16 chainId,
        bytes32 addr,
        address ext
    ) external restricted {
        PoolInfo storage p = _getPool(chainId, addr);
        _registerPoolExt(p, ext);
    }

    /// @inheritdoc LspManagerV2Base
    function increaseToken(
        uint16 chainId,
        address owner,
        uint256 amount
    ) external override isRelayer {
        address tokenWrapper = IRelayer(getRelayer()).getTokenWrapper(chainId);
        IERC20(tokenWrapper).safeTransfer(owner, amount);

        emit TokenIncrease(chainId, owner, amount);
    }

    /// @inheritdoc LspManagerV2Base
    function withdraw(
        uint16 chainId,
        bytes32 host,
        bytes32 target,
        uint256 amount
    ) external override {
        PoolInfo storage p = _getPool(chainId, host);

        address relayer = getRelayer();
        address tokenWrapper = IRelayer(relayer).getTokenWrapper(chainId);
        IERC20(tokenWrapper).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenWrapper).approve(relayer, amount);

        uint256 fee = _computeWithdrawFee(chainId, amount);
        bytes memory payload = abi.encodeWithSignature(
            "withdraw(bytes32,uint256)",
            target,
            amount - fee
        );
        IRelayer(relayer).sendTokenWithMessage(
            chainId,
            p.host,
            p.nativeToken,
            0x0,
            payload,
            amount
        );

        emit Withdrawal(chainId, msg.sender, target, fee, amount);
    }

    function depositTokenToPool(
        uint16 chainId,
        bytes32 pool,
        uint256 amount
    ) external {
        PoolInfo storage p = _getPool(chainId, pool);
        if (!_checkState(p._state, AS_DELEGATOR))
            revert NonDelegatedPool(chainId, pool);

        if (p.ext != address(0)) {
            DepositExt(p.ext).canDeposit(pool, msg.sender, amount);
        }

        address relayer = getRelayer();
        address tokenWrapper = IRelayer(relayer).getTokenWrapper(chainId);
        IERC20(tokenWrapper).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        IERC20(tokenWrapper).safeIncreaseAllowance(relayer, amount);

        bytes memory payload = abi.encodeWithSignature(
            "deposit(bytes32,bytes32,uint256)",
            pool,
            toBytes32Addr(msg.sender),
            amount
        );
        IRelayer(relayer).sendTokenWithMessage(
            chainId,
            p.host,
            p.nativeToken,
            0x0,
            payload,
            amount
        );
    }

    /**
     * @notice Completes the token deposit operation.
     * @dev This function must be called by the relayer contract.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param owner The address of the user.
     * @param amount The amount of tokens to deposit.
     */
    function completeTokenDeposit(
        uint16 chainId,
        bytes32 pool,
        address owner,
        uint256 amount
    ) external isRelayer {
        PoolInfo storage p = _getPool(chainId, pool);
        if (!_checkState(p._state, AS_DELEGATOR))
            revert NonDelegatedPool(chainId, pool);

        if (p.ext != address(0)) {
            DepositExt(p.ext).completeDeposit(pool, owner, amount);
        }

        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _deposit($p, owner, amount, _checkState(p._state, AUTO_DEPOSIT), false);

        emit TokenDeposit(chainId, pool, owner, amount);
    }

    function releaseTokenFromPool(
        uint16 chainId,
        bytes32 pool,
        uint256 amount
    ) external {
        PoolInfo storage p = _getPool(chainId, pool);
        if (!_checkState(p._state, AS_DELEGATOR))
            revert NonDelegatedPool(chainId, pool);

        if (p.ext != address(0)) {
            DepositExt(p.ext).canRelease(pool, msg.sender, amount);
        }

        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _release(
            $p,
            msg.sender,
            amount,
            _checkState(p._state, AUTO_DEPOSIT),
            false
        );

        bytes memory payload = abi.encodeWithSignature(
            "release(bytes32,bytes32,uint256)",
            pool,
            toBytes32Addr(msg.sender),
            amount
        );
        IRelayer(getRelayer()).sendMessage(chainId, p.host, payload);

        emit TokenReleaseSchedule(chainId, pool, msg.sender, amount);
    }

    /**
     * @notice Completes the token release operation.
     * @dev This function must be called by the relayer contract.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param owner The address of the user.
     * @param amount The amount of tokens to release.
     */
    function completeTokenRelease(
        uint16 chainId,
        bytes32 pool,
        address owner,
        uint256 amount
    ) external isRelayer {
        PoolInfo storage p = _getPool(chainId, pool);
        if (!_checkState(p._state, AS_DELEGATOR))
            revert NonDelegatedPool(chainId, pool);

        if (p.ext != address(0)) {
            DepositExt(p.ext).completeRelease(pool, owner, amount);
        }

        // 产生代币
        address tokenWrapper = IRelayer(getRelayer()).getTokenWrapper(chainId);
        IERC20(tokenWrapper).transfer(owner, amount);

        emit TokenRelease(chainId, pool, owner, amount);
    }

    /**
     * @notice Withdraws rewards from a pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     */
    function withdrawReward(uint16 chainId, bytes32 pool) external {
        PoolInfo storage p = _getPool(chainId, pool);
        if (_checkState(p._state, AUTO_DEPOSIT)) {
            return;
        }

        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        // 如果该矿池是节点矿池，则尝试释放已解锁的代币
        if (!_checkState(p._state, AS_DELEGATOR)) {
            _cancel($p, msg.sender);
        }

        _addDividend($p, msg.sender, false, false);
        uint256 amount = _withdraw($p, msg.sender);

        // 产生代币
        address tokenWrapper = IRelayer(getRelayer()).getTokenWrapper(chainId);
        IERC20(tokenWrapper).transfer(msg.sender, amount);

        emit GetReward(chainId, pool, msg.sender, amount);
    }

    function lockShareToMarket(
        uint16 chainId,
        bytes32 pool,
        address owner,
        uint256 amount
    ) external isMarket {
        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _lock($p, owner, amount);
    }

    function unlockShareFromMarket(
        uint16 chainId,
        bytes32 pool,
        address owner,
        uint256 amount
    ) external isMarket {
        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _unlock($p, owner, amount);
    }

    function transferShare(
        uint16 chainId,
        bytes32 pool,
        address from,
        address to,
        uint256 amount
    ) external isMarket {
        PoolInfo storage p = _getPool(chainId, pool);
        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _transfer($p, from, to, amount, _checkState(p._state, AUTO_DEPOSIT));
    }

    /**
     * @notice Updates the pool reward.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param amount The amount of reward tokens.
     */
    function updatePoolReward(
        uint16 chainId,
        bytes32 pool,
        uint256 amount
    ) external isRelayer {
        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _updateDividend($p, amount);

        emit PoolReward(chainId, pool, amount);
    }

    /**
     * @notice Unlocks a specified amount of shares in a pool.
     * @param chainId The ID of the blockchain.
     * @param pool The address of the pool.
     * @param amount The amount of shares to unlock.
     */
    function unlockPoolShare(
        uint16 chainId,
        bytes32 pool,
        uint256 amount
    ) external isRelayer {
        PoolInfo storage p = _getPool(chainId, pool);
        if (_checkState(p._state, AS_DELEGATOR))
            revert NonCollator(chainId, pool);

        DepositPool storage $p = _getPoolDeposit(chainId, pool);
        _refund($p, amount);
    }
}
