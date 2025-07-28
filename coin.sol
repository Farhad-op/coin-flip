// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CoinFlipGame {
    address public owner;
    uint256 public houseBalance;
    uint256 public minimumBet = 0.01 ether;
    uint256 public maximumBet = 1 ether;
    
    struct Game {
        address player;
        uint256 betAmount;
        uint256 choice; // 0 for heads, 1 for tails
        bool isActive;
        uint256 timestamp;
    }
    
    mapping(address => Game) public activeGames;
    mapping(address => uint256) public playerWinnings;
    
    event BetPlaced(address indexed player, uint256 amount, uint256 choice);
    event GameResult(address indexed player, bool won, uint256 result, uint256 payout);
    event Withdrawal(address indexed player, uint256 amount);
    event HouseFunded(uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validBet() {
        require(msg.value >= minimumBet && msg.value <= maximumBet, "Bet amount out of range");
        require(houseBalance >= msg.value * 2, "House doesn't have enough funds");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // Function 1: Place a bet (0 for heads, 1 for tails)
    function placeBet(uint256 _choice) external payable validBet {
        require(_choice == 0 || _choice == 1, "Choice must be 0 (heads) or 1 (tails)");
        require(!activeGames[msg.sender].isActive, "You already have an active game");
        
        activeGames[msg.sender] = Game({
            player: msg.sender,
            betAmount: msg.value,
            choice: _choice,
            isActive: true,
            timestamp: block.timestamp
        });
        
        emit BetPlaced(msg.sender, msg.value, _choice);
    }
    
    // Function 2: Flip coin and determine winner
    function flipCoin() external {
        Game storage game = activeGames[msg.sender];
        require(game.isActive, "No active game found");
        require(game.player == msg.sender, "Not your game");
        
        // Generate pseudo-random result (0 or 1)
        uint256 result = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            game.betAmount
        ))) % 2;
        
        bool won = (result == game.choice);
        uint256 payout = 0;
        
        if (won) {
            payout = game.betAmount * 2; // Double the bet amount
            playerWinnings[msg.sender] += payout;
            houseBalance -= game.betAmount; // House loses the bet amount
        } else {
            houseBalance += game.betAmount; // House wins the bet amount
        }
        
        // Mark game as inactive
        game.isActive = false;
        
        emit GameResult(msg.sender, won, result, payout);
    }
    
    // Function 3: Withdraw winnings
    function withdrawWinnings() external {
        uint256 amount = playerWinnings[msg.sender];
        require(amount > 0, "No winnings to withdraw");
        require(address(this).balance >= amount, "Contract doesn't have enough balance");
        
        playerWinnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit Withdrawal(msg.sender, amount);
    }
    
    // Function 4: Fund the house (only owner)
    function fundHouse() external payable onlyOwner {
        houseBalance += msg.value;
        emit HouseFunded(msg.value);
    }
    
    // Function 5: Withdraw house funds (only owner)
    function withdrawHouseFunds(uint256 _amount) external onlyOwner {
        require(_amount <= houseBalance, "Amount exceeds house balance");
        require(address(this).balance >= _amount, "Contract doesn't have enough balance");
        
        houseBalance -= _amount;
        payable(owner).transfer(_amount);
    }
    
    // Function 6: Get game info for a player
    function getGameInfo(address _player) external view returns (
        uint256 betAmount,
        uint256 choice,
        bool isActive,
        uint256 timestamp,
        uint256 winnings
    ) {
        Game memory game = activeGames[_player];
        return (
            game.betAmount,
            game.choice,
            game.isActive,
            game.timestamp,
            playerWinnings[_player]
        );
    }
    
    // Get contract balance
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
