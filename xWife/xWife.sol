// SPDX-License-Identifier: None
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TokenSale is ERC20, Ownable, Pausable, ReentrancyGuard {

    uint128 public saleStartTimestamp = uint128(block.timestamp);

    uint128 public adoptionPhaseDuration;

    uint128 public inflationPhaseDuration;

    uint256 public tokenPrice;

    mapping(address => uint256) public lockedWives;

    bool public salePaused;

    enum Phase { ADOPTION, INFLATION, AFTER_INFLATION }


    event Purchased(address indexed user, uint256 paid, uint256 received);

    event TokenPriceUpdated(uint256 oldPrice, uint256 newPrice);

    event xWifeUnlocked(address user, uint256 amount);

    event PausedSale(address pausedBy);

    event UnpausedSale(address unpausedBy);

    /**
     * @dev assign the duration values
     *
     * @param ownerAddress Admin access of this contract
     * @param adoptionPhaseLength Duration of adoption phase in hours
     * @param inflationPhaseLength Duration of inflation phase in hours
     *
     */
    constructor (address ownerAddress,
        uint128 adoptionPhaseLength,
        uint128 inflationPhaseLength,
        uint256 tokenPricePerWei,
        string memory tokenName,
        string memory tokenSymbol) ERC20(tokenName, tokenSymbol) {

        require(ownerAddress != address(0), "Invalid Owner address.");
        require(adoptionPhaseLength != 0, "Invalid Adoption Phase Length.");
        require(inflationPhaseLength != 0, "Invalid Inflation Phase Length.");
        require(tokenPricePerWei != 0, "Invalid Price.");

        adoptionPhaseDuration  = adoptionPhaseLength * 60 * 60; //2 months
        inflationPhaseDuration = inflationPhaseLength * 60 * 60; //6 months
        tokenPrice = tokenPricePerWei;
        _transferOwnership(ownerAddress);
    }

    /**
    * @dev Returns xWife tokens `receivedAmount` to be returned by paying PLS `purchaseAmount` amount.
    *
    */
    function getReturnAmount(uint256 purchaseAmount) public view returns(uint256) {
        uint256 receivedAmount = purchaseAmount*tokenPrice;
        return receivedAmount;
    }

    /**
    * @dev Sets the return amount of tokens `tokenPrice` in return of 1 wei PLS.
    *
    */
    function setTokenPrice(uint256 _price) external onlyOwner {
        require(_price != 0, "Invalid price.");
        emit TokenPriceUpdated(tokenPrice, _price);
        tokenPrice = _price;
    }

    /**
    * @dev Returns the active phase.
    *
    */
    function getPhase() public view returns(Phase) {
        if(block.timestamp <= (saleStartTimestamp + adoptionPhaseDuration)) {
            return Phase.ADOPTION;
        }

        if(block.timestamp <= (saleStartTimestamp + adoptionPhaseDuration + inflationPhaseDuration)) {
            return Phase.INFLATION;
        }

        return Phase.AFTER_INFLATION;
    }

    /**
    * @dev User buys some xWife tokens by paying PLS.
    *
    */
    function buy() public payable whenSaleNotPaused {
        uint256 purchaseAmount = msg.value;
        uint256 receivedAmount = getReturnAmount(purchaseAmount);

        if(getPhase() == Phase.ADOPTION)  lockedWives[_msgSender()] += receivedAmount;
        else                              _mint(_msgSender(), receivedAmount);

        (bool sent,) = owner().call{value: purchaseAmount}("");
        require(sent, "Failed to send PLS");
        emit Purchased(_msgSender(), purchaseAmount, receivedAmount);
    }

    /**
    * @dev Unlock locked xWifeTokens after adoption phase ends.
    *
    */
    function unlockWives(uint256 amount) external returns(bool) {
        require(getPhase() != Phase.ADOPTION, "Adoption Phase active");
        require(amount <= lockedWives[_msgSender()], "Not enough locked balance");

        lockedWives[_msgSender()] -= amount;
        _mint(_msgSender(), amount);

        emit xWifeUnlocked(_msgSender(),amount);
        return true;
    }

    /**
    * @dev Fallback function if PLS is sent to address instead of buyTokens function
    **/
    receive () external payable {
        buy();
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenSaleNotPaused() {
        require(!salePaused, "Pausable: paused");
        _;
    }

    /**
     * @dev Pause the contract. Stops the pausable functions from being accessed.
     */
    function pauseSale() external onlyOwner whenSaleNotPaused {
        salePaused = true;
        emit PausedSale(_msgSender());
    }

    /**
     * @dev Unpause the contract. Allows the pausable functions to be accessed.
     */
    function unpauseSale() external onlyOwner {
        require(salePaused, "Pausable: not paused");
        salePaused = false;
        emit UnpausedSale(_msgSender());
    }

}

library DistributionTypes {
    struct AssetConfigInput {
        uint128 emissionPerSecond;
        uint256 totalStaked;
        address underlyingAsset;
    }

    struct UserStakeInput {
        address underlyingAsset;
        uint256 stakedByUser;
        uint256 totalStaked;
    }
}


/**
 * @title xWifeDistributionManager
 * @notice Accounting contract to manage multiple staking distributions
 * @author xWife
 **/
contract xWifeDistributionManager {

    struct AssetData {
        uint128 emissionPerSecond;
        uint128 lastUpdateTimestamp;
        uint256 index;
        mapping(address => uint256) users;
    }

    uint8 public constant PRECISION = 18;

    mapping(address => AssetData) public assets;

    event AssetConfigUpdated(address indexed asset, uint256 emission);
    event AssetIndexUpdated(address indexed asset, uint256 index);
    event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

    /**
     * @dev Configures the distribution of rewards for a list of assets
   * @param assetsConfigInput The list of configurations to apply
   **/
    function configureAssets(DistributionTypes.AssetConfigInput[] memory assetsConfigInput) internal {

        for (uint256 i = 0; i < assetsConfigInput.length; i++) {
            AssetData storage assetConfig = assets[assetsConfigInput[i].underlyingAsset];

            _updateAssetStateInternal(
                assetsConfigInput[i].underlyingAsset,
                assetConfig,
                assetsConfigInput[i].totalStaked
            );

            assetConfig.emissionPerSecond = assetsConfigInput[i].emissionPerSecond;

            emit AssetConfigUpdated(
                assetsConfigInput[i].underlyingAsset,
                assetsConfigInput[i].emissionPerSecond
            );
        }
    }

    /**
     * @dev Updates the state of one distribution, mainly rewards index and timestamp
   * @param underlyingAsset The address used as key in the distribution, for example sAAVE or the aTokens addresses on xWife
   * @param assetConfig Storage pointer to the distribution's config
   * @param totalStaked Current total of staked assets for this distribution
   * @return The new distribution index
   **/
    function _updateAssetStateInternal(
        address underlyingAsset,
        AssetData storage assetConfig,
        uint256 totalStaked
    ) internal returns (uint256) {
        uint256 oldIndex = assetConfig.index;
        uint128 lastUpdateTimestamp = assetConfig.lastUpdateTimestamp;

        if (block.timestamp == lastUpdateTimestamp) {
            return oldIndex;
        }

        uint256 newIndex = _getAssetIndex(
            oldIndex,
            assetConfig.emissionPerSecond,
            lastUpdateTimestamp,
            totalStaked
        );

        if (newIndex != oldIndex) {
            assetConfig.index = newIndex;
            emit AssetIndexUpdated(underlyingAsset, newIndex);
        }

        assetConfig.lastUpdateTimestamp = uint128(block.timestamp);

        return newIndex;
    }

    /**
     * @dev Updates the state of an user in a distribution
   * @param user The user's address
   * @param asset The address of the reference asset of the distribution
   * @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
   * @param totalStaked Total tokens staked in the distribution
   * @return The accrued rewards for the user until the moment
   **/
    function _updateUserAssetInternal(
        address user,
        address asset,
        uint256 stakedByUser,
        uint256 totalStaked
    ) internal returns (uint256) {
        AssetData storage assetData = assets[asset];
        uint256 userIndex = assetData.users[user];
        uint256 accruedRewards = 0;

        uint256 newIndex = _updateAssetStateInternal(asset, assetData, totalStaked);

        if (userIndex != newIndex) {
            if (stakedByUser != 0) {
                accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
            }

            assetData.users[user] = newIndex;
            emit UserIndexUpdated(user, asset, newIndex);
        }

        return accruedRewards;
    }

    /**
     * @dev Used by "frontend" stake contracts to update the data of an user when claiming rewards from there
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
    function _claimRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    returns (uint256)
    {
        uint256 accruedRewards = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            accruedRewards = accruedRewards + 
                _updateUserAssetInternal(
                    user,
                    stakes[i].underlyingAsset,
                    stakes[i].stakedByUser,
                    stakes[i].totalStaked
                );
        }

        return accruedRewards;
    }

    /**
     * @dev Return the accrued rewards for an user over a list of distribution
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
    function _getUnclaimedRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    view
    returns (uint256)
    {
        uint256 accruedRewards = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            AssetData storage assetConfig = assets[stakes[i].underlyingAsset];
            uint256 assetIndex = _getAssetIndex(
                assetConfig.index,
                assetConfig.emissionPerSecond,
                assetConfig.lastUpdateTimestamp,
                stakes[i].totalStaked
            );

            accruedRewards = accruedRewards +
                _getRewards(stakes[i].stakedByUser, assetIndex, assetConfig.users[user]);
        }
        return accruedRewards;
    }

    /**
     * @dev Internal function for the calculation of user's rewards on a distribution
   * @param principalUserBalance Amount staked by the user on a distribution
   * @param reserveIndex Current index of the distribution
   * @param userIndex Index stored for the user, representation his staking moment
   * @return The rewards
   **/
    function _getRewards(
        uint256 principalUserBalance,
        uint256 reserveIndex,
        uint256 userIndex
    ) internal pure returns (uint256) {
        return principalUserBalance * (reserveIndex - userIndex) / (10**uint256(PRECISION));
    }

    /**
     * @dev Calculates the next value of an specific distribution index, with validations
   * @param currentIndex Current index of the distribution
   * @param emissionPerSecond Representing the total rewards distributed per second per asset unit, on the distribution
   * @param lastUpdateTimestamp Last moment this distribution was updated
   * @param totalBalance of tokens considered for the distribution
   * @return The new index.
   **/
    function _getAssetIndex(
        uint256 currentIndex,
        uint256 emissionPerSecond,
        uint128 lastUpdateTimestamp,
        uint256 totalBalance
    ) internal view returns (uint256) {
        if (
            emissionPerSecond == 0 ||
            totalBalance == 0 ||
            lastUpdateTimestamp == block.timestamp
        ) {
            return currentIndex;
        }

        uint256 currentTimestamp = block.timestamp;
        uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
        return
        ((emissionPerSecond * timeDelta * (10**uint256(PRECISION))) / totalBalance) + currentIndex;
    }

    /**
     * @dev Returns the data of an user on a distribution
   * @param user Address of the user
   * @param asset The address of the reference asset of the distribution
   * @return The new index
   **/
    function getUserAssetData(address user, address asset) public view returns (uint256) {
        return assets[asset].users[user];
    }
}



contract XWife is TokenSale, xWifeDistributionManager {

    uint256 constant baseFee = 24*10**18;
    uint256 constant fixedFee = 1*10**18;

    address public penaltyAndFeesRecipient;

    uint128 public emissionPerSecond;
    uint128 public lastUpdateMonth;
    uint128 private emissionRateDuration;// = 30 days;
    uint256 internal constant LATE_PENALTY_GRACE_DAYS = 14 days;
    uint256 internal constant LATE_PENALTY_SCALE_DAYS = 700 days;

    struct StakeStore {
        uint256 stakedWives;
        uint256 stakeStartTimestamp;
        uint256 stakeEndTimestamp;
        uint256 lastUpdateTimestamp;
    }

    uint256 public totalStaked;
    mapping(address => uint256) public stakerRewardsToClaim;
    mapping(address => StakeStore) public stakes;

    event Staked(address user, uint256 amount, uint256 duration);
    event Withdrawn(address user, uint256 amount, uint256 supplyLockingFees, uint256 earlyOrLatePenalty);
    event Compounded(address user, uint256 amountToClaim);
    event RewardsClaimed(address user, uint256 amountToClaim);
    event EmissionRateUpdated(uint256 emissionPerSecond);

    /**
     * @dev assign the duration values
     *
     * @param ownerAddress Admin access of this contract
     * @param adoptionPhaseLength Duration of adoption phase in hours (1440 Hrs)
     * @param inflationPhaseLength Duration of inflation phase in hours (4320 Hrs)
     * @param tokenPricePerWei Duration of inflation phase in hours
     * @param emissionPerSecondInitial Initial emission rate per second
     * @param emissionDuration Duration after which emission rate updates automatically, in hours (720 Hrs)
     *
     */
    constructor (address ownerAddress,
        address penaltyAndFeeRecipient,
        uint128 adoptionPhaseLength,
        uint128 inflationPhaseLength,
        uint128 tokenPricePerWei,
        uint128 emissionPerSecondInitial,
        uint128 emissionDuration,
        string memory tokenName,
        string memory tokenSymbol)
    TokenSale(ownerAddress, adoptionPhaseLength, inflationPhaseLength, tokenPricePerWei, tokenName, tokenSymbol) {

        penaltyAndFeesRecipient = penaltyAndFeeRecipient;
        emissionPerSecond = emissionPerSecondInitial;
        emissionRateDuration = emissionDuration * 60 * 60; // 30 days
    }

    function getSupplyLockingFees(uint256 amount) public view returns (uint256) {
        return amount*getSupplyLockingFeesPercent()/(100*10**18);
    }

    function getSupplyLockingFeesPercent() public view returns (uint256) {
        if(block.timestamp > saleStartTimestamp + adoptionPhaseDuration + inflationPhaseDuration){
            return fixedFee;
        }
        uint256 feesPercent = baseFee-((baseFee*(block.timestamp - (saleStartTimestamp + adoptionPhaseDuration))) / inflationPhaseDuration);
        return fixedFee+feesPercent;
    }

    function getPenalty(uint256 amount, uint256 startTimestamp, uint256 endTimestamp) public view returns (uint256)
    {
        uint256 currentTimestamp = block.timestamp;

        if (currentTimestamp < endTimestamp) {
            uint256 servedDuration = endTimestamp - currentTimestamp;
            uint256 totalDuration = endTimestamp - startTimestamp;
            return (amount * servedDuration) / totalDuration;
        }

        /* Allow grace time before penalties accrue */
        uint256 maxUnlockedTimestamp = endTimestamp + LATE_PENALTY_GRACE_DAYS;
        if (currentTimestamp <= maxUnlockedTimestamp) {
            return 0;
        }

        /* Calculate penalty as a percentage of stake return based on time */
        return amount * (currentTimestamp - maxUnlockedTimestamp) / LATE_PENALTY_SCALE_DAYS;
    }

    /**
     * @dev Stakes `amount` tokens for `duration` days. Increases the staked amount and duration if a stake already exists.
     *
     * @param amount    Amount of xWife tokens to stake.
     * @param duration  no. of days for which the tokens are staked.
     */
    function stakeStart(uint256 amount, uint256 duration) external inInflationPhase nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0.");
        require(duration > 0, "Duration less than minimum.");

        duration = duration*24*60*60; //converting in seconds
        address user = msg.sender;

        updateEmissionRate();

        uint256 accruedRewards = _updateUserAssetInternal(
            user,
            address(this),
            stakes[user].stakedWives,
            totalStaked
        );

        if (accruedRewards != 0) {
            stakerRewardsToClaim[user] = stakerRewardsToClaim[user] + accruedRewards;
        }


        //if its a new stake
        if(stakes[user].stakeStartTimestamp==0){
            stakes[user] = StakeStore(
                amount,
                block.timestamp,
                block.timestamp+duration,
                block.timestamp);
        }
        else { // if stake is being updated
            StakeStore storage newStake = stakes[user];
            newStake.stakedWives += amount;
            newStake.stakeEndTimestamp += duration;
            newStake.lastUpdateTimestamp = block.timestamp;
        }

        totalStaked += amount;

        _transfer(user, address(this), amount);
        emit Staked(user, amount, duration);
    }

    /**
     * @dev Withdraws `amount` tokens.
     *
     * @param amount    Amount of xWife tokens to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        uint balance = stakes[msg.sender].stakedWives;

        amount = (amount == 0) ? balance : amount;
        require(amount <= balance, "Invalid amount");

        _updateCurrentUnclaimedRewards(msg.sender, balance, true);

        uint supplyLockingFees  = getSupplyLockingFees(amount);
        uint earlyOrLatePenalty = getPenalty(amount - supplyLockingFees,
                                             stakes[msg.sender].stakeStartTimestamp,
                                             stakes[msg.sender].stakeEndTimestamp);
        totalStaked = totalStaked-amount;

        if(amount == balance)
            delete stakes[msg.sender];

        else {
            StakeStore storage newStake = stakes[msg.sender];
            newStake.stakedWives -= amount;
            newStake.lastUpdateTimestamp = block.timestamp;
        }

        _transfer(address(this), msg.sender, amount-(supplyLockingFees+earlyOrLatePenalty));
        _transfer(address(this), penaltyAndFeesRecipient, supplyLockingFees+earlyOrLatePenalty);
        emit Withdrawn(msg.sender, amount, supplyLockingFees, earlyOrLatePenalty);
       }

    /**
     * @dev Compounds an `amount` of reward i.e. mints reward and adds it to stake's principal.
     * @param amount Amount to compound
     **/
    function compound(uint256 amount) external whenNotPaused {
        uint256 newTotalRewards = _updateCurrentUnclaimedRewards(
            msg.sender,
            stakes[msg.sender].stakedWives,
            true
        );

        require(amount <= newTotalRewards, "Not enough amount to claim");

        require(stakes[msg.sender].stakedWives != 0, "No tokens staked to compound.");

        uint256 amountToClaim = (amount == 0) ? newTotalRewards : amount;

        stakerRewardsToClaim[msg.sender] = newTotalRewards - amountToClaim;

        stakes[msg.sender].stakedWives += amountToClaim;

        totalStaked += amountToClaim;

        _mint(address(this), amountToClaim);

        emit Compounded(msg.sender, amountToClaim);
    }


    /**
     * @dev Claims an `amount` of reward by minting it to user;s address.
     * @param amount Amount to claim
     **/
    function claimRewards(uint256 amount) external {
        uint256 newTotalRewards = _updateCurrentUnclaimedRewards(
            msg.sender,
            stakes[msg.sender].stakedWives,
            false
        );

        require(amount <= newTotalRewards, "Not enough amount to claim");

        uint256 amountToClaim = (amount == 0) ? newTotalRewards : amount;

        stakerRewardsToClaim[msg.sender] = newTotalRewards - amountToClaim;

        _mint(msg.sender, amountToClaim);

        emit RewardsClaimed(msg.sender, amountToClaim);
    }

    /**
     * @dev Updates the user state related with his accrued rewards
   * @param user Address of the user
   * @param userBalance The current balance of the user
   * @param updateStorage Boolean flag used to update or not the stakerRewardsToClaim of the user
   * @return The unclaimed rewards that were added to the total accrued
   **/
    function _updateCurrentUnclaimedRewards(
        address user,
        uint256 userBalance,
        bool updateStorage
    ) internal returns (uint256) {

        updateEmissionRate();

        uint256 accruedRewards = _updateUserAssetInternal(
            user,
            address(this),
            userBalance,
            this.totalStaked()
        );
        uint256 unclaimedRewards = stakerRewardsToClaim[user] + accruedRewards;

        if (accruedRewards != 0) {
            if (updateStorage) {
                stakerRewardsToClaim[user] = unclaimedRewards;
            }
        }

        return unclaimedRewards;
    }

    /**
     * @dev Return the total rewards pending to claim by an staker
     * @param staker The staker address
     * @return The rewards
     */
    function getTotalRewardsBalance(address staker) external view returns (uint256) {

        DistributionTypes.UserStakeInput[] memory userStakeInputs
        = new DistributionTypes.UserStakeInput[](1);
        userStakeInputs[0] = DistributionTypes.UserStakeInput({
        underlyingAsset: address(this),
        stakedByUser: stakes[staker].stakedWives,
        totalStaked: this.totalStaked()
        });
        return stakerRewardsToClaim[staker] + _getUnclaimedRewards(staker, userStakeInputs);
    }

    function updateEmissionRate() public {

        uint128 month = uint128((block.timestamp - (saleStartTimestamp + adoptionPhaseDuration)) / emissionRateDuration) + 1;

        if(lastUpdateMonth>=month || month > 6) return;

        DistributionTypes.AssetConfigInput[] memory assetInputs
        = new DistributionTypes.AssetConfigInput[](1);

        assetInputs[0] = DistributionTypes.AssetConfigInput(emissionPerSecond,totalStaked,address(this));

        emissionPerSecond = emissionPerSecond / 2;
        lastUpdateMonth = month;

        configureAssets(assetInputs);

        emit EmissionRateUpdated(assetInputs[0].emissionPerSecond);
    }

    /**
     * @dev Pause the contract. Stops the pausable functions from being accessed.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract. Allows the pausable functions to be accessed.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    modifier inInflationPhase() {
        require(getPhase() == Phase.INFLATION, "Not in Inflation Phase");
        _;
    }
}