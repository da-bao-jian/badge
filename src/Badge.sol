// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "openzeppelin/token/ERC721/IERC721.sol";
import "./IBadge.sol";

/**
 * @dev Basis Badge contract for badges
 */
abstract contract Badge is IBadge, IERC721 {

    modifier onlyExpired() {
        require(this.isExpired());
        _;
    }


    // deployer's address
    address public immutable _owner;

    // Mapping from Badge ID to owner address
    mapping(uint256 => address) private _owners;

    // Badge's name
    string private _name;

    // Badge's symbol
    string private _symbol;

    // Badge's identity object
    struct BadgeIdentity {
        string uri;
        string projectName;
    }

    // Badge's metadata
    struct Meta {
        // time when badge was created
        uint256 epoch;
        // epochs until expiration
        uint256 epochTillExp;
    }

    // Mapping from token ID to owner's address
    mapping(bytes32 => address) private _owners;

    // Mapping from owner's address to token ID
    mapping(address => bytes32) private _tokens;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;

        _owner = msg.sender;
    }

    // ===== Badge Manager Functions =====    

    // Returns the badge's name
    function name() public view virtual returns (string memory) {
        return _name;
    }

    // Returns the badge's symbol
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    // Returns the token ID owned by `owner`, if it exists, and 0 otherwise
    function tokenOf(address owner) public view virtual returns (bytes32) {
        require(owner != address(0), "Invalid owner at zero address");

        return _tokens[owner];
    }

    // Returns the owner of a given token ID, reverts if the token does not exist
    function ownerOf(bytes32 tokenId) public view virtual returns (address) {
        require(tokenId != 0, "Invalid tokenId value");

        address owner = _owners[tokenId];

        require(owner != address(0), "Invalid owner at zero address");

        return owner;
    }

    // Checks if a token ID exists
    function _exists(bytes32 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    // @dev Mints `tokenId` and transfers it to `to`.
    function _mint(address to, bytes32 tokenId) internal virtual {
        require(msg.sender == _owner, "Only the owner can mint");
        require(to != address(0), "Invalid owner at zero address");
        require(tokenId != 0, "Token ID cannot be zero");
        require(!_exists(tokenId), "Token already minted");
        require(tokenOf(to) == 0, "Owner already has a token");

        _tokens[to] = tokenId;
        _owners[tokenId] = to;
    }

    // @dev Burns `tokenId`.
    function _burn(bytes32 tokenId) internal virtual {
        address owner = Badge.ownerOf(tokenId);

        delete _tokens[owner];
        delete _owners[tokenId];
    }
}
