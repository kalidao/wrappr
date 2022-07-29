// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC1155Votes} from "./ERC1155Votes.sol";
import {Multicall} from "./Multicall.sol";

/// @title Wrappr
/// @author KaliCo LLC
/// @notice Ricardian contract for on-chain structures.
contract Wrappr is ERC1155Votes, Multicall {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event OwnerOfSet(address indexed operator, address indexed to, uint256 id);

    event ManagerSet(address indexed operator, address indexed to, bool approval);

    event AdminSet(address indexed operator, address indexed admin);

    event TransferabilitySet(address indexed operator, uint256 id, bool transferability);

    event PermissionSet(address indexed operator, uint256 id, bool permission);

    event UserPermissionSet(address indexed operator, address indexed to, uint256 id, bool permission);

    event BaseURIset(address indexed operator, string baseURI);

    event UserURIset(address indexed operator, address indexed to, uint256 id, string uuri);

    event MintFeeSet(address indexed operator, uint256 mintFee);

    /// -----------------------------------------------------------------------
    /// WRAPPR STORAGE/LOGIC
    /// -----------------------------------------------------------------------

    string public name;

    string public symbol;

    string internal baseURI;

    uint256 internal mintFee;

    address public admin;

    mapping(uint256 => address) public ownerOf;

    mapping(address => bool) public manager;

    mapping(uint256 => bool) internal registered;

    mapping(uint256 => bool) public transferable;

    mapping(uint256 => bool) public permissioned;

    mapping(address => mapping(uint256 => bool)) public userPermissioned;

    mapping(uint256 => string) internal uris;

    mapping(address => mapping(uint256 => string)) public userURI;

    modifier onlyAdmin() virtual {
        require(msg.sender == admin, "NOT_ADMIN");

        _;
    }

    modifier onlyOwnerOfOrAdmin(uint256 id) virtual {
        require(msg.sender == ownerOf[id] || msg.sender == admin, "NOT_AUTHORIZED");

        _;
    }

    function uri(uint256 id) public view override virtual returns (string memory) {
        string memory tokenURI = uris[id];

        if (bytes(tokenURI).length == 0) return baseURI;
        else return tokenURI;
    }

    /// -----------------------------------------------------------------------
    /// CONSTRUCTOR
    /// -----------------------------------------------------------------------

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _mintFee,
        address _admin
    ) payable {
        name = _name;

        symbol = _symbol;

        baseURI = _baseURI;

        mintFee = _mintFee;

        admin = _admin;

        emit BaseURIset(address(0), _baseURI);

        emit MintFeeSet(address(0), _mintFee);

        emit AdminSet(address(0), _admin);
    }

    /// -----------------------------------------------------------------------
    /// PUBLIC FUNCTIONS
    /// -----------------------------------------------------------------------

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data,
        string calldata tokenURI,
        address owner
    ) public payable virtual {
        uint256 fee = mintFee;

        if (fee != 0) require(msg.value == fee, "NOT_FEE");

        require(!registered[id], "REGISTERED");

        if (owner != address(0)) {
            ownerOf[id] = owner;

            emit OwnerOfSet(address(0), owner, id);
        }

        registered[id] = true;

        __mint(to, id, amount, data, tokenURI);
    }

    function burn(
        address from, 
        uint256 id, 
        uint256 amount
    ) public payable virtual {
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        __burn(from, id, amount);
    }

    /// -----------------------------------------------------------------------
    /// MANAGEMENT FUNCTIONS
    /// -----------------------------------------------------------------------

    function manageMint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data,
        string calldata tokenURI,
        address owner
    ) public payable virtual {
        require(msg.sender == ownerOf[id] || manager[msg.sender] || msg.sender == admin, "NOT_AUTHORIZED");

        if (!registered[id]) registered[id] = true;

        if (ownerOf[id] == address(0) && owner != address(0)) {
            ownerOf[id] = owner;

            emit OwnerOfSet(address(0), owner, id);
        }

        __mint(to, id, amount, data, tokenURI);
    }

    function manageBurn(
        address from,
        uint256 id,
        uint256 amount
    ) public payable virtual {
        require(msg.sender == ownerOf[id] || manager[msg.sender] || msg.sender == admin, "NOT_AUTHORIZED");

        __burn(from, id, amount);
    }

    /// -----------------------------------------------------------------------
    /// OWNER FUNCTIONS
    /// -----------------------------------------------------------------------
    
    function setOwnerOf(address to, uint256 id)
        public
        payable
        onlyOwnerOfOrAdmin(id)
        virtual
    {
        ownerOf[id] = to;

        emit OwnerOfSet(msg.sender, to, id);
    }

    function setTransferability(uint256 id, bool transferability) public payable onlyOwnerOfOrAdmin(id) virtual {
        transferable[id] = transferability;

        emit TransferabilitySet(msg.sender, id, transferability);
    }

    function setPermission(uint256 id, bool permission) public payable onlyOwnerOfOrAdmin(id) virtual {
        permissioned[id] = permission;

        emit PermissionSet(msg.sender, id, permission);
    }

    function setUserPermission(
        address to, 
        uint256 id, 
        bool permission
    ) public payable onlyOwnerOfOrAdmin(id) virtual {
        userPermissioned[to][id] = permission;

        emit UserPermissionSet(msg.sender, to, id, permission);
    }

    function setURI(uint256 id, string calldata tokenURI) public payable onlyOwnerOfOrAdmin(id) virtual {
        uris[id] = tokenURI;

        emit URI(tokenURI, id);
    }

    function setUserURI(
        address to, 
        uint256 id, 
        string calldata uuri
    ) public payable onlyOwnerOfOrAdmin(id) virtual {
        userURI[to][id] = uuri;

        emit UserURIset(msg.sender, to, id, uuri);
    }

    /// -----------------------------------------------------------------------
    /// ADMIN FUNCTIONS
    /// -----------------------------------------------------------------------

    function setManager(address to, bool approval)
        public
        payable
        onlyAdmin
        virtual
    {
        manager[to] = approval;

        emit ManagerSet(msg.sender, to, approval);
    }
    
    function setAdmin(address _admin) public payable onlyAdmin virtual {
        admin = _admin;

        emit AdminSet(msg.sender, _admin);
    }

    function setBaseURI(string calldata _baseURI)
        public
        payable
        onlyAdmin
        virtual
    {
        baseURI = _baseURI;

        emit BaseURIset(msg.sender, _baseURI);
    }

    function setMintFee(uint256 _mintFee) public payable onlyAdmin virtual {
        mintFee = _mintFee;

        emit MintFeeSet(msg.sender, _mintFee);
    }

    function claimFee(address to, uint256 amount)
        public
        payable
        onlyAdmin
        virtual
    {
        assembly {
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                mstore(0x00, hex"08c379a0") // Function selector of the error method.
                mstore(0x04, 0x20) // Offset of the error string.
                mstore(0x24, 19) // Length of the error string.
                mstore(0x44, "ETH_TRANSFER_FAILED") // The error string.
                revert(0x00, 0x64) // Revert with (offset, size).
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Transfer Functions
    /// -----------------------------------------------------------------------

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override virtual {
        super.safeTransferFrom(from, to, id, amount, data);

        require(transferable[id], "NONTRANSFERABLE");

        if (permissioned[id]) require(userPermissioned[from][id] && userPermissioned[to][id], "NOT_PERMITTED");

        _moveDelegates(delegates(from, id), delegates(to, id), id, amount);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public override virtual {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            require(transferable[id], "NONTRANSFERABLE");

            if (permissioned[id]) require(userPermissioned[from][id] && userPermissioned[to][id], "NOT_PERMITTED");

            _moveDelegates(delegates(from, id), delegates(to, id), id, amount);

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function __mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data,
        string calldata tokenURI
    ) internal virtual {
        _mint(to, id, amount, data);

        safeCastTo192(totalSupply[id]);

        _moveDelegates(address(0), delegates(to, id), id, amount);

        if (bytes(tokenURI).length != 0) {
            uris[id] = tokenURI;

            emit URI(tokenURI, id);
        }
    }

    function __burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        _burn(from, id, amount);

        _moveDelegates(delegates(from, id), address(0), id, amount);
    }
}
