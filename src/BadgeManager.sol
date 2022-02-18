// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./Badge.sol";
import "./IBadge.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Manager: caller is not the Badge Manager");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract BadgeManager is Ownable {

    mapping (address => bool) public clientMap;

    Badge[] public badgeList;
    
    constructor() {
    }

    function mintBadge(address to, bytes32 tokenId) public onlyOwner {
        if (clientMap[to]) _mintBadgeForExistingClient(to, tokenId);
        else _mintBadgeForNewClient(to, tokenId);
    }

    function createBadge(address badge) public onlyOwner {
        // use CREATE2
    }



    function _mintBadgeForExistingClient(address clientAddr, string calldata badgeName) private {
        // calls mint method from badge
    }

    function _mintBadgeForNewClient(address clientAddr, string calldata badgeName) private {
        // calls mint method from badge
    }

    // @dev: verify a client has a badge 
    function verifyClientBadge(address clientAddr, address badgeAddr) public view returns(bool){
        if (!verifyClient(clientAddr)) revert ("Client not found");

        if (IBadge(badgeAddr).verifyClientHasBadge(clientAddr, badgeAddr)) return true;
        else return false;
    }

    // @dev: verify a client's existence
    function verifyClient(address clientAddr) public view returns (bool) {
        return clientMap[clientAddr];
    }

    
    // @dev Badge wrapper to make badge a ERC721 token
    function wrapBadge(address _badge) external onlyOwner returns (bool) {

    }

}