// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

// event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
// event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
// event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

// function balanceOf(address owner) external view returns (uint256 balance);
// function ownerOf(uint256 tokenId) external view returns (address owner);
// function safeTransferFrom(
//     address from,
//     address to,
//     uint256 tokenId
// ) external;
// function transferFrom(
//     address from,
//     address to,
//     uint256 tokenId
// ) external;
// function approve(address to, uint256 tokenId) external;
// function getApproved(uint256 tokenId) external view returns (address operator);
// function setApprovalForAll(address operator, bool _approved) external;
// function isApprovedForAll(address owner, address operator) external view returns (bool);
// function safeTransferFrom(
//     address from,
//     address to,
//     uint256 tokenId,
//     bytes calldata data
// ) external;

interface IBadge {
    // @dev gives owner the right to mint new tokens
    function mint(address to, uint256 tokenId) external;

    // @dev check the badge token matches the identity object
    function verifyBadge(address clientAddr, address BadgeAddr)
        external
        view
        returns (bool);

    // @dev show badge info
    function getBadgeInfo(uint256 _tokenId) external view;

    function self() external view returns (address);
}
