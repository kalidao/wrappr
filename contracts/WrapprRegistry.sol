// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Minimalist and gas efficient standard ERC-1155 implementation with supply tracking.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /// -----------------------------------------------------------------------
    /// ERC-1155 STORAGE
    /// -----------------------------------------------------------------------
    
    mapping(uint256 => uint256) public totalSupply;

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// METADATA LOGIC
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view virtual returns (string memory);

    /// -----------------------------------------------------------------------
    /// ERC-1155 LOGIC
    /// -----------------------------------------------------------------------

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual {
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        balanceOf[from][id] -= amount;
        
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTHORIZED");

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i = 0; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;
            
            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value.
            unchecked {
                balanceOf[to][id] += amount;
            }

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data) ==
                    ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i = 0; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC-165 LOGIC
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165 Interface ID for ERC-165
            interfaceId == 0xd9b67a26 || // ERC-165 Interface ID for ERC-1155
            interfaceId == 0x0e89341c; // ERC-165 Interface ID for ERC1155MetadataURI
    }

    /// -----------------------------------------------------------------------
    /// INTERNAL MINT/BURN LOGIC
    /// -----------------------------------------------------------------------

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal virtual {
        totalSupply[id] += amount;
        
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value. 
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;
        
        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply[id] -= amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

/// @notice Compound-like voting extension for ERC-1155.
/// @author KaliCo LLC
abstract contract ERC1155Votes is ERC1155 {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate,
        uint256 id
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint256 indexed id,
        uint256 previousBalance,
        uint256 newBalance
    );

    /// -----------------------------------------------------------------------
    /// VOTING STORAGE
    /// -----------------------------------------------------------------------
     
    mapping(address => mapping(uint256 => address)) internal _delegates;

    mapping(address => mapping(uint256 => uint256)) public numCheckpoints;

    mapping(address => mapping(uint256 => mapping(uint256 => Checkpoint))) public checkpoints;
    
    struct Checkpoint {
        uint64 fromTimestamp;
        uint192 votes;
    }

    /// -----------------------------------------------------------------------
    /// DELEGATION LOGIC
    /// -----------------------------------------------------------------------

    function delegates(address account, uint256 id) public view virtual returns (address) {
        address current = _delegates[account][id];

        return current == address(0) ? account : current;
    }

    function getCurrentVotes(address account, uint256 id) public view virtual returns (uint256) {
        // Won't underflow because decrement only occurs if positive `nCheckpoints`.
        unchecked {
            uint256 nCheckpoints = numCheckpoints[account][id];

            return
                nCheckpoints != 0
                    ? checkpoints[account][id][nCheckpoints - 1].votes
                    : 0;
        }
    }

    function getPriorVotes(
        address account, 
        uint256 id,
        uint256 timestamp
    )
        public
        view
        virtual
        returns (uint256)
    {
        require(block.timestamp > timestamp, "UNDETERMINED");

        uint256 nCheckpoints = numCheckpoints[account][id];

        if (nCheckpoints == 0) return 0;

        // Won't underflow because decrement only occurs if positive `nCheckpoints`.
        unchecked {
            if (
                checkpoints[account][id][nCheckpoints - 1].fromTimestamp <=
                timestamp
            ) return checkpoints[account][id][nCheckpoints - 1].votes;

            if (checkpoints[account][id][0].fromTimestamp > timestamp) return 0;

            uint256 lower;

            uint256 upper = nCheckpoints - 1;

            while (upper > lower) {
                uint256 center = upper - (upper - lower) / 2;

                Checkpoint memory cp = checkpoints[account][id][center];

                if (cp.fromTimestamp == timestamp) {
                    return cp.votes;
                } else if (cp.fromTimestamp < timestamp) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }

            return checkpoints[account][id][lower].votes;
        }
    }

    function delegate(address delegatee, uint256 id) public payable virtual {
        address currentDelegate = delegates(msg.sender, id);

        _delegates[msg.sender][id] = delegatee;

        emit DelegateChanged(msg.sender, currentDelegate, delegatee, id);

        _moveDelegates(currentDelegate, delegatee, id, balanceOf[msg.sender][id]);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 id,
        uint256 amount
    ) internal virtual {
        if (srcRep != dstRep && amount != 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep][id];

                uint256 srcRepOld;

                // Won't underflow because decrement only occurs if positive `srcRepNum`.
                unchecked {
                    srcRepOld = srcRepNum != 0
                        ? checkpoints[srcRep][id][srcRepNum - 1].votes
                        : 0;
                }

                _writeCheckpoint(srcRep, id, srcRepNum, srcRepOld, srcRepOld - amount);
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep][id];

                // Won't underflow because decrement only occurs if positive `dstRepNum`.
                unchecked {
                    uint256 dstRepOld = dstRepNum != 0
                        ? checkpoints[dstRep][id][dstRepNum - 1].votes
                        : 0;
                    
                     _writeCheckpoint(dstRep, id, dstRepNum, dstRepOld, dstRepOld + amount);
                }
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 id,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal virtual {
        unchecked {
            uint64 timestamp = safeCastTo64(block.timestamp);

            // Won't underflow because decrement only occurs if positive `nCheckpoints`.
            if (
                nCheckpoints != 0 &&
                checkpoints[delegatee][id][nCheckpoints - 1].fromTimestamp ==
                timestamp
            ) {
                checkpoints[delegatee][id][nCheckpoints - 1].votes = safeCastTo192(
                    newVotes
                );
            } else {
                checkpoints[delegatee][id][nCheckpoints] = Checkpoint(
                    timestamp,
                    safeCastTo192(newVotes)
                );

                // Won't realistically overflow.
                ++numCheckpoints[delegatee][id];
            }
        }

        emit DelegateVotesChanged(delegatee, id, oldVotes, newVotes);
    }

    function safeCastTo64(uint256 x) internal pure virtual returns (uint64 y) {
        require(x < 1 << 64);

        y = uint64(x);
    }

    function safeCastTo192(uint256 x) internal pure virtual returns (uint192 y) {
        require(x < 1 << 192);

        y = uint192(x);
    }
}

/// @notice Helper utility that enables calling multiple local methods in a single call.
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol)
abstract contract Multicall {
    function multicall(bytes[] calldata data)
        public
        virtual
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length; ) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                if (result.length < 68) revert();

                assembly {
                    result := add(result, 0x04)
                }

                revert(abi.decode(result, (string)));
            }

            results[i] = result;

            // An array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                ++i;
            }
        }
    }
}

/// @title Wrappr
/// @author KaliCo LLC
/// @notice Ricardian contract for on-chain structures.
contract Wrappr is ERC1155Votes, Multicall {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event OwnerOfSet(address indexed operator, address indexed to, uint256 id);

    event ManagerSet(address indexed operator, address indexed to, bool approval);

    event AdminSet(address indexed operator, address indexed to);

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
        require(manager[msg.sender] || msg.sender == admin || msg.sender == ownerOf[id], "NOT_AUTHORIZED");

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
        require(manager[msg.sender] || msg.sender == admin || msg.sender == ownerOf[id], "NOT_AUTHORIZED");

        __burn(from, id, amount);
    }

    /// -----------------------------------------------------------------------
    /// OWNER FUNCTIONS
    /// -----------------------------------------------------------------------

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

    function setOwnerOf(address to, uint256 id)
        public
        payable
        onlyOwnerOfOrAdmin(id)
        virtual
    {
        ownerOf[id] = to;

        emit OwnerOfSet(msg.sender, to, id);
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

    function setAdmin(address to) public payable onlyAdmin virtual {
        admin = to;

        emit AdminSet(msg.sender, to);
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

/// @title Wrappr Registry
/// @author KaliCo LLC
/// @notice Factory to deploy ricardian contracts.
contract WrapprRegistry is Multicall {
    event WrapprRegistered(
        address indexed structure, 
        string name, 
        string symbol, 
        string baseURI, 
        uint256 mintFee, 
        address indexed admin
    );

    function registerWrappr(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        uint256 _mintFee,
        address _admin
    ) external payable {
        address structure = address(
            new Wrappr{salt: keccak256(bytes(_name))}(
                _name,
                _symbol,
                _baseURI,
                _mintFee,
                _admin
            )
        );

        emit WrapprRegistered(
            structure, 
            _name, 
            _symbol, 
            _baseURI, 
            _mintFee, 
            _admin
        );
    }
}
