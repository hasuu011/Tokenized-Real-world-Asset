// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title RealWorldAssetToken (RWA)
 * @notice Tokenizing real-world assets as NFTs with verification controls.
 * @dev Uses a lightweight custom ERC721 implementation (no external imports).
 */
contract RealWorldAssetToken {

    // ========== ERC721 BASE IMPLEMENTATION ==========
    string public name = "RealWorldAsset";
    string public symbol = "RWA";

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // ========== CUSTOM REAL-WORLD ASSET LOGIC ==========
    address public admin;
    uint256 public tokenCounter;

    struct AssetData {
        string metadataURI;  // IPFS or off-chain docs
        bool verified;       // verification status
        uint256 appraisalValue;
        address[] ownershipHistory;
    }

    mapping(uint256 => AssetData) public assetDetails;

    event AssetMinted(uint256 indexed tokenId, address indexed owner, string metadataURI);
    event AssetVerified(uint256 indexed tokenId, uint256 appraisalValue);
    event OwnershipRecorded(uint256 indexed tokenId, address indexed owner);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RWA: NOT_ADMIN");
        _;
    }

    modifier exists(uint256 tokenId) {
        require(_owners[tokenId] != address(0), "RWA: NON_EXISTENT_TOKEN");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ========== MINTING ==========

    /// @notice Mint NFT representing a real-world asset (admin or asset issuer)
    function mint(address to, string calldata metadataURI) external onlyAdmin returns (uint256) {
        require(to != address(0), "RWA: INVALID_ADDRESS");

        tokenCounter++;
        uint256 tokenId = tokenCounter;

        _owners[tokenId] = to;
        _balances[to] += 1;

        assetDetails[tokenId].metadataURI = metadataURI;
        assetDetails[tokenId].ownershipHistory.push(to);

        emit Transfer(address(0), to, tokenId);
        emit AssetMinted(tokenId, to, metadataURI);

        return tokenId;
    }

    // ========== VERIFICATION OF ASSET ==========

    /// @notice Admin verifies & assigns appraisal value to an asset
    function verifyAsset(uint256 tokenId, uint256 appraisalValue) 
        external 
        onlyAdmin 
        exists(tokenId) 
    {
        AssetData storage asset = assetDetails[tokenId];
        require(!asset.verified, "RWA: ALREADY_VERIFIED");
        require(appraisalValue > 0, "RWA: INVALID_APPRAISAL_VALUE");

        asset.verified = true;
        asset.appraisalValue = appraisalValue;
        emit AssetVerified(tokenId, appraisalValue);
    }

    // ========== TRANSFER LOGIC WITH VERIFICATION RESTRICTION ==========

    function transferFrom(address from, address to, uint256 tokenId) public exists(tokenId) {
        require(assetDetails[tokenId].verified, "RWA: TRANSFER_BLOCKED_UNTIL_VERIFIED");
        require(to != address(0), "RWA: ZERO_ADDRESS");
        require(_owners[tokenId] == from, "RWA: NOT_OWNER");
        require(
            msg.sender == from ||
            msg.sender == _tokenApprovals[tokenId] ||
            _operatorApprovals[from][msg.sender],
            "RWA: NOT_AUTHORIZED"
        );

        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        assetDetails[tokenId].ownershipHistory.push(to);
        emit Transfer(from, to, tokenId);
        emit OwnershipRecorded(tokenId, to);
    }

    // Safe transfer (simple version)
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
        require(_checkOnERC721Received(), "RWA: RECEIVER_NOT_IMPLEMENTED");
    }

    function _checkOnERC721Received() private pure returns (bool) {
        return true;
    }

    // ========== ERC721 VIEW FUNCTIONS ==========

    function ownerOf(uint256 tokenId) public view exists(tokenId) returns (address) {
        return _owners[tokenId];
    }

    function balanceOf(address user) public view returns (uint256) {
        require(user != address(0), "RWA: ZERO_ADDRESS");
        return _balances[user];
    }

    function tokenURI(uint256 tokenId) external view exists(tokenId) returns (string memory) {
        return assetDetails[tokenId].metadataURI;
    }

    function getOwnershipHistory(uint256 tokenId) external view exists(tokenId) returns (address[] memory) {
        return assetDetails[tokenId].ownershipHistory;
    }

    // ========== APPROVALS ==========

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "RWA: ONLY_OWNER");

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) 
        external 
        view 
        returns (bool) 
    {
        return _operatorApprovals[owner][operator];
    }

    // ========== ADMIN CONTROL ==========

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "RWA: ZERO_ADMIN");
        admin = newAdmin;
    }
}
