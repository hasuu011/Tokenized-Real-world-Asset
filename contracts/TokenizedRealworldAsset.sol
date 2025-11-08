IPFS or SHA256 hash for proof of ownership
        uint256 totalShares;
        uint256 pricePerShare;
        bool verified;
        address owner;
    }

    mapping(uint256 => Asset) public assets;
    mapping(uint256 => mapping(address => uint256)) public ownership; // assetId ? (owner ? shares)

    event AssetTokenized(
        uint256 indexed id,
        string name,
        string assetType,
        uint256 totalShares,
        uint256 pricePerShare,
        address indexed owner
    );

    event SharesTransferred(uint256 indexed assetId, address indexed from, address indexed to, uint256 shares);
    event AssetVerified(uint256 indexed assetId, address indexed verifier);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /**
     * @notice Tokenize a new real-world asset into fractional shares
     * @param _name Name of the asset
     * @param _assetType Type/category of the asset (e.g., Real Estate, Gold, Art)
     * @param _documentHash Hash or proof document stored off-chain
     * @param _totalShares Total shares (tokens) representing ownership
     * @param _pricePerShare Price per share in wei
     */
    function tokenizeAsset(
        string memory _name,
        string memory _assetType,
        string memory _documentHash,
        uint256 _totalShares,
        uint256 _pricePerShare
    ) external {
        require(bytes(_name).length > 0, "Asset name required");
        require(bytes(_assetType).length > 0, "Asset type required");
        require(_totalShares > 0, "Invalid share count");
        require(_pricePerShare > 0, "Invalid price");

        assetCount++;
        assets[assetCount] = Asset({
            id: assetCount,
            name: _name,
            assetType: _assetType,
            documentHash: _documentHash,
            totalShares: _totalShares,
            pricePerShare: _pricePerShare,
            verified: false,
            owner: msg.sender
        });

        ownership[assetCount][msg.sender] = _totalShares;

        emit AssetTokenized(assetCount, _name, _assetType, _totalShares, _pricePerShare, msg.sender);
    }

    /**
     * @notice Transfer fractional ownership of an asset
     * @param _assetId ID of the asset
     * @param _to Recipient address
     * @param _shares Number of shares to transfer
     */
    function transferShares(uint256 _assetId, address _to, uint256 _shares) external {
        require(ownership[_assetId][msg.sender] >= _shares, "Insufficient shares");
        require(_shares > 0, "Invalid amount");

        ownership[_assetId][msg.sender] -= _shares;
        ownership[_assetId][_to] += _shares;

        emit SharesTransferred(_assetId, msg.sender, _to, _shares);
    }

    /**
     * @notice Verify an asset (admin only)
     * @param _assetId ID of the asset
     */
    function verifyAsset(uint256 _assetId) external onlyAdmin {
        Asset storage asset = assets[_assetId];
        require(!asset.verified, "Already verified");
        asset.verified = true;

        emit AssetVerified(_assetId, msg.sender);
    }

    /**
     * @notice Get details of a specific tokenized asset
     * @param _assetId Asset ID
     */
    function getAsset(uint256 _assetId) external view returns (Asset memory) {
        require(_assetId > 0 && _assetId <= assetCount, "Invalid asset ID");
        return assets[_assetId];
    }

    /**
     * @notice Get number of shares owned by an address for a specific asset
     * @param _assetId Asset ID
     * @param _owner Address of the shareholder
     */
    function getShareBalance(uint256 _assetId, address _owner) external view returns (uint256) {
        return ownership[_assetId][_owner];
    }
}
// 
End
// 
