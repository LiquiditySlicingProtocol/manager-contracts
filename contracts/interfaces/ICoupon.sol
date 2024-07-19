// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ICoupon
 * @notice Interface for coupon verification and discount computation.
 */
interface ICoupon {
    /**
     * @notice Checks if a referrer possesses a specific coupon.
     * @param referrer The address of the referrer.
     * @param couponId The identifier of the coupon.
     * @return bool Returns true if the referrer possesses the coupon, otherwise false.
     */
    function hasCoupon(address referrer, uint256 couponId) external view returns (bool);

    /**
     * @notice Computes the discount for a given coupon and price.
     * @param couponId The identifier of the coupon.
     * @param price The original price before discount.
     * @return uint256 Returns the discounted price.
     */
    function computeDiscount(uint256 couponId, uint256 price) external view returns (uint256);
}
