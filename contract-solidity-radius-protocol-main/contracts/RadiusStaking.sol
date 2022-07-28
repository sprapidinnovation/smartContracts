// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface RadiusCoin {
    function reflectionFromToken(uint256 _amount, bool _deductFee)
        external
        view
        returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function tokenFromReflection(uint256 _amount)
        external
        view
        returns (uint256);

    function balanceOf(address _address) external view returns (uint256);

    function mint(uint256 _amount) external;

    function setTimeDurationForExtraPenaltyTax(uint _duration) external;

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferOwnership(address _owner) external;

    function excludeAccount(address _address) external;

    function includeAccount(address _address) external;

    function setReservePool(address _address) external;

    function setLiquidityPoolAddress(address _address, bool _add) external;

    function lockedTill(address _address) external view returns (uint256);

    function lock(address _address, uint256 _days) external;

    function unlock(address _address) external;

    function setLimit(
        address _address,
        uint256 _period,
        uint256 _rule
    ) external;

    function removeLimit(address _address) external;

    function excludeFromFee(address account) external;

    function includeFromFee(address account) external;

    function setReflectionFee(uint256 fee) external;

    function setLiquidityFee(uint256 fee) external;

    function setCharityFee(uint256 fee) external;

    function setBurnPercent(uint256 fee) external;

    function setMarketingFee(uint256 fee) external;

    function setEarlySellFee(uint256 fee) external;

    function setCharityAddress(address _address) external;

    function setRouterAddress(address _address) external;

    function setLiquidityManager(address _address) external;

    function setMarketingAddress(address _Address) external;

    function PrepareForPreSale() external;

    function afterPreSale() external;

    function withdraw() external;

    function setMinter(address _minter) external;

    function removeMinter(address _minter) external;

    function setHaltPercentages(uint256[3] memory _percentages) external;

    function setHaltPeriods(uint256[3] memory _periods) external;

    function setExclusionFromHalt(address _account, bool _exclude) external;

    function resetHaltSequence() external;

    function setLastThresholdPrice(uint _lastThresholdPrice) external;

    function toggleLockTransfer() external;

    function executePriceDeclineHalt(
        uint256 currentPrice,
        uint256 referencePrice
    ) external returns (bool);
}

contract RadiusStaking is Ownable {
    using SafeMath for uint256;

    struct Stake {
        uint256 tAmount;
        uint256 rAmount;
        uint256 time;
        uint256 period;
        uint256 rate;
        bool isActive;
    }

    mapping(uint256 => uint256) public interestRate;
    mapping(address => Stake[]) public stakes;

    RadiusCoin private token;

    uint256 private constant DENOMINATOR = 10000;
    uint256 public rewardsDistributed;
    uint256 public rewardsPending;

    event TokenStaked(
        address account,
        uint256 stakeId,
        uint256 tokenAmount,
        uint256 timestamp,
        uint256 period
    );
    event TokenUnstaked(
        address account,
        uint256 tokenAmount,
        uint256 interest,
        uint256 timestamp
    );
    event StakingPeriodUpdated(uint256 period, uint256 rate);

    event RuleChanged(uint256 newRule);
    event ThresholdChanged(uint256 newThreshold);
    event RestrictionDurationChanged(uint256 newRestrictionDuration);
    event ForceEopToggle(bool forceEop);

    modifier isValidStakeId(address _address, uint256 _id) {
        require(_id < stakes[_address].length, "Id is not valid");
        _;
    }

    constructor(address _address) {
        token = RadiusCoin(_address);

        interestRate[6] = 750;
        interestRate[12] = 2500;
    }

    /// @notice used to stake Radius Coin
    /// @param _amount amount of Radius Coin to stake
    /// @param _period number of days or months?? to stake for
    function stakeToken(uint256 _amount, uint256 _period) external {
        require(interestRate[_period] != 0, "Staking period not valid");

        uint256 rAmount = token.reflectionFromToken(_amount, false);
        token.transferFrom(msg.sender, address(this), _amount);

        uint256 stakeId = stakes[msg.sender].length;
        rewardsPending = rewardsPending.add(
            _amount.mul(interestRate[_period]).div(DENOMINATOR)
        );
        stakes[msg.sender].push(
            Stake(
                _amount,
                rAmount,
                block.timestamp,
                _period,
                interestRate[_period],
                true
            )
        );

        emit TokenStaked(
            msg.sender,
            stakeId,
            _amount,
            block.timestamp,
            _period
        );
    }

    /// @notice used to unstake Radius Coin
    /// @param _id index of the stake to unstake from
    function unstakeToken(uint256 _id)
        external
        isValidStakeId(msg.sender, _id)
    {
        require(
            timeLeftToUnstake(msg.sender, _id) == 0,
            "Stake duration not over"
        );
        require(stakes[msg.sender][_id].isActive, "Tokens already unstaked");

        Stake storage stake = stakes[msg.sender][_id];

        uint256 tAmount = token.tokenFromReflection(stake.rAmount);
        uint256 interest = stakingReward(msg.sender, _id);

        uint256 balance = token.balanceOf(address(this));
        if (balance < tAmount.add(interest)) {
            token.mint(tAmount.add(interest).sub(balance));
        }

        stake.isActive = false;
        rewardsPending = rewardsPending.sub(interest);
        rewardsDistributed = rewardsDistributed.add(interest);
        token.transfer(msg.sender, tAmount.add(interest));

        emit TokenUnstaked(msg.sender, tAmount, interest, block.timestamp);
    }

    /// @notice used to get the stake information of the staker
    /// @param _address the address of the staker
    /// @param _id the index of the stake
    function getStake(address _address, uint256 _id)
        external
        view
        isValidStakeId(_address, _id)
        returns (Stake memory)
    {
        return stakes[_address][_id];
    }

    /// @notice used to get the information of all of the stakes
    /// @param _address the address of the staker
    function getAllStakes(address _address)
        external
        view
        returns (Stake[] memory)
    {
        return stakes[_address];
    }

    /// @notice used to fetch the reflection earned by the staker
    /// @param _address the address of the staker
    /// @param _id the index of the stake
    function reflectionReceived(address _address, uint256 _id)
        external
        view
        isValidStakeId(_address, _id)
        returns (uint256)
    {
        require(stakes[_address][_id].isActive, "Tokens already unstaked");
        Stake memory stake = stakes[_address][_id];
        return (token.tokenFromReflection(stake.rAmount) - stake.tAmount);
    }

    /// @notice used to fetch the time left after which staker can unstake
    /// @param _address the address of the staker
    /// @param _id the index of the stake
    function timeLeftToUnstake(address _address, uint256 _id)
        public
        view
        isValidStakeId(_address, _id)
        returns (uint256)
    {
        require(stakes[_address][_id].isActive, "Tokens already unstaked");
        Stake memory stake = stakes[_address][_id];
        uint256 unstakeTime = stake.time + stake.period * 30 days;

        return (
            block.timestamp < unstakeTime ? unstakeTime - block.timestamp : 0
        );
    }

    /// @notice used to check whether staker can unstake or not
    /// @param _address the address of the staker
    /// @param _id the index of the stake
    function canUnstake(address _address, uint256 _id)
        public
        view
        isValidStakeId(_address, _id)
        returns (bool)
    {
        return (timeLeftToUnstake(_address, _id) == 0 &&
            stakes[_address][_id].isActive);
    }

    /// @notice used to get the reward earned on stake
    /// @param _address the address of the staker
    /// @param _id the index of the stake
    function stakingReward(address _address, uint256 _id)
        public
        view
        isValidStakeId(_address, _id)
        returns (uint256)
    {
        Stake memory stake = stakes[_address][_id];
        return stake.tAmount.mul(stake.rate).div(DENOMINATOR);
    }

    /// @notice used to add a staking period and the interest rate for that period
    /// @param _period number of days or months??
    /// @param _rate interest rate
    function addStakingPeriod(uint256 _period, uint256 _rate)
        external
        onlyOwner
    {
        interestRate[_period] = _rate;
        emit StakingPeriodUpdated(_period, _rate);
    }

    function changeTokenOwnership(address _owner) external onlyOwner {
        token.transferOwnership(_owner);
    }

    function excludeAccount(address account) external onlyOwner {
        token.excludeAccount(account);
    }

    function includeAccount(address account) external onlyOwner {
        token.includeAccount(account);
    }

    function setReservePool(address _address) external onlyOwner {
        token.setReservePool(_address);
    }

    function setLiquidityPoolAddress(address _address, bool _add)
        external
        onlyOwner
    {
        token.setLiquidityPoolAddress(_address, _add);
    }

    function lock(address _address, uint256 _days) external onlyOwner {
        require(token.lockedTill(_address) == 0, "Address is already locked");
        token.lock(_address, _days);
    }

    function unlock(address _address) external onlyOwner {
        token.unlock(_address);
    }

    function setLimit(
        address _address,
        uint256 _period,
        uint256 _rule
    ) external onlyOwner {
        token.setLimit(_address, _period, _rule);
    }

    function removeLimit(address _address) external onlyOwner {
        token.removeLimit(_address);
    }

    function setMinter(address _minter) external onlyOwner {
        token.setMinter(_minter);
    }

    function removeMinter(address _minter) external onlyOwner {
        token.removeMinter(_minter);
    }

    function setTimeDurationForExtraPenaltyTax(uint _duration)
        external
        onlyOwner
    {
        token.setTimeDurationForExtraPenaltyTax(_duration);
    }

    function excludeFromFee(address account) external onlyOwner {
        token.excludeFromFee(account);
    }

    function includeFromFee(address account) external onlyOwner {
        token.includeFromFee(account);
    }

    function setReflectionFee(uint256 fee) external onlyOwner {
        token.setReflectionFee(fee);
    }

    function setLiquidityFee(uint256 fee) external onlyOwner {
        token.setLiquidityFee(fee);
    }

    function setCharityFee(uint256 fee) external onlyOwner {
        token.setCharityFee(fee);
    }

    function setBurnPercent(uint256 fee) external onlyOwner {
        token.setBurnPercent(fee);
    }

    function setMarketingFee(uint256 fee) external onlyOwner {
        token.setMarketingFee(fee);
    }

    function setEarlySellFee(uint256 fee) external onlyOwner {
        token.setEarlySellFee(fee);
    }

    function setCharityAddress(address _Address) external onlyOwner {
        token.setCharityAddress(_Address);
    }

    function setRouterAddress(address _Address) external onlyOwner {
        token.setRouterAddress(_Address);
    }

    function setLiquidityManager(address _address) external onlyOwner {
        token.setLiquidityManager(_address);
    }

    function setMarketingAddress(address _Address) external onlyOwner {
        token.setMarketingAddress(_Address);
    }

    function PrepareForPreSale() external onlyOwner {
        token.PrepareForPreSale();
    }

    function afterPreSale() external onlyOwner {
        token.afterPreSale();
    }

    function setHaltPercentages(uint256[3] memory _percentages)
        external
        onlyOwner
    {
        token.setHaltPercentages(_percentages);
    }

    function setHaltPeriods(uint256[3] memory _periods) external onlyOwner {
        token.setHaltPeriods(_periods);
    }

    function setExclusionFromHalt(address _account, bool _exclude)
        external
        onlyOwner
    {
        token.setExclusionFromHalt(_account, _exclude);
    }

    function setLastThresholdPrice(uint _lastThresholdPrice)
        external
        onlyOwner
    {
        token.setLastThresholdPrice(_lastThresholdPrice);
    }

    function resetHaltSequence() external onlyOwner {
        token.resetHaltSequence();
    }

    function toggleLockTransfer() external onlyOwner {
        token.toggleLockTransfer();
    }

    function executePriceDeclineHalt(
        uint256 currentPrice,
        uint256 referencePrice
    ) external onlyOwner returns (bool) {
        return token.executePriceDeclineHalt(currentPrice, referencePrice);
    }

    receive() external payable {}

    function withdraw() external onlyOwner {
        token.withdraw();
        payable(msg.sender).transfer(address(this).balance);
    }
}
