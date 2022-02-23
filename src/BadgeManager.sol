// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./Badge.sol";

// abstract contract Ownable is Context {
//     address private _owner;

//     event OwnershipTransferred(
//         address indexed previousOwner,
//         address indexed newOwner
//     );

//     constructor() {
//         _transferOwnership(_msgSender());
//     }

//     function owner() public view virtual returns (address) {
//         return _owner;
//     }

//     modifier onlyOwner() {
//         require(
//             owner() == _msgSender(),
//             "Manager: caller is not the Badge Manager"
//         );
//         _;
//     }

//     function renounceOwnership() public virtual onlyOwner {
//         _transferOwnership(address(0));
//     }

//     function transferOwnership(address newOwner) public virtual onlyOwner {
//         require(
//             newOwner != address(0),
//             "Ownable: new owner is the zero address"
//         );
//         _transferOwnership(newOwner);
//     }

//     function _transferOwnership(address newOwner) internal virtual {
//         address oldOwner = _owner;
//         _owner = newOwner;
//         emit OwnershipTransferred(oldOwner, newOwner);
//     }
// }


/**
 * @dev BadgeManager is the factory contract to deploy badges and keep track of
 *  clients and badges info
 */
contract BadgeManager {
    /// This is a mapping for checking if a client exists
    mapping(address => bool) public clientMap;

    ///  This is a mapping to link client address to metadata
    mapping(address => ClientMeta) public clientMeta;

    ///  A mapping between a badge name and the address of the badge contract
    mapping(string => address) public badgeMapAddress;

    ///  A mapping of the badge name to the Badge object
    mapping(string => Badge) public badgeObj;

    /// A mapping of the  client to badge name and number of expired badges
    /// Solely used for checking if a client and badge exists
    mapping(address => mapping(string => uint256)) public clientBadgeNonce;

    /// @notice This mapping only contains non-expired badges,
    ///         expired badges will be set to false in wrapBadge()
    /// @dev  A mapping of the badgeId to check if a badge exists
    mapping(uint256 => bool) public badgeIdMap;

    /// A struct to store a client's metadata
    struct ClientMeta {
        Badge[] badges;
        // Badge[] exBadges;
        string uri;
        string projName;
    }

    address public manager;
    
    modifier onlyOwner() {
        require(
            owner() == _msgSender(),
            "Manager: caller is not the Badge Manager"
        );
        _;
    }

    event Removal(string badgeName, address client);

    constructor() {
        manager = msg.sender;
    }

    function owner() public view returns (address) {
        return manager;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

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
        string calldata uri,
        string calldata projName
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
    function mintBadge(address to, string calldata badgeName, string calldata uri) public onlyOwner {
        if (badgeMapAddress[badgeName] == address(0))
            revert("Manager: badge does not exist");
        if (!verifyClient(to))
            revert("Manager: client does not exist, call createClient() first");

        // get the badge symbol
        // here using symbol instead of name is because symbols are three characters long
        string memory badge = badgeObj[badgeName].symbol();

        // mint the badge for the client
        _mintBadgeForClient(to, badge, uri);
    }

    /// @notice Deploy a new badge contract
    /// @dev  The BadgeManager follows the factory pattern to deploy badge contracts
    ///       However, the catch here is we want the BadgeManager to deploy different contracts
    ///       instead of instances of the same contract.
    ///       To do so, we use the CREATE2 opcode to deploy contract that has been
    ///       written, tested, and ready to deploy
    ///       Assumption:
    ///         all badge contracts inherit from the Badge abstract contract and
    ///         only takes three arguments in contract constructor
    ///       Example off-chain implementation:
    ///       https://github.com/miguelmota/solidity-create2-example/blob/master/test/utils/index.js
    /// @param badgeName Name of the badge
    /// @param badgeSymbol Symbol of the badge
    /// @param salt A random number used to create the pre-computed address
    ///        A hashtable of salt and address should be maintained off-chain
    /// @param creationCode The to-be deployed contract's bytecode
    /// @return deployedContract Address of the new badge contract
    function createBadge(
        string memory badgeName,
        string memory badgeSymbol,
        uint256 episodes,
        uint256 salt,
        bytes memory creationCode
    ) external onlyOwner returns (address deployedContract) {
        if (badgeMapAddress[badgeName] != address(0))
            revert("Manager: badge already exists");

        // create the badge
        // newBadge = new Badge(badgeName, badgeSymbol, 12);

        // get the contract bytecode
        bytes memory contractBytecode = _getByteCode(
            badgeName,
            badgeSymbol,
            episodes,
            creationCode
        );

        // deploy contract using CREATE2 opcode
        assembly {
            deployedContract := create2(
                callvalue(),
                add(contractBytecode, 0x20),
                mload(contractBytecode),
                salt
            )

            if iszero(extcodesize(deployedContract)) {
                revert(0, 0)
            }
        }

        // add the badge to the list
        badgeObj[badgeName] = Badge(deployedContract);
        // update the badgeMapAddress
        badgeMapAddress[badgeName] = deployedContract;
    }

    /// @dev Conpute the `initCode` for a new badge contract
    ///      given three arguments: badgeName, badgeSymbol, and episodes
    /// @param badgeName Name of the badge
    /// @param badgeSymbol Symbol of the badge
    /// @param episodes Number of episodes
    /// @param creationCode The contract bytecode
    ///        Provided from createBadge(), computed off-chain
    /// @return bytecode The initCode of the new badge contract
    function _getByteCode(
        string memory badgeName,
        string memory badgeSymbol,
        uint256 episodes,
        bytes memory creationCode
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                creationCode,
                abi.encode(badgeName, badgeSymbol, episodes)
            );
    }

    /// @dev Mint a badge for a client
    function _mintBadgeForClient(address clientAddr, string memory badgeName, string calldata uri)
        internal
    {
        // get the badge contract instance
        Badge badge = badgeObj[badgeName];

        uint256 tokenId = _getTokenId(clientAddr, badgeName);

        if (badgeIdMap[tokenId]) revert("Manager: last badge has not expired");

        if (keccak256(abi.encodePacked(clientMeta[clientAddr].uri)) != keccak256(abi.encodePacked(uri)))
            revert("Manager: client uri does client profile");

        // increment the nonce
        unchecked {
            // counter overflow is extreeemly unlikely
            clientBadgeNonce[clientAddr][badgeName]++;
        }
        // get the new nonce
        uint256 nonce = clientBadgeNonce[clientAddr][badgeName];

        // generate tokenId and mint to the client
        tokenId = _generateTokenId(badgeName, clientAddr, nonce);
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
            keccak256(abi.encodePacked(badgeName, clientAddr, nounce))
        );
        badgeIdMap[tokenId] = true;
        return tokenId;
    }

    function _getTokenId(address clientAddr, string memory badgeName)
        internal
        view
        returns (uint256)
    {
        uint256 nonce = getNonce(clientAddr, badgeName);
        uint256 tokenId = uint256(
            keccak256(abi.encodePacked(badgeName, clientAddr, nonce))
        );
        return tokenId;
    }

    /// @notice Badge verification is done through the BadgeManager contract
    ///         To use this to verify a client, a mapping of client name to client address needs to be maintained
    /// @dev verify a client has a currently valid badge expensively by calculating the hash of the client's address and the badge's symbol on-chain
    function verifyClientBadgeExpensive(
        address clientAddr,
        string calldata badgeName
    ) public view returns (bool) {
        if (badgeMapAddress[badgeName] == address(0))
            revert("Manager: badge does not exist");
        if (!verifyClient(clientAddr)) revert("Manager: client does not exist");

        uint256 tokenId = _getTokenId(clientAddr, badgeName);

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

    function verifyClient(address clientAddr) internal view returns (bool) {
        return clientMap[clientAddr];
    }

    /// @dev Badge wrapper to make badge a ERC721 token
    ///      A list of badge and client info should be maintained off-chain
    ///      The off-chain code should be able to call wrapBadge() automatically when the time is up
    function wrapBadge(
        address _badge,
        address clientAddr,
        string calldata _badgeName
    ) external onlyOwner returns (bool) {
        uint256 tokenId = _getTokenId(clientAddr, _badgeName);
        Badge(_badge).convert(tokenId);

        // gas optimization
        unchecked {
            // inefficient, but since this function is only called when a badge expires, it's fine
            for (uint256 i = 0; i < clientMeta[clientAddr].badges.length; i++) {
                if (
                    Badge(clientMeta[clientAddr].badges[i]).isExpired(
                        tokenId
                    ) &&
                    keccak256(
                        abi.encodePacked(
                            clientMeta[clientAddr].badges[i].name()
                        )
                    ) ==
                    keccak256(abi.encodePacked(_badgeName))
                ) {
                    Badge removed = _arrRemover(
                        i,
                        clientMeta[clientAddr].badges
                    );

                    emit Removal(removed.name(), clientAddr);
                    break;
                }
            }
        }

        delete badgeIdMap[tokenId];

        return true;
    }

    /// @dev Helper function to efficiently remove an element from an array
    function _arrRemover(uint256 index, Badge[] storage badges)
        internal
        returns (Badge removed)
    {
        Badge temp = badges[badges.length - 1];
        badges[badges.length - 1] = badges[index];
        badges[index] = temp;
        removed = badges[badges.length - 1];
        badges.pop();
    }
}
