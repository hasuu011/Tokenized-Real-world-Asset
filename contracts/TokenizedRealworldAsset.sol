// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
/*
 * @title Tokenized Real World Asset (RWA) Contract
 * @dev A smart contract for tokenizing real-world assets as NFTs
 * Each token represents ownership or fractional ownership of a real-world asset
 */
contract Project is ERC721, Ownable

    // Mapping tokenId to Asset
    mapping(uint256 => Asset) public assets;

    // Mapping tokenId => (holder=> shares owned)
    mapping(uint256 => mapping(address => uint256)) public shareholdings;

    // Number of shares sold per tokenId
    mapping(uint256 => uint256) public sharesSold;

    // Platform fee in basis points (parts per 10,000), e.g. 250 = 2.5%
    uint256 public platformFee = 250;

    // List of all token IDs minted
    uint256[] private tokenList;

    // Events
    event AssetTokenized(uint256 indexed tokenId, string name, uint256 totalValue, uint256 shares, address indexed creator);
    event SharesPurchased(uint256 indexed tokenId, address indexed buyer, uint256 shares, uint256 totalCost);
    event AssetUpdated(uint256 indexed tokenId, string newMetadataURI);
    event SharesTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 shares);
    event AssetBurned(uint256 indexed tokenId);

    constructor() ERC721("Tokenized Real World Assets", "TRWA") {}

    function tokenizeAsset(
        string memory _name,
        string memory _description,
        string memory _location,
        uint256 _totalValue,
        uint256 _shares,
        string memory _metadataURI
    ) external returns (uint256) {
        require(_totalValue > 0 && _shares > 0, "Value and shares must be > 0");
        require(bytes(_name).length > 0, "Name required");

        _tokenIds.increment();
    
  
    }

    function purchaseShares(uint256 _tokenId, uint256 _sharesToBuy) external payable nonReentrant {
        require(_exists(_tokenId), "Token doesn't exist");
        require(assets[_tokenId].isActive, "Asset inactive");
        require(_sharesToBuy > 0, "Shares must be > 0");

  
        uint256 baseCost = _sharesToBuy * asset.pricePerShare;
        uint256 fee = (baseCost * platformFee) / 10000;
        uint256 totalCost = baseCost + fee;

        require(msg.value >= totalCost, "Insufficient payment");

        shareholdings[_tokenId][msg.sender] += _sharesToBuy;
        sharesSold[_tokenId] += _sharesToBuy;

        payable(asset.creator).transfer(baseCost);

        if (fee > 0) {
            payable(owner()).transfer(fee);
        }

        // Refund excess payment if any
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit SharesPurchased(_tokenId, msg.sender, _sharesToBuy, totalCost);
    }

    function updateAssetMetadata(uint256 _tokenId, string memory _newMetadataURI) external {
        require(_exists(_tokenId), "Token doesn't exist");
        require(msg.sender == assets[_tokenId].creator || msg.sender == owner(), "Unauthorized");

        assets[_tokenId].metadataURI = _newMetadataURI;
        emit AssetUpdated(_tokenId, _newMetadataURI);
    }

    function getAssetBasicInfo(uint256 _tokenId) external view returns (string memory, string memory, string memory, address) {
        require(_exists(_tokenId), "Token doesn't exist");
        Asset storage asset = assets[_tokenId];
        return (asset.name, asset.description, asset.location, asset.creator);
    }

    function getAssetFinancialInfo(uint256 _tokenId) external view returns (uint256, uint256, uint256, uint256, bool) {
        require(_exists(_tokenId), "Token doesn't exist");
        Asset storage asset = assets[_tokenId];
        return (asset.totalValue, asset.shares, asset.pricePerShare, sharesSold[_tokenId], asset.isActive);
    }

    function getShareholding(uint256 _tokenId, address _holder) external view returns (uint256) {
        return shareholdings[_tokenId][_holder];
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token doesn't exist");
        return assets[_tokenId].metadataURI;
    }

    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee max 10%");
        platformFee = _newFee;
    }

    function toggleAssetStatus(uint256 _tokenId) external {
        require(_exists(_tokenId), "Token doesn't exist");
        require(msg.sender == assets[_tokenId].creator || msg.sender == owner(), "Unauthorized");

        assets[_tokenId].isActive = !assets[_tokenId].isActive;
    }

    function getTotalAssets() external view returns (uint256) {
        return _tokenIds.current();
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function transferShares(uint256 _tokenId, address _to, uint256 _shares) external {
        require(_shares > 0, "Must transfer > 0");
        require(shareholdings[_tokenId][msg.sender] >= _shares, "Insufficient shares");

        shareholdings[_tokenId][msg.sender] -= _shares;
        shareholdings[_tokenId][_to] += _shares;

        emit SharesTransferred(_tokenId, msg.sender, _to, _shares);
    }

    function burnAsset(uint256 _tokenId) external {
        require(_exists(_tokenId), "Token doesn't exist");
        require(msg.sender == assets[_tokenId].creator || msg.sender == owner(), "Unauthorized");

        _burn(_tokenId);
        delete assets[_tokenId];
        delete sharesSold[_tokenId];

        emit AssetBurned(_tokenId);
    }

    function getAllAssets() external view returns (uint256[] memory) {
        return tokenList;
    }

    function getMyShareholdings(address user) external view returns (uint256[] memory, uint256[] memory) {
        uint256 count = _tokenIds.current();
        uint256[] memory ids = new uint256[](count);
        uint256[] memory shares = new uint256[](count);

        for (uint256 i = 1; i <= count; i++) {
            ids[i - 1] = i;
            shares[i - 1] = shareholdings[i][user];
        }
        return (ids, shares);
    }
}
