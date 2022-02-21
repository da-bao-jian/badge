// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

// import "openzeppelin/token/ERC721/IERC721.sol";
// import "openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import "openzeppelin/token/ERC721/IERC721Receiver.sol";
import "openzeppelin/utils/Address.sol";

/**
 * @dev Badge Contract is backward compatible with ERC721
 */
contract Badge {
    using Address for address;

    modifier onlyExpired(uint256 tokenId) {
        require(
            _badgeMeta[tokenId].expirationDate > block.timestamp,
            "Function only available for expiration"
        );
        _;
    }

    modifier onlyManager() {
        require(
            msg.sender == _manager,
            "Badge: Only manager can call this function"
        );
        _;
    }

    // deployer's address
    address public _manager;

    // Badge's name
    string private _name;

    // Badge's symbol
    string private _symbol;

    // number of epochs until expiration
    // each episode is 1 month
    uint256 private _episodes;

    // Badge's metadata
    struct BadgeMeta {
        // read dynamic NFT
        // time when badge was created
        uint256 start;
        // epochs until expiration
        uint256 daysTillExp;
        // Date when badge expires
        uint256 expirationDate;
    }

    // Mapping from token ID to owner's address
    mapping(uint256 => address) private _owners;

    mapping(uint256 => BadgeMeta) private _badgeMeta;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from owner's address to token ID
    mapping(address => uint256) private _tokens;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    constructor(
        string memory badgeName,
        string memory badgeSymbol,
        uint256 episodes
    ) {
        _manager = msg.sender;

        _name = badgeName;
        _symbol = badgeSymbol;
        _episodes = episodes;
    }

    // ===== Badge Manager Functions =====

    /// @notice Returns the badge's name
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Returns the badge's symbol
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // Returns the token ID owned by `owner`, if it exists, and 0 otherwise
    function tokenOf(address owner) public view returns (uint256) {
        require(owner != address(0), "Invalid owner at zero address");

        return _tokens[owner];
    }

    // Returns the owner of a given token ID, reverts if the token does not exist
    function ownerOf(uint256 tokenId) public view returns (address) {
        require(tokenId != 0, "Invalid tokenId value");

        address owner = _owners[tokenId];

        require(owner != address(0), "Invalid owner at zero address");

        return owner;
    }

    // Checks if a token ID exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function mint(address to, uint256 tokenId) external onlyManager {
        require(_mint(to, tokenId), "Mint Failed");
    }

    /// @notice Mints `tokenId` and transfers it to `to`.
    /// @dev
    function _mint(address to, uint256 tokenId) internal returns (bool) {
        // require(!_exists(tokenId), "Token already minted");
        // require(tokenOf(to) == 0, "Owner already has a token");

        _tokens[to] = tokenId;
        _owners[tokenId] = to;

        BadgeMeta memory badgeMeta;
        badgeMeta.start = block.timestamp;
        badgeMeta.daysTillExp = _episodes * 30 days;
        badgeMeta.expirationDate = badgeMeta.start + badgeMeta.daysTillExp;
        _badgeMeta[tokenId] = badgeMeta;

        return true;
    }

    function burn(uint256 tokenId) external onlyManager {
        _burn(tokenId);
    }

    /// @dev Burns `tokenId`.
    function _burn(uint256 tokenId) internal {
        address owner = Badge.ownerOf(tokenId);

        delete _tokens[owner];
        delete _owners[tokenId];
    }

    function self() public view returns (address) {
        return address(this);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return "";
    }

    // ===== ERC721 Functions =====

    function balanceOf(address owner) external view returns (uint256 balance) {
        require(
            owner != address(0),
            "ERC721: balance query for the zero address"
        );
        return _balances[owner];
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(
            _exists(tokenId),
            "ERC721: approved query for nonexistent token"
        );

        return _tokenApprovals[tokenId];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public {
        require(
            _isApprovedOrOwner(_manager, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        require(
            _exists(tokenId),
            "ERC721: operator query for nonexistent token"
        );
        address owner = Badge.ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        require(
            Badge.ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(Badge.ownerOf(tokenId), to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    _manager,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function approve(address to, uint256 tokenId) public {
        address owner = Badge.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            msg.sender == _manager || isApprovedForAll(_manager, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal pure {
        return;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal pure {
        return;
    }
}
