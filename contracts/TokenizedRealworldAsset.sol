// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenizedRWA
 * @dev A framework for tokenizing real-world assets with compliance features, 
 * fractional ownership, and automated dividend distributions
 */
contract TokenizedRWA is ERC20, Ownable {
    // Asset details
    struct AssetDetails {
        string assetType;        // E.g., "Real Estate", "Commodity", "Art"
        string assetIdentifier;  // Legal identifier or description
        string location;         // Physical location if applicable
        uint256 totalValuation;  // Total valuation in USD (scaled by 10^18)
        bool isVerified;         // Verification status by designated authority
    }
    
    AssetDetails public assetDetails;
    
    // Compliance and investor tracking
    mapping(address => bool) public whitelisted;
    mapping(address => bool) public kycCompleted;
    uint256 public maxInvestors;
    uint256 public currentInvestorCount;
    
    // Dividend distribution
    uint256 public accumulatedDividends;
    mapping(address => uint256) public lastDividendClaimed;
    
    // Events
    event AssetVerificationUpdated(bool verificationStatus);
    event DividendDeposited(uint256 amount);
    event DividendClaimed(address investor, uint256 amount);
    event InvestorWhitelisted(address investor);
    event KycCompleted(address investor);
    
    /**
     * @dev Constructor that sets up the tokenized asset
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     * @param _assetType Type of the real-world asset
     * @param _assetIdentifier Legal identifier of the asset
     * @param _location Physical location of the asset
     * @param _totalValuation Total valuation of the asset in USD (scaled by 10^18)
     * @param _maxInvestors Maximum number of investors allowed
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _assetType,
        string memory _assetIdentifier,
        string memory _location,
        uint256 _totalValuation,
        uint256 _maxInvestors
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        assetDetails = AssetDetails({
            assetType: _assetType,
            assetIdentifier: _assetIdentifier,
            location: _location,
            totalValuation: _totalValuation,
            isVerified: false
        });
        
        maxInvestors = _maxInvestors;
        currentInvestorCount = 0;
    }
    
    /**
     * @dev Add an investor to the whitelist (KYC required before investment)
     * @param _investor Address of the investor to whitelist
     */
    function whitelistInvestor(address _investor) external onlyOwner {
        require(!whitelisted[_investor], "Investor already whitelisted");
        whitelisted[_investor] = true;
        emit InvestorWhitelisted(_investor);
    }
    
    /**
     * @dev Update KYC status for an investor
     * @param _investor Address of the investor
     * @param _status KYC status (true = completed)
     */
    function updateKycStatus(address _investor, bool _status) external onlyOwner {
        require(whitelisted[_investor], "Investor not whitelisted");
        
        // If this is a new investor, increment the counter
        if (_status && !kycCompleted[_investor]) {
            require(currentInvestorCount < maxInvestors, "Maximum investors reached");
            currentInvestorCount++;
        }
        
        kycCompleted[_investor] = _status;
        emit KycCompleted(_investor);
    }
    
    /**
     * @dev Issue tokens to an investor (partial ownership of the asset)
     * @param _investor Address of the investor
     * @param _amount Amount of tokens to mint
     */
    function issueTokens(address _investor, uint256 _amount) external onlyOwner {
        require(whitelisted[_investor], "Investor not whitelisted");
        require(kycCompleted[_investor], "KYC not completed");
        
        _mint(_investor, _amount);
    }
    
    /**
     * @dev Deposit dividends for distribution to token holders
     */
    function depositDividends() external payable onlyOwner {
        require(msg.value > 0, "Must deposit positive amount");
        
        accumulatedDividends += msg.value;
        emit DividendDeposited(msg.value);
    }
    
    /**
     * @dev Allow token holders to claim their dividends
     */
    function claimDividends() external {
        uint256 ownerBalance = balanceOf(msg.sender);
        require(ownerBalance > 0, "No tokens owned");
        
        uint256 totalSupplyValue = totalSupply();
        uint256 dividendShare = (ownerBalance * accumulatedDividends) / totalSupplyValue;
        
        // Reset claim tracking
        lastDividendClaimed[msg.sender] = accumulatedDividends;
        
        // Transfer dividends
        (bool success, ) = payable(msg.sender).call{value: dividendShare}("");
        require(success, "Dividend transfer failed");
        
        emit DividendClaimed(msg.sender, dividendShare);
    }
    
    /**
     * @dev Update the verification status of the asset
     * @param _status New verification status
     */
    function updateVerificationStatus(bool _status) external onlyOwner {
        assetDetails.isVerified = _status;
        emit AssetVerificationUpdated(_status);
    }
    
    /**
     * @dev Override transfer function to enforce compliance
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(whitelisted[to], "Recipient not whitelisted");
        require(kycCompleted[to], "Recipient KYC not completed");
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override transferFrom function to enforce compliance
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(whitelisted[to], "Recipient not whitelisted");
        require(kycCompleted[to], "Recipient KYC not completed");
        return super.transferFrom(from, to, amount);
    }
}
