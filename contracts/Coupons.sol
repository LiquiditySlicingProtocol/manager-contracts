// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./interfaces/ICoupon.sol";
import "./library/EIP712.sol";
import "./library/ERC1155.sol";
import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
import "./utils/SignatureVerification.sol";

contract Coupons is ICoupon, EIP712, ERC1155, Ownable {
    using SafeMath for uint256;
    using SignatureVerification for bytes;

    bytes32 public constant _CLAIM_REQUEST_TYPEHASH =
        keccak256(
            "ClaimRequest(uint256 tokenId,uint256 amount,uint256 maxAmount,address claimer,uint256 nonce,uint256 deadline)"
        );

    struct Coupon {
        bool exists;
        uint64 discount;
        uint32 expiredAt;
        uint256 totalSupply;
    }
    struct ClaimRequest {
        uint256 tokenId;
        uint256 amount;
        uint256 maxAmount;
        address claimer;
        uint256 nonce;
        uint256 deadline;
    }

    uint8 constant _decimalsMask = 0xff;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _baseURI;

    uint256 private _totalSupplyAll;

    // mapping for token URIs
    mapping(uint256 tokenId => string) private _tokenURIs;

    // mapping for coupon information
    mapping(uint256 tokenId => Coupon) private _coupons;

    // user nonces
    mapping(address account => mapping(uint256 nonce => bool)) private _nonces;

    event NewCoupon(uint256 couponId, uint64 discount, uint32 expiredAt);

    event RevokeCoupon(uint256 couponId);

    constructor(
        address initialOwner,
        string memory baseURI
    ) Ownable(initialOwner) EIP712("LspCoupon") {
        _setBaseURI(baseURI);
    }

    modifier couponExists(uint256 tokenId) {
        require(_coupons[tokenId].exists, "!Exists");
        uint32 expiredAt = _coupons[tokenId].expiredAt;
        require(
            expiredAt == 0 || expiredAt > uint32(block.timestamp % 2 ** 32),
            "!Expired"
        );
        _;
    }

    function createCoupon(
        uint64 discount,
        uint32 expireTime,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner {
        uint8 decimals = uint8(discount & uint64(_decimalsMask));
        require(decimals <= 30, "!Large");
        if (decimals > 0) {
            require((discount >> 8) <= 10 ** (decimals + 2), "!Large");
        }

        uint256 tokenId = _totalSupplyAll;

        uint32 expiredAt;
        if (expireTime > 0) {
            expiredAt = uint32(block.timestamp % 2 ** 32) + expireTime;
        }

        _coupons[tokenId] = Coupon(true, discount, expiredAt, amount);

        if (amount > 0) {
            _mint(msg.sender, tokenId, amount, data);
        }
        _totalSupplyAll += 1;

        emit NewCoupon(tokenId, discount, expiredAt);
    }

    function mintCoupon(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner couponExists(tokenId) {
        require(amount > 0, "!Invalid");

        _mint(to, tokenId, amount, data);
        _coupons[tokenId].totalSupply += amount;
    }

    function burnCoupon(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external onlyOwner couponExists(tokenId) {
        require(amount > 0, "!Invalid");

        _burn(from, tokenId, amount);
        _coupons[tokenId].totalSupply -= amount;
    }

    function deleteCoupon(uint256 tokenId) external onlyOwner {
        _coupons[tokenId].exists = false;
    }

    function claimCoupon(
        ClaimRequest calldata req,
        bytes calldata mintData,
        bytes calldata signature
    ) external couponExists(req.tokenId) {
        require(req.claimer == msg.sender, "!Forbidden");
        require(block.timestamp < req.deadline, "!Expired");
        require(!_nonces[msg.sender][req.nonce], "!Nonce");
        require(
            balanceOf[msg.sender][req.tokenId] <= req.maxAmount - req.amount,
            "!Exceed"
        );

        bytes32 reqHash = EIP712._hashTypedData(_hashClaimRequest(req));
        signature.verify(reqHash, owner());
        _nonces[msg.sender][req.nonce] = true;

        _mint(msg.sender, req.tokenId, req.amount, mintData);
        _coupons[req.tokenId].totalSupply += req.amount;
    }

    function revokeCoupon(
        uint256 tokenId
    ) external onlyOwner couponExists(tokenId) {
        _coupons[tokenId].exists = false;

        emit RevokeCoupon(tokenId);
    }

    function hasCoupon(
        address referrer,
        uint256 tokenId
    ) external view returns (bool) {
        if (!_coupons[tokenId].exists) return false;
        uint32 expiredAt = _coupons[tokenId].expiredAt;
        if (expiredAt != 0 && expiredAt < uint32(block.timestamp % 2 ** 32))
            return false;
        return this.balanceOf(referrer, tokenId) > 0;
    }

    function computeDiscount(
        uint256 tokenId,
        uint256 price
    ) external view couponExists(tokenId) returns (uint256 checked) {
        uint64 base = _coupons[tokenId].discount;
        uint8 decimals = uint8(base & uint256(_decimalsMask));
        uint64 discount = base >> 8;
        if (decimals > 0) {
            checked = price - price.mul(discount).div(10 ** decimals);
        } else {
            checked = price - discount;
        }
    }

    /**
     * @dev Total value of tokens in with a given id.
     */
    function totalSupply(uint256 tokenId) public view returns (uint256) {
        return _coupons[tokenId].totalSupply;
    }

    /**
     * @dev Total value of tokens.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupplyAll;
    }

    /**
     * This implementation returns the concatenation of the `_baseURI`
     * and the token-specific uri if the latter is set
     *
     * This enables the following behaviors:
     *
     * - if `_tokenURIs[tokenId]` is set, then the result is the concatenation
     *   of `_baseURI` and `_tokenURIs[tokenId]` (keep in mind that `_baseURI`
     *   is empty per default);
     *
     * - if `_tokenURIs[tokenId]` is NOT set then we fallback to `super.uri()`
     *   which in most cases will contain `ERC1155._uri`;
     *
     * - if `_tokenURIs[tokenId]` is NOT set, and if the parents do not have a
     *   uri value set, then the result is empty.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];

        // If token URI is set, concatenate base URI and tokenURI (via string.concat).
        return
            bytes(tokenURI).length > 0
                ? string.concat(_baseURI, tokenURI)
                : _baseURI;
    }

    /**
     * @dev Sets `tokenURI` as the tokenURI of `tokenId`.
     */
    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    /**
     * @dev Sets `baseURI` as the `_baseURI` for all tokens
     */
    function _setBaseURI(string memory baseURI) internal {
        _baseURI = baseURI;
    }

    function _hashClaimRequest(
        ClaimRequest memory req
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_CLAIM_REQUEST_TYPEHASH, req));
    }
}
