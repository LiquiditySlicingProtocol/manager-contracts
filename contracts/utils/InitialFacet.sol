// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract InitialFacet {
    
    address immutable _this;
    address immutable _diamond;

    error InvalidCall(address who);

    constructor(address diamondCore_) {
        _this = address(this);
        _diamond = diamondCore_;
    }

    modifier onlyDiamond() {
        if (address(this) == _this) {
            revert InvalidCall(msg.sender);
        }
        if (address(this) != _diamond) {
            revert InvalidCall(address(this));
        }
        _;
    }

}
