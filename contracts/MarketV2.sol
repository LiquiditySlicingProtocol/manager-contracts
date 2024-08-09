// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IPoolV2} from "./interfaces/IPoolV2.sol";
import {IDeposit} from "./interfaces/IDeposit.sol";
import {IShare} from "./interfaces/IShare.sol";
import {ICoupon} from "./interfaces/ICoupon.sol";
import {MarketV2Base} from "./MarketV2Base.sol";
import {SafeERC20} from "./utils/SafeERC20.sol";

error InvalidAmount(uint256 amount, uint256 minUnit);
error InsufficientShare(uint256 available);
error ListingNotAllowed(uint16 chainId, bytes32 pool);
error ListingCannotCancel(uint256 id);
error ListingOffSale(uint256 id);

contract MarketV2 is MarketV2Base, AccessManagedUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
      _disableInitializers();
    }

    /**
     * @dev called by DiamondCut function
     */
    function initialize(
        address newManager,
        address token,
        uint256 listFee_,
        uint256 buyFee_
    ) external {
        _setManager(newManager);
        _setPayment(token);
        _setListFee(listFee_);
        _setBuyFee(buyFee_);
    }

    function addList(ListRequest calldata data) external {
        require(data.minUnit != 0);
        require(data.unitPrice != 0);
        if (data.amount < data.minUnit || data.amount % data.minUnit != 0)
            revert InvalidAmount(data.amount, data.minUnit);

        address manager = getManager();
        IDeposit.StakingData memory userStaking = IDeposit(manager)
            .getUserStaking(data.chainId, data.pool, msg.sender);
        if (userStaking.freezed < data.amount)
            revert InsufficientShare(userStaking.freezed);

        if (
            !IPoolV2(manager).checkPoolState(
                data.chainId,
                data.pool,
                0x8 // ALLOW_LISTING defined in Pool
            )
        ) revert ListingNotAllowed(data.chainId, data.pool);

        IShare(manager).lockShareToMarket(
            data.chainId,
            data.pool,
            msg.sender,
            data.amount
        );

        List memory list;
        list.chainId = data.chainId;
        list.pool = data.pool;
        list.amount = data.amount;
        list.minUnit = data.minUnit;
        list.unitPrice = data.unitPrice;

        _addList(list);
    }

    function cancelList(uint256 id) external {
        List storage list = _getList(id);

        require(list.seller == msg.sender);
        if (list.status > uint8(ListStatus.OnSale))
            revert ListingCannotCancel(id);

        address manager = getManager();
        IShare(manager).unlockShareFromMarket(
            list.chainId,
            list.pool,
            msg.sender,
            list.amount
        );

        list.status = uint8(ListStatus.Canceled);

        emit CancelList(id);
    }

    function makeOrder(uint256 id, uint256 amount) external {
        List storage list = _getList(id);

        if (list.status != uint8(ListStatus.OnSale)) revert ListingOffSale(id);

        if (list.amount < amount) revert InsufficientShare(list.amount);
        if (amount < list.minUnit || amount % list.minUnit != 0)
            revert InvalidAmount(amount, list.minUnit);

        uint256 price = list.unitPrice * (amount / list.minUnit);
        uint256 buyFee_ = _computeFee(list.buyFee, price);
        if (buyFee_ > 0) {
            IERC20(getPayment()).safeTransferFrom(
                msg.sender,
                address(this),
                buyFee_
            );
        }

        uint256 listFee_ = _computeFee(list.listFee, price);
        if (listFee_ > 0) {
            IERC20(getPayment()).safeTransferFrom(
                msg.sender,
                address(this),
                listFee_
            );
            price -= listFee_;
        }
        if (price > 0) {
            IERC20(getPayment()).safeTransferFrom(
                msg.sender,
                list.seller,
                price
            );
        }

        address manager = getManager();
        // TODO 如果非锁仓代币订单成交，需要跨链通知吗？
        IShare(manager).transferShare(
            list.chainId,
            list.pool,
            list.seller,
            msg.sender,
            amount
        );

        list.amount -= amount;
        if (list.amount == 0) {
            list.status = uint8(ListStatus.Finished);
        }

        emit MakeOrder(msg.sender, id, amount);
    }

    function setManager(address newManager) public restricted {
        _setManager(newManager);
    }

    function setPayment(address token) public restricted {
        _setPayment(token);
    }

    function setListFee(uint256 value) public restricted {
        _setListFee(value);
    }

    function setBuyFee(uint256 value) public restricted {
        _setBuyFee(value);
    }
}
