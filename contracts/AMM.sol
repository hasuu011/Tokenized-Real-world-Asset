// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Automated Market Maker with Dynamic Fee Structure
 * @author Created for Core Testnet 2
 * @notice This contract implements an AMM with fees that adjust based on market volatility
 */
contract Project is Ownable {
    using Math for uint256;

    // Constants
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_FEE = 1e15; // 0.1%
    uint256 private constant MAX_FEE = 3e16; // 3%
    uint256 private constant VOLATILITY_PERIOD = 3600; // 1 hour

    // Token pair
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    // Pool data
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public kLast; // Last product of reserves
    
    // Fee structure
    uint256 public currentFee; // Current fee rate, scaled by PRECISION
    uint256 public volatilityAccumulator; // Measures recent price volatility
    
    // Price oracle
    AggregatorV3Interface public priceOracle;
    
    // Trading history
    struct PriceSnapshot {
        uint256 timestamp;
        uint256 price; // Price scaled by PRECISION
    }
    PriceSnapshot[] public priceHistory;
    
    // Events
    event Swap(address indexed sender, uint256 amountAIn, uint256 amountBIn, uint256 amountAOut, uint256 amountBOut);
    event AddLiquidity(address indexed provider, uint256 amountA, uint256 amountB);
    event RemoveLiquidity(address indexed provider, uint256 amountA, uint256 amountB);
    event FeeUpdated(uint256 newFee);
    
    /**
     * @notice Constructor to create a new AMM pool
     * @param _tokenA Address of the first token
     * @param _tokenB Address of the second token
     * @param _priceOracle Address of price oracle (Chainlink)
     */
    constructor(address _tokenA, address _tokenB, address _priceOracle) Ownable(msg.sender) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Identical tokens");
        
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        priceOracle = AggregatorV3Interface(_priceOracle);
        
        // Start with a base fee
        currentFee = 5e15; // 0.5%
    }
    
    /**
     * @notice Adds liquidity to the pool
     * @param amountADesired Amount of token A to add
     * @param amountBDesired Amount of token B to add
     * @param amountAMin Minimum amount of token A to add (slippage protection)
     * @param amountBMin Minimum amount of token B to add (slippage protection)
     * @return amountA Token A amount actually added
     * @return amountB Token B amount actually added
     */
    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external returns (uint256 amountA, uint256 amountB) {
        // Calculate optimal amounts based on existing ratio
        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 optimalAmountB = (amountADesired * reserveB) / reserveA;
            if (optimalAmountB <= amountBDesired) {
                require(optimalAmountB >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = optimalAmountB;
            } else {
                uint256 optimalAmountA = (amountBDesired * reserveA) / reserveB;
                require(optimalAmountA >= amountAMin, "Insufficient A amount");
                amountA = optimalAmountA;
                amountB = amountBDesired;
            }
        }
        
        // Transfer tokens to contract
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        
        // Update reserves
        reserveA += amountA;
        reserveB += amountB;
        kLast = reserveA * reserveB;
        
        emit AddLiquidity(msg.sender, amountA, amountB);
        
        // Update fee after significant pool changes
        _updateFee();
        
        return (amountA, amountB);
    }
    
    /**
     * @notice Executes a swap between token A and token B
     * @param amountAIn Amount of token A to swap in (0 if swapping B for A)
     * @param amountBIn Amount of token B to swap in (0 if swapping A for B)
     * @param amountAOutMin Minimum amount of token A to receive (slippage protection)
     * @param amountBOutMin Minimum amount of token B to receive (slippage protection)
     * @return amountAOut Amount of token A sent out
     * @return amountBOut Amount of token B sent out
     */
    function swap(
        uint256 amountAIn,
        uint256 amountBIn,
        uint256 amountAOutMin,
        uint256 amountBOutMin
    ) external returns (uint256 amountAOut, uint256 amountBOut) {
        require(amountAIn > 0 || amountBIn > 0, "Insufficient input amount");
        require(amountAIn == 0 || amountBIn == 0, "Cannot swap both tokens");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        
        // Calculate amounts out
        if (amountAIn > 0) {
            // Swap A for B
            uint256 amountAWithFee = amountAIn * (PRECISION - currentFee) / PRECISION;
            amountBOut = reserveB * amountAWithFee / (reserveA + amountAWithFee);
            require(amountBOut >= amountBOutMin, "Insufficient output amount");
            
            // Transfer tokens
            tokenA.transferFrom(msg.sender, address(this), amountAIn);
            tokenB.transfer(msg.sender, amountBOut);
            
            // Update reserves
            reserveA += amountAIn;
            reserveB -= amountBOut;
        } else {
            // Swap B for A
            uint256 amountBWithFee = amountBIn * (PRECISION - currentFee) / PRECISION;
            amountAOut = reserveA * amountBWithFee / (reserveB + amountBWithFee);
            require(amountAOut >= amountAOutMin, "Insufficient output amount");
            
            // Transfer tokens
            tokenB.transferFrom(msg.sender, address(this), amountBIn);
            tokenA.transfer(msg.sender, amountAOut);
            
            // Update reserves
            reserveB += amountBIn;
            reserveA -= amountAOut;
        }
        
        emit Swap(msg.sender, amountAIn, amountBIn, amountAOut, amountBOut);
        
        // Update price history and recalculate fee
        _recordPrice();
        _updateFee();
        
        return (amountAOut, amountBOut);
    }
    
    /**
     * @notice Updates the fee based on recent market volatility
     * @dev Called internally after swaps and liquidity changes
     */
    function _updateFee() internal {
        // Calculate volatility based on price history
        uint256 volatility = _calculateVolatility();
        
        // Update volatility accumulator with time decay
        uint256 timePassed = block.timestamp - (priceHistory.length > 0 ? priceHistory[priceHistory.length - 1].timestamp : block.timestamp);
        uint256 decayFactor = Math.min(timePassed, VOLATILITY_PERIOD) * PRECISION / VOLATILITY_PERIOD;
        
        volatilityAccumulator = (volatilityAccumulator * (PRECISION - decayFactor) / PRECISION) + volatility;
        
        // Dynamic fee calculation - higher volatility leads to higher fee
        uint256 volatilityFactor = Math.min(volatilityAccumulator, PRECISION);
        uint256 newFee = MIN_FEE + ((MAX_FEE - MIN_FEE) * volatilityFactor / PRECISION);
        
        if (currentFee != newFee) {
            currentFee = newFee;
            emit FeeUpdated(newFee);
        }
    }
    
    /**
     * @notice Records the current pool price in price history
     */
    function _recordPrice() internal {
        uint256 currentPrice = reserveB > 0 ? (reserveA * PRECISION) / reserveB : 0;
        priceHistory.push(PriceSnapshot({
            timestamp: block.timestamp,
            price: currentPrice
        }));
        
        // Keep history limited to avoid excessive gas costs
        if (priceHistory.length > 24) {
            // Remove oldest entry
            for (uint i = 0; i < priceHistory.length - 1; i++) {
                priceHistory[i] = priceHistory[i + 1];
            }
            priceHistory.pop();
        }
    }
    
    /**
     * @notice Calculates recent price volatility
     * @return Volatility measure from 0 to PRECISION
     */
    function _calculateVolatility() internal view returns (uint256) {
        if (priceHistory.length < 2) return 0;
        
        uint256 maxDeviation = 0;
        uint256 lastPrice = priceHistory[priceHistory.length - 1].price;
        uint256 avgPrice = lastPrice;
        
        // Calculate average price and find max deviation
        for (uint i = priceHistory.length - 2; i < priceHistory.length; i--) {
            if (i == type(uint).max) break; // Handle underflow
            
            uint256 timeDiff = priceHistory[i + 1].timestamp - priceHistory[i].timestamp;
            if (timeDiff > VOLATILITY_PERIOD) continue; // Only consider recent prices
            
            avgPrice = (avgPrice + priceHistory[i].price) / 2;
            
            uint256 deviation;
            if (priceHistory[i].price > lastPrice) {
                deviation = (priceHistory[i].price - lastPrice) * PRECISION / lastPrice;
            } else {
                deviation = (lastPrice - priceHistory[i].price) * PRECISION / lastPrice;
            }
            
            if (deviation > maxDeviation) {
                maxDeviation = deviation;
            }
        }
        
        // Normalize to 0-PRECISION range with a curve that emphasizes larger deviations
        return Math.min(maxDeviation * maxDeviation / PRECISION, PRECISION);
    }
    
    /**
     * @notice Returns the current pool price from A to B
     * @return Price scaled by PRECISION
     */
    function getCurrentPrice() external view returns (uint256) {
        require(reserveA > 0 && reserveB > 0, "Empty reserves");
        return (reserveB * PRECISION) / reserveA;
    }
}
