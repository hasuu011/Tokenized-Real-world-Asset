// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Tokenized Real World Asset (RWA) Contract
 * @dev A smart contract for tokenizing real-world assets as NFTs
 * Each token represents ownership or fractional ownership of a real-world asset
 */
contract Project is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Counter for token IDs
    Counters.Counter private _tokenIds;
    
    // Struct to store asset information
    struct Asset {
        string name;
        string description;
        string location;
        uint256 totalValue;
        uint256 shares;
        uint256 pricePerShare;
        bool isActive;
        address creator;
        string metadataURI;
    }
    
    // Mapping from token ID to asset information
    mapping(uint256 => Asset) public assets;
    
    // Mapping from token ID to number of shares owned by address
    mapping(uint256 => mapping(address => uint256)) public shareholdings;
    
    // Mapping from token ID to total shares sold
    mapping(uint256 => uint256) public sharesSold;
    
    // Platform fee percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFee = 250;
    
    // Events
    event AssetTokenized(
        uint256 indexed tokenId,
        string name,
        uint256 totalValue,
        uint256 shares,
        address indexed creator
    );
    
    event SharesPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 shares,
        uint256 totalCost
    );
    
    event AssetUpdated(
        uint256 indexed tokenId,
        string newMetadataURI
    );
    
    constructor() ERC721("Tokenized Real World Assets", "TRWA") Ownable(msg.sender) {}
    
    /**
     * @dev Core Function 1: Tokenize a real-world asset
     * @param _name Name of the asset
     * @param _description Description of the asset
     * @param _location Location of the asset
     * @param _totalValue Total value of the asset in wei
     * @param _shares Total number of shares for fractional ownership
     * @param _metadataURI URI pointing to asset metadata (images, documents, etc.)
     */
    function tokenizeAsset(
        string memory _name,
        string memory _description,
        string memory _location,
        uint256 _totalValue,
        uint256 _shares,
        string memory _metadataURI
    ) external returns (uint256) {
        require(_totalValue > 0, "Total value must be greater than 0");
        require(_shares > 0, "Shares must be greater than 0");
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        // Calculate price per share
        uint256 pricePerShare = _totalValue / _shares;
        
        // Create asset struct
        assets[newTokenId] = Asset({
            name: _name,
            description: _description,
            location: _location,
            totalValue: _totalValue,
            shares: _shares,
            pricePerShare: pricePerShare,
            isActive: true,
            creator: msg.sender,
            metadataURI: _metadataURI
        });
        
        // Mint NFT to the creator
        _safeMint(msg.sender, newTokenId);
        
        emit AssetTokenized(newTokenId, _name, _totalValue, _shares, msg.sender);
        
        return newTokenId;
    }
    
    /**
     * @dev Core Function 2: Purchase fractional shares of a tokenized asset
     * @param _tokenId ID of the tokenized asset
     * @param _sharesToBuy Number of shares to purchase
     */
    function purchaseShares(uint256 _tokenId, uint256 _sharesToBuy) 
        external 
        payable 
        nonReentrant 
    {
        require(_ownerOf(_tokenId) != address(0), "Token does not exist");
        require(assets[_tokenId].isActive, "Asset is not active");
        require(_sharesToBuy > 0, "Must purchase at least 1 share");
        
        Asset storage asset = assets[_tokenId];
        
        // Check if enough shares are available
        uint256 availableShares = asset.shares - sharesSold[_tokenId];
        require(_sharesToBuy <= availableShares, "Not enough shares available");
        
        // Calculate total cost including platform fee
        uint256 baseCost = _sharesToBuy * asset.pricePerShare;
        uint256 fee = (baseCost * platformFee) / 10000;
        uint256 totalCost = baseCost + fee;
        
        require(msg.value >= totalCost, "Insufficient payment");
        
        // Update shareholdings
        shareholdings[_tokenId][msg.sender] += _sharesToBuy;
        sharesSold[_tokenId] += _sharesToBuy;
        
        // Transfer payment to asset creator (minus platform fee)
        payable(asset.creator).transfer(baseCost);
        
        // Transfer platform fee to contract owner
        if (fee > 0) {
            payable(owner()).transfer(fee);
        }
        
        // Refund excess payment
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
        
        emit SharesPurchased(_tokenId, msg.sender, _sharesToBuy, totalCost);
    }
    
    /**
     * @dev Core Function 3: Update asset metadata and information
     * @param _tokenId ID of the tokenized asset
     * @param _newMetadataURI New metadata URI
     */
    function updateAssetMetadata(uint256 _tokenId, string memory _newMetadataURI) 
        external 
    {
        require(_ownerOf(_tokenId) != address(0), "Token does not exist");
        require(
            msg.sender == assets[_tokenId].creator || msg.sender == owner(),
            "Only asset creator or contract owner can update metadata"
        );
        
        assets[_tokenId].metadataURI = _newMetadataURI;
        
        emit AssetUpdated(_tokenId, _newMetadataURI);
    }
    
    /**
     * @dev Get basic asset information
     * @param _tokenId ID of the tokenized asset
     */
    function getAssetBasicInfo(uint256 _tokenId) 
        external 
        view 
        returns (
            string memory name,
            string memory description,
            string memory location,
            address creator
        ) 
    {
        require(_ownerOf(_tokenId) != address(0), "Token does not exist");
        Asset storage asset = assets[_tokenId];
        
        return (
            asset.name,
            asset.description,
            asset.location,
            asset.creator
        );
    }
    
    /**
     * @dev Get asset financial information
     * @param _tokenId ID of the tokenized asset
     */
    function getAssetFinancialInfo(uint256 _tokenId) 
        external 
        view 
        returns (
            uint256 totalValue,
            uint256 shares,
            uint256 pricePerShare,
            uint256 soldShares,
            bool isActive
        ) 
    {
        require(_ownerOf(_tokenId) != address(0), "Token does not exist");
        Asset storage asset = assets[_tokenId];
        
        return (
            asset.totalValue,
            asset.shares,
            asset.pricePerShare,
            sharesSold[_tokenId],
            asset.isActive
        );
    }
    
    /**
     * @dev Get shareholding for a specific address and token
     * @param _tokenId ID of the tokenized asset
     * @param _holder Address of the shareholder
     */
    function getShareholding(uint256 _tokenId, address _holder) 
        external 
        view 
        returns (uint256) 
    {
        return shareholdings[_tokenId][_holder];
    }
    
    /**
     * @dev Override tokenURI to return asset metadata
     * @param _tokenId ID of the token
     */
    function tokenURI(uint256 _tokenId) 
        public 
        view 
        override 
        returns (string memory) 
    {
        require(_ownerOf(_tokenId) != address(0), "Token does not exist");
        return assets[_tokenId].metadataURI;
    }
    
    /**
     * @dev Set platform fee (only owner)
     * @param _newFee New platform fee in basis points
     */
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Platform fee cannot exceed 10%");
        platformFee = _newFee;
    }
    
    /**
     * @dev Toggle asset active status (only asset creator or owner)
     * @param _tokenId ID of the tokenized asset
     */
    function toggleAssetStatus(uint256 _tokenId) external {
        require(_ownerOf(_tokenId) != address(0), "Token does not exist");
        require(
            msg.sender == assets[_tokenId].creator || msg.sender == owner(),
            "Only asset creator or contract owner can toggle status"
        );
        
        assets[_tokenId].isActive = !assets[_tokenId].isActive;
    }
    
    /**
     * @dev Get total number of tokenized assets
     */
    function getTotalAssets() external view returns (uint256) {
        return _tokenIds.current();
    }
    
    /**
     * @dev Emergency withdraw function (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
