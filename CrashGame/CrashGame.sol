// SPDX-License-Identifier: None
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IHousePool{
    function Transfer(uint _amount) external;
    function SendRewardFunds() external payable;
    function maxProfit() external returns(uint256);
}

/// @title PulseRocket - Crash Game Contract
/// @notice Admin can create/start/end games, User can place bet and manual cashout.
/// @dev Dependent on HousePool Contract for funds.
contract PulseRocket is Ownable, Pausable {

    /// Status in which a game can be in at a given moment
    enum GameStatus { NONEXISTENT, CREATED, STARTED, ENDED }

    /**
     * @dev Contains the info about Bets placed
     * @param better          Address of the better.
     * @param betAmount       Amount of bet placed.
     * @param cashoutPoint    Multipler at which the better will cashout.
     * @param timestamp       Timestamp when whet is placed.
     * @param winAmount       Amount won by the better.
     * @param isManualCashout True if better does manual cashout.
     * @param winAmount       Amount won by the better.
     */
    struct Bet{
        address better;
        uint256 betAmount;
        uint256 cashoutPoint;
        uint256 timestamp;
        uint256 winAmount;
        bool isManualCashout;
        bool win;
    }

    struct Game {
        string  gameId;
        uint256 crashPoint;
        uint256 createGameTimestamp;
        uint256 startGameTimestamp;
        uint256 endGameTimestamp;
        mapping(address=>Bet) bets;
        address[] betters;
    }

    struct GameInfo {
        string  gameId;
        uint256 crashPoint;
        uint256 createGameTimestamp;
        uint256 startGameTimestamp;
        uint256 endGameTimestamp;
        GameStatus gameStatus;
        address[] betters;
    }

    mapping (string => Game) games;
    IHousePool public housepool;
    address public recipient;
    uint256 public recipientShare = 5000;
    uint256 constant DECIMALS = 10000;

    mapping (address => bool) public isAdmin;

    event GameCreated(string indexed gameId, uint256 createGameTimestamp);
    event GameStarted(string indexed gameId, uint256 startGameTimestamp);
    event GameEnded(string indexed gameId, uint256 endGameTimestamp, uint256 crashPoint);

    event BetPlaced(string indexed gameId, address indexed better, uint256 betAmount, uint256 autoCashoutPoint);
    event ManualCashout(string indexed gameId, address indexed better, uint256 manualCashoutPoint);

    event AdminUpdated(address admin, bool value);
    event RecipientShareUpdated(address admin, uint oldShare, uint newShare);

    constructor(IHousePool _housepool, address _recipient) Ownable() {
        require(address(_housepool)!=address(0), "Invalid housepool address.");
        require(address(_recipient)!=address(0), "Invalid recipient address.");

        housepool = _housepool;
        recipient = _recipient;
        isAdmin[_msgSender()] = true;
    }

    function updateAdmin(address admin, bool value) external onlyOwner {
        isAdmin[admin] = value;
        emit AdminUpdated(admin, value);
    }

    function createGame(string calldata gameId) external onlyAdmin whenNotPaused {
        require(idMatch(games[gameId].gameId,""), "Game already exists");

        uint256 currentTimestamp = block.timestamp;

        games[gameId].gameId = gameId;
        games[gameId].createGameTimestamp = currentTimestamp;

        emit GameCreated(gameId, currentTimestamp);
    }

    function startGame(string calldata gameId) external onlyAdmin isValidGame(gameId) whenNotPaused {
        require(games[gameId].startGameTimestamp == 0, "Game already started.");

        uint256 currentTimestamp = block.timestamp;

        games[gameId].startGameTimestamp = currentTimestamp;

        emit GameStarted(gameId, currentTimestamp);
    }

    function placeBet(string calldata gameId, uint256 autoCashoutPoint) external payable isValidBet(msg.value, autoCashoutPoint) isValidGame(gameId) whenNotPaused {
        uint256 betAmount = msg.value;
        require(games[gameId].startGameTimestamp == 0, "Game has started.");
        require(games[gameId].endGameTimestamp == 0, "Game already ended.");
        require(games[gameId].bets[_msgSender()].cashoutPoint == 0, "Bet already placed.");
        require(betAmount > 0, "Invalid bet amount.");
        require(autoCashoutPoint > 101, "Invalid cashout point.");

        games[gameId].bets[_msgSender()] = Bet(_msgSender(), betAmount, autoCashoutPoint, block.timestamp, 0, false, false);
        games[gameId].betters.push(_msgSender());
        emit BetPlaced(gameId, _msgSender(), betAmount, autoCashoutPoint);
    }

    function manualCashout(string calldata gameId, uint256 manualCashoutPoint) whenNotPaused external {
        require(games[gameId].startGameTimestamp!=0,"Game not started.");
        require(games[gameId].endGameTimestamp==0,"Game already ended.");
        require(games[gameId].bets[_msgSender()].cashoutPoint!=0,"Bet not placed.");
        require(games[gameId].bets[_msgSender()].cashoutPoint>manualCashoutPoint,"Invalid cashout amount.");

        games[gameId].bets[_msgSender()].cashoutPoint = manualCashoutPoint;
        games[gameId].bets[_msgSender()].isManualCashout = true;
        emit ManualCashout(gameId, _msgSender(), manualCashoutPoint);
    }

    function endGame(string calldata gameId, uint256 crashPoint) external payable onlyAdmin whenNotPaused {
        require(games[gameId].startGameTimestamp!=0, "Game not started.");

        uint256 currentTimestamp = block.timestamp;
        uint256 housepoolDepositAmount=0;
        uint256 housepoolWithdrawAmount=0;
        uint256 recipientAmount=0;

        games[gameId].endGameTimestamp = currentTimestamp;
        games[gameId].crashPoint = crashPoint;

        address[] memory betters=games[gameId].betters;

        for(uint256 i=0;i<betters.length;i++){
            if(games[gameId].bets[betters[i]].cashoutPoint<=crashPoint){
                games[gameId].bets[betters[i]].win=true;
                ( uint housepoolAmt, uint betterAmt )=returnProfit(games[gameId].bets[betters[i]]);
                housepoolWithdrawAmount += housepoolAmt;
                games[gameId].bets[betters[i]].winAmount = betterAmt;
            }
            else{
                games[gameId].bets[betters[i]].win=false;
                ( uint housepoolAmt, uint recipientAmt )=returnLoss(games[gameId].bets[betters[i]]);
                housepoolDepositAmount += housepoolAmt;
                recipientAmount += recipientAmt;
            }
        }
        
        if(housepoolDepositAmount>0)
            housepool.SendRewardFunds{value:housepoolDepositAmount}();

        if(housepoolWithdrawAmount>0)
            housepool.Transfer(housepoolWithdrawAmount);

        if(recipientAmount>0)
            payable(recipient).transfer(recipientAmount);

        transferToUser(gameId);
        emit GameEnded(gameId, currentTimestamp, crashPoint);
    }

    function returnProfit(Bet memory bet) internal pure returns(uint,uint) {
        uint256 returnAmt = getReturnAmount(bet.betAmount,bet.cashoutPoint);
        return (returnAmt-bet.betAmount,returnAmt);
    }

    function returnLoss(Bet memory bet) internal view returns(uint,uint) {
        uint256 recipientAmount = bet.betAmount * recipientShare / DECIMALS;
        return (bet.betAmount-recipientAmount, recipientAmount);
    }

    function transferToUser(string memory gameId) internal returns(bool) {
        address[] memory betters=games[gameId].betters;
        for(uint256 i=0;i<betters.length;i++){
            uint256 amount = games[gameId].bets[betters[i]].winAmount;
            if(amount > 0)
                payable(betters[i]).transfer(amount);
        }
        return true;
    }

    function getReturnAmount(uint256 betAmount, uint256 cashoutPoint) internal pure returns(uint256) {
        return betAmount * cashoutPoint / 100;
    }

    function getBetInfo(string calldata gameId, address better) external view returns(Bet memory){
        return games[gameId].bets[better];
    }

    function getGameStatus(string calldata gameId) public view returns(GameStatus){
        if(games[gameId].createGameTimestamp==0){
            return GameStatus.NONEXISTENT;
        }
        if(games[gameId].startGameTimestamp==0){
            return GameStatus.CREATED;
        }
        if(games[gameId].endGameTimestamp==0){
            return GameStatus.STARTED;
        }
        return GameStatus.ENDED;
    }

    function getGameInfo(string calldata gameId) external view returns(GameInfo memory){
        return GameInfo(games[gameId].gameId,
            games[gameId].crashPoint,
            games[gameId].createGameTimestamp,
            games[gameId].startGameTimestamp,
            games[gameId].endGameTimestamp,
            getGameStatus(gameId),
            games[gameId].betters);
    }

    modifier isValidBet(uint256 betAmount, uint256 cashoutPoint){
        require(getReturnAmount(betAmount,cashoutPoint)<=housepool.maxProfit(),"Invalid Bet.");
        _;
    }

    function idMatch(string memory id1, string memory id2) internal pure returns (bool){
        return keccak256(abi.encodePacked((id1))) == keccak256(abi.encodePacked(id2));
    }

    /**
     * @dev Admin updates the recipient share.
     * @param newShare The new recipient share
     */
    function updateRecipientShare(uint newShare) external onlyAdmin {
        emit RecipientShareUpdated(_msgSender(), recipientShare, newShare);
        recipientShare = newShare;
    }

    receive() external payable {
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyAdmin() {
        require(isAdmin[_msgSender()], "Caller is not the admin");
        _;
    }

    /**
     * @dev Throws if Invalid Game ID is passed.
     */
    modifier isValidGame(string memory gameId) {
        require(idMatch(games[gameId].gameId, gameId), "Invalid Game Id.");
        _;
    }

    /**
     * @dev Pause the contract. Stops the pausable functions from being accessed.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpause the contract. Allows the pausable functions to be accessed.
     */
    function unpause() external onlyAdmin {
        _unpause();
    }
}