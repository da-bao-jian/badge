// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./Badge.sol";

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
        require(
            owner() == _msgSender(),
            "Manager: caller is not the Badge Manager"
        );
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
    /// @dev This is a mapping for checking if a client exists
    mapping(address => bool) public clientMap;

    /// @dev This is a mapping to link client address to metadata
    mapping(address => ClientMeta) public clientMeta;

    /// @dev A mapping between a badge name and the address of the badge contract
    mapping(string => address) public badgeMapAddress;

    /// @dev A mapping of the badge name to the Badge object
    mapping(string => Badge) public badgeObj;

    /// @dev A mapping of the  client to badge name and number of expired badges
    ///     Solely used for checking if a client and badge exists
    mapping(address => mapping(string => uint256)) public clientBadgeNonce;

    /// @dev A mapping of the badgeId to check if a badge exists
    mapping(uint256 => bool) public badgeIdMap;

    /// @dev A struct to store a client's metadata
    struct ClientMeta {
        Badge[] badges;
        // ExBadge[] exBadges;
        string uri;
        string projName;
    }

    constructor() {}

    /// @notice Does not revert or throw when a client or badge do not exist
    /// @dev Return the current nonce of a client's badge
    function getNonce(address clientAddr, string memory badgeName)
        public
        view
        returns (uint256)
    {
        return clientBadgeNonce[clientAddr][badgeName];
    }

    /// @dev Create a client
    /// @param clientAddr The address of the client
    /// @param uri The URI of the client
    /// @param projName The name of the project
    function createClient(
        address clientAddr,
        string memory uri,
        string memory projName
    ) public returns (bool) {
        require(
            clientMap[clientAddr] == false,
            "Client: Client already exists"
        );
        ClientMeta memory meta;
        meta.uri = uri;
        meta.projName = projName;
        clientMeta[clientAddr] = meta;
        clientMap[clientAddr] = true;
        return true;
    }

    /// @notice Mint a badge for a client
    /// @dev Checks if the client exits, if not, creates a new client
    /// @param to Address of the client
    /// @param badgeName Id of the badge
    function mintBadge(address to, string memory badgeName) public onlyOwner {
        if (badgeMapAddress[badgeName] == address(0))
            revert("Manager: badge does not exist");
        if (!verifyClient(to))
            revert("Manager: client does not exist, call createClient() first");

        // get the badge symbol
        // here using symbol instead of name is because symbols are three characters long
        string memory badge = badgeObj[badgeName].symbol();

        // mint the badge for the client
        _mintBadgeForClient(to, badge);
    }

    /// @notice Deploy a new badge contract
    /// @dev  from the JavaScript side, the return type is a
    ///       'address' as this is the closest type available in the ABI
    /// @param badgeName Name of the badge
    /// @param badgeSymbol Symbol of the badge
    /// @return newBadge Address of the new badge contract
    /// TODO: add a function to incorporate non standard, seperately deployed badge contract
    function createBadge(string memory badgeName, string memory badgeSymbol)
        external
        onlyOwner
        returns (Badge newBadge)
    {
        if (badgeMapAddress[badgeName] != address(0))
            revert("Manager: badge already exists");

        // create the badge
        newBadge = new Badge(badgeName, badgeSymbol, 12);
        // add the badge to the list
        badgeObj[badgeName] = newBadge;
        // update the badgeMapAddress
        badgeMapAddress[badgeName] = address(newBadge);
    }

    /// @dev Mint a badge for a client
    function _mintBadgeForClient(address clientAddr, string memory badgeName)
        internal
    {
        // get the badge contract instance
        Badge badge = badgeObj[badgeName];

        // TODO: check the timestamp of the badge, if last one is not expire, revert

        // increment the nonce
        clientBadgeNonce[clientAddr][badgeName]++;
        // get the nonce
        uint256 nonce = clientBadgeNonce[clientAddr][badgeName];

        // generate tokenId and mint to the client
        uint256 tokenId = _generateTokenId(badgeName, clientAddr, nonce);
        badge.mint(clientAddr, tokenId);

        // update the client metadata
        clientMeta[clientAddr].badges.push(badge);
    }

    function _generateTokenId(
        string memory badgeName,
        address clientAddr,
        uint256 nounce
    ) internal returns (uint256) {
        // pack client's address, badge's symbol, and timestamp into uint256 as the tokenId
        uint256 tokenId = uint256(
            keccak256(abi.encode(badgeName, clientAddr, nounce))
        );
        badgeIdMap[tokenId] = true;
        return tokenId;
    }

    /// @notice Badge verification is done through the BadgeManager contract
    ///         To use this to verify a client, a mapping of client name to client address needs to be maintained
    /// @dev verify a client has a currently valid badge expensively by calculating the hash of the client's address and the badge's symbol on-chain
    function verifyClientBadgeExpensive(
        address clientAddr,
        string memory badgeName
    ) public view returns (bool) {
        if (badgeMapAddress[badgeName] == address(0))
            revert("Manager: badge does not exist");
        if (!verifyClient(clientAddr)) revert("Manager: client does not exist");

        uint256 nonce = getNonce(clientAddr, badgeName);
        uint256 tokenId = uint256(
            keccak256(abi.encode(badgeName, clientAddr, nonce))
        );

        if (badgeIdMap[tokenId]) return true;
        else return false;
    }

    /// @notice Badge verification is done through the BadgeManager contract
    ///         Hash needs to be calculated off-chain
    ///         Nonce could be quries from calling getNonce()
    ///         Since getNonce() don't throw, result needs to be checked
    /// @dev Verify a client has a currently valid badge cheaply by providing the hash
    function verifyClientBadgeCheap(uint256 tokenId)
        public
        view
        returns (bool)
    {
        if (badgeIdMap[tokenId]) return true;
        else return false;
    }

    /// @dev verify a client's existence
    function verifyClient(address clientAddr) public view returns (bool) {
        return clientMap[clientAddr];
    }

    /// @dev Badge wrapper to make badge a ERC721 token
    function wrapBadge(address _badge) external onlyOwner returns (bool) {
        // TODO: delete the tokenId from the badgeIdMap
        // TODO: delete the badge from clientmeta's array and push it into exBadge array
        // use burn from Badge contract
    }
}
