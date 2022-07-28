// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RadiusCoin is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    string private _name = "Radius Protocol";
    string private _symbol = "RAD";
    uint8 private _decimals = 9;

    uint256 private constant DENOMINATOR = 10000;

    mapping(address => uint256) internal _reflectionBalance;
    mapping(address => uint256) internal _tokenBalance;
    mapping(address => mapping(address => uint256)) internal _allowances;

    mapping(address => bool) private isMinter;

    uint256 private constant MAX = ~uint256(0);
    uint256 internal _tokenTotal = 400 * 10**15;
    uint256 internal _reflectionTotal = (MAX - (MAX % _tokenTotal));

    mapping(address => bool) isExcludedFromFee;
    mapping(address => bool) internal _isExcluded;
    address[] internal _excluded;
    // fees
    uint256 public _taxFee = 0; // 100 = 1% [PRESALE]
    uint256 public _charityFee = 0; // 100 = 1% [PRESALE]
    uint256 public _burnFee = 0; // 100 = 1% [PRESALE]
    uint256 public _liquidityFee = 0; // 100 = 1% [PRESALE]
    uint256 public _marketingFee = 0; // 100 = 1% [PRESALE]
    uint256 public _earlySellFee = 0;
    //var
    uint256 public _charityFeeTotal;
    uint256 public _burnFeeTotal;
    uint256 public _taxFeeTotal;
    uint256 public _liquidityFeeTotal;
    uint256 public _marketingFeeTotal;
    uint256 public _earlySellFeeTotal;

    //addresses
    address public charityAddress; // Charity Address
    address public routerAddress; // PancakeSwapRouterV2
    address public marketingFeeAddress; // marketing wallet
    address public liquidityManager; // address which will manually add liquidity to pool

    uint public timeDurationForExtraPenaltyTax; //
    //3 Level Halt Mechanism
    uint internal constant ACCURACY = 1e18;
    uint256 public lastThresholdPrice;

    bool public lockTransfer;

    enum HaltLevelStatus {
        LEVEL0,
        LEVEL1,
        LEVEL2,
        LEVEL3
    }

    HaltLevelStatus public currentHaltLevel;

    uint256 public currentHaltPeriod;

    struct HaltLevel {
        HaltLevelStatus haltLevel;
        uint256 haltLevelPercentage;
        uint256 haltLevelPeriod;
    }

    HaltLevel[4] public halts;

    mapping(address => bool) public isExcludedFromHalt;

    event RewardsDistributed(uint256 amount);

    mapping(address => bool) public isLiquidityPoolAddress;
    address public reservePoolAddress;

    // Set limit on addresses
    struct LimitInfo {
        address account;
        uint256 end;
        uint256 period;
        uint256 rule;
        uint256 spendLimit;
        uint256 amountSpent;
    }

    mapping(address => uint256) public lockedTill;
    mapping(address => LimitInfo) public limitInfos;
    // Keep track of first buy time
    mapping(address => uint256) public firstBuy;

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    /// @dev A record of each accounts delegate
    mapping(address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint) public nonces;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint previousBalance,
        uint newBalance
    );

    modifier isUnlocked(address _address) {
        require(lockedTill[_address] == 0, "Address is already locked");
        _;
    }

    constructor() {
        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[address(this)] = true;
        _reflectionBalance[_msgSender()] = _reflectionTotal;
        emit Transfer(address(0), _msgSender(), _tokenTotal);
        _moveDelegates(address(0), _msgSender(), _tokenTotal);
        currentHaltLevel = HaltLevelStatus.LEVEL0;
        initHaltLevelInfo();
        timeDurationForExtraPenaltyTax = 1 weeks;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tokenTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tokenBalance[account];
        return tokenFromReflection(_reflectionBalance[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address _owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function reflectionFromToken(uint256 tokenAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tokenAmount <= _tokenTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            return tokenAmount.mul(_getReflectionRate());
        } else {
            return
                tokenAmount.sub(tokenAmount.mul(_taxFee).div(DENOMINATOR)).mul(
                    _getReflectionRate()
                );
        }
    }

    function tokenFromReflection(uint256 reflectionAmount)
        public
        view
        returns (uint256)
    {
        require(
            reflectionAmount <= _reflectionTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getReflectionRate();
        return reflectionAmount.div(currentRate);
    }

    function excludeAccount(address account) public onlyOwner {
        require(account != address(0), "RADIUS: can not set zero address");
        require(
            account != routerAddress,
            "RADIUS: Uniswap router cannot be excluded."
        );
        require(
            account != address(this),
            "RADIUS: The contract it self cannot be excluded"
        );
        require(!_isExcluded[account], "RADIUS: Account is already excluded");
        if (_reflectionBalance[account] > 0) {
            _tokenBalance[account] = tokenFromReflection(
                _reflectionBalance[account]
            );
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) public onlyOwner {
        require(_isExcluded[account], "RADIUS: Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tokenBalance[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private isUnlocked(sender) isUnlocked(recipient) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!lockTransfer || msg.sender == owner(), "Transfers are locked");

        require(
            (block.timestamp > currentHaltPeriod) ||
                _msgSender() == owner() ||
                isExcludedFromHalt[_msgSender()],
            "Level halt has not expired"
        );

        (bool isValid, string memory limitMessage) = isWithinLimit(
            sender,
            amount
        );
        require(isValid, limitMessage);

        uint256 transferAmount = amount;
        uint256 rate = _getReflectionRate();

        if (
            !isExcludedFromFee[sender] &&
            !isExcludedFromFee[recipient] &&
            isLiquidityPoolAddress[recipient]
        ) {
            transferAmount = collectFee(sender, amount, rate);
        }

        //@dev Transfer reflection
        _reflectionBalance[sender] = _reflectionBalance[sender].sub(
            amount.mul(rate)
        );
        _reflectionBalance[recipient] = _reflectionBalance[recipient].add(
            transferAmount.mul(rate)
        );
        _moveDelegates(
            _delegates[sender],
            _delegates[recipient],
            transferAmount.mul(rate)
        );

        if (firstBuy[recipient] == 0) {
            firstBuy[recipient] = block.timestamp;
        }

        //@dev If any account belongs to the excludedAccount transfer token
        if (_isExcluded[sender]) {
            _tokenBalance[sender] = _tokenBalance[sender].sub(amount);
        }
        if (_isExcluded[recipient]) {
            _tokenBalance[recipient] = _tokenBalance[recipient].add(
                transferAmount
            );
        }

        emit Transfer(sender, recipient, transferAmount);
    }

    function setReservePool(address _address) external onlyOwner {
        require(_address != address(0), "RADIUS: can not set zero address");
        require(
            _address != reservePoolAddress,
            "New reserve pool address must different"
        );
        reservePoolAddress = _address;
        isMinter[_address] = true;
        isExcludedFromFee[_address] = true;
    }

    function setLiquidityPoolAddress(address _address, bool _add)
        external
        onlyOwner
    {
        require(_address != address(0), "RADIUS: can not set zero address");
        require(
            isLiquidityPoolAddress[_address] != _add,
            "Change address status"
        );
        isLiquidityPoolAddress[_address] = _add;
    }

    function lock(address _address, uint256 _days)
        external
        isUnlocked(_address)
        onlyOwner
    {
        require(_address != address(0), "RADIUS: can not set zero address");
        lockedTill[_address] = block.timestamp + _days * 1 days;
        excludeAccount(_address);
    }

    function unlock(address _address) external {
        require(_address != address(0), "RADIUS: can not set zero address");
        require(
            block.timestamp > lockedTill[_address] || _msgSender() == owner(),
            "Cannot unlock before locked time"
        );
        require(lockedTill[_address] > 0, "Address is already unlocked");
        lockedTill[_address] = 0;
        includeAccount(_address);
    }

    function isWithinLimit(address _address, uint256 _amount)
        private
        returns (bool, string memory)
    {
        LimitInfo storage limit = limitInfos[_address];

        if (limitInfos[_address].account != _address) {
            return (true, "");
        }

        if (block.timestamp <= limit.end) {
            if (limit.amountSpent.add(_amount) > limit.spendLimit) {
                return (false, "Amount exceeds limit");
            } else {
                limit.amountSpent = limit.amountSpent.add(_amount);
            }
        } else {
            uint256 max = balanceOf(_address).mul(limit.rule).div(DENOMINATOR);
            if (_amount <= max) {
                limit.spendLimit = max;
                limit.amountSpent = _amount;
                limit.end = block.timestamp + limit.period * 1 days;
            } else {
                return (false, "Amount exceeds limit");
            }
        }

        return (true, "");
    }

    function setLimit(
        address _address,
        uint256 _period,
        uint256 _rule
    ) external onlyOwner {
        limitInfos[_address] = LimitInfo(_address, 0, _period, _rule, 0, 0);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "RADIUS: can not set zero address");
        require(!isMinter[_minter], "already a minter");
        isMinter[_minter] = true;
    }

    function removeMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "RADIUS: can not set zero address");
        require(isMinter[_minter], "not a minter");
        isMinter[_minter] = false;
    }

    function removeLimit(address _address) external onlyOwner {
        require(_address != address(0), "RADIUS: can not set zero address");
        delete limitInfos[_address];
    }

    function mint(uint256 amount) external {
        require(isMinter[_msgSender()], "not a minter");
        // require(_msgSender() == reservePoolAddress);
        uint256 rate = _getReflectionRate();
        require(
            _reflectionBalance[_msgSender()] < MAX - amount * rate,
            "this address can not mint more tokens or it will cause overflow"
        );

        _tokenTotal = _tokenTotal.add(amount);
        _reflectionTotal = (MAX - (MAX % _tokenTotal));
        _reflectionBalance[_msgSender()] = _reflectionBalance[_msgSender()].add(
            amount * rate
        );

        _moveDelegates(
            _delegates[address(0)],
            _delegates[_msgSender()],
            amount
        );
        emit Transfer(address(0), _msgSender(), amount);
    }

    function burn(uint256 amount) external {
        uint256 rate = _getReflectionRate();
        _reflectionBalance[_msgSender()] = _reflectionBalance[_msgSender()].sub(
            amount * rate,
            "ERC20: burn amount exceeds balance"
        );
        _reflectionTotal = _reflectionTotal.sub(amount * rate);
        _tokenTotal = _tokenTotal.sub(amount);
        _moveDelegates(
            _delegates[_msgSender()],
            _delegates[address(0)],
            amount
        );
        emit Transfer(_msgSender(), address(0), amount);
    }

    function setTimeDurationForExtraPenaltyTax(uint _duration)
        external
        onlyOwner
    {
        timeDurationForExtraPenaltyTax = _duration * 1 days;
    }

    function collectFee(
        address account,
        uint256 amount,
        uint256 rate
    ) private returns (uint256) {
        uint256 transferAmount = amount;

        uint256 charityFee = amount.mul(_charityFee).div(DENOMINATOR);
        uint256 liquidityFee = amount.mul(_liquidityFee).div(DENOMINATOR);
        uint256 taxFee = amount.mul(_taxFee).div(DENOMINATOR);
        uint256 burnFee = amount.mul(_burnFee).div(DENOMINATOR);
        uint256 marketingFee = amount.mul(_marketingFee).div(DENOMINATOR);

        // DEDUCTS EXTRA 17% IF POSITION SOLD WITHIN ONE WEEK OF OPENING
        if (
            block.timestamp <=
            firstBuy[account] + timeDurationForExtraPenaltyTax
        ) {
            uint256 extraTax = amount.mul(_earlySellFee).div(DENOMINATOR);
            transferAmount = transferAmount.sub(extraTax);
            _reflectionBalance[reservePoolAddress] = _reflectionBalance[
                reservePoolAddress
            ].add(extraTax.mul(rate));
            _earlySellFeeTotal = _earlySellFeeTotal.add(extraTax);
            emit Transfer(account, reservePoolAddress, extraTax);
        }
        if (taxFee > 0) {
            transferAmount = transferAmount.sub(taxFee);
            _reflectionTotal = _reflectionTotal.sub(taxFee.mul(rate));
            _taxFeeTotal = _taxFeeTotal.add(taxFee);
            emit RewardsDistributed(taxFee);
        }

        if (charityFee > 0) {
            transferAmount = transferAmount.sub(charityFee);
            _reflectionBalance[charityAddress] = _reflectionBalance[
                charityAddress
            ].add(charityFee.mul(rate));
            _charityFeeTotal = _charityFeeTotal.add(charityFee);
            emit Transfer(account, charityAddress, charityFee);
        }

        if (burnFee > 0) {
            transferAmount = transferAmount.sub(burnFee);
            _reflectionTotal = _reflectionTotal.sub(burnFee.mul(rate));
            _tokenTotal = _tokenTotal.sub(burnFee);
            _burnFeeTotal = _burnFeeTotal.add(burnFee);
            emit Transfer(account, address(0), burnFee);
        }

        if (liquidityFee > 0) {
            transferAmount = transferAmount.sub(liquidityFee);
            _reflectionBalance[liquidityManager] = _reflectionBalance[
                liquidityManager
            ].add(liquidityFee.mul(rate));
            _liquidityFeeTotal = _liquidityFeeTotal.add(liquidityFee);
            emit Transfer(account, liquidityManager, liquidityFee);
        }

        if (marketingFee > 0) {
            transferAmount = transferAmount.sub(marketingFee);
            _reflectionBalance[marketingFeeAddress] = _reflectionBalance[
                marketingFeeAddress
            ].add(marketingFee.mul(rate));
            _marketingFeeTotal = _marketingFeeTotal.add(marketingFee);
            emit Transfer(account, marketingFeeAddress, marketingFee);
        }

        return transferAmount;
    }

    function _getReflectionRate() private view returns (uint256) {
        uint256 reflectionSupply = _reflectionTotal;
        uint256 tokenSupply = _tokenTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _reflectionBalance[_excluded[i]] > reflectionSupply ||
                _tokenBalance[_excluded[i]] > tokenSupply
            ) return _reflectionTotal.div(_tokenTotal);
            reflectionSupply = reflectionSupply.sub(
                _reflectionBalance[_excluded[i]]
            );
            tokenSupply = tokenSupply.sub(_tokenBalance[_excluded[i]]);
        }
        if (reflectionSupply < _reflectionTotal.div(_tokenTotal))
            return _reflectionTotal.div(_tokenTotal);
        return reflectionSupply.div(tokenSupply);
    }

    function excludeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = true;
    }

    function includeFromFee(address account) external onlyOwner {
        isExcludedFromFee[account] = false;
    }

    function setReflectionFee(uint256 fee) external onlyOwner {
        _taxFee = fee;
    }

    function setLiquidityFee(uint256 fee) external onlyOwner {
        _liquidityFee = fee;
    }

    function setCharityFee(uint256 fee) external onlyOwner {
        _charityFee = fee;
    }

    function setBurnPercent(uint256 fee) external onlyOwner {
        _burnFee = fee;
    }

    function setMarketingFee(uint256 fee) external onlyOwner {
        _marketingFee = fee;
    }

    function setEarlySellFee(uint256 fee) external onlyOwner {
        _earlySellFee = fee;
    }

    function setCharityAddress(address _Address) external onlyOwner {
        require(_Address != charityAddress);

        charityAddress = _Address;
    }

    function setRouterAddress(address _Address) external onlyOwner {
        require(_Address != routerAddress);

        routerAddress = _Address;
    }

    function setLiquidityManager(address _address) external onlyOwner {
        require(_address != liquidityManager);

        liquidityManager = _address;
    }

    function setMarketingAddress(address _Address) external onlyOwner {
        require(_Address != marketingFeeAddress);

        marketingFeeAddress = _Address;
    }

    function PrepareForPreSale() external onlyOwner {
        _burnFee = 0;
        _charityFee = 0;
        _taxFee = 0;
        _marketingFee = 0;
        _liquidityFee = 0;
        _earlySellFee = 0;
    }

    function afterPreSale() external onlyOwner {
        _burnFee = 200;
        _charityFee = 100;
        _taxFee = 500;
        _marketingFee = 300;
        _liquidityFee = 600;
        _earlySellFee = 1700;
    }

    function initHaltLevelInfo() internal {
        halts[1].haltLevelPercentage = 15;
        halts[2].haltLevelPercentage = 10;
        halts[3].haltLevelPercentage = 10;

        halts[1].haltLevelPeriod = 1 hours;
        halts[2].haltLevelPeriod = 3 * 1 hours;
        halts[3].haltLevelPeriod = 6 * 1 hours;

        halts[1].haltLevel = HaltLevelStatus(1);
        halts[2].haltLevel = HaltLevelStatus(2);
        halts[3].haltLevel = HaltLevelStatus(3);
    }

    function setHaltPercentages(uint256[3] memory _percentages)
        external
        onlyOwner
    {
        halts[1].haltLevelPercentage = _percentages[0]; // in normal precentages without extra ZEROs
        halts[2].haltLevelPercentage = _percentages[1];
        halts[3].haltLevelPercentage = _percentages[2];
    }

    function setHaltPeriods(uint256[3] memory _periods) external onlyOwner {
        halts[1].haltLevelPeriod = _periods[0] * 1 hours;
        halts[2].haltLevelPeriod = _periods[1] * 1 hours;
        halts[3].haltLevelPeriod = _periods[2] * 1 hours;
    }

    function checkPercent(uint256 currentPrice, uint256 referencePrice)
        internal
        pure
        returns (uint256)
    {
        return (
            ((referencePrice.sub(currentPrice)).mul(100)).mul(ACCURACY).div(
                referencePrice
            )
        );
    }

    function setExclusionFromHalt(address _account, bool _exclude)
        external
        onlyOwner
    {
        require(
            _account != address(0),
            "RadiusToken: _account can not be zero address"
        );
        isExcludedFromHalt[_account] = _exclude;
    }

    function isHalted() external view returns (bool) {
        return currentHaltPeriod >= block.timestamp;
    }

    function executePriceDeclineHalt(
        uint256 currentPrice,
        uint256 referencePrice
    ) external onlyOwner returns (bool) {
        uint256 percentDecline;

        if (currentHaltLevel != HaltLevelStatus.LEVEL0) {
            referencePrice = lastThresholdPrice;
        }

        if (currentPrice < referencePrice) {
            percentDecline = checkPercent(currentPrice, referencePrice);
            if (
                currentHaltLevel == HaltLevelStatus.LEVEL0 ||
                currentHaltLevel == HaltLevelStatus.LEVEL3
            ) {
                if (
                    percentDecline >=
                    (halts[1].haltLevelPercentage.mul(ACCURACY))
                ) {
                    //set Level index halt
                    _updateCurrentHaltInfo(1, currentPrice);
                    return true;
                }
                return false;
            } else if (
                currentHaltLevel == HaltLevelStatus.LEVEL1 ||
                currentHaltLevel == HaltLevelStatus.LEVEL2
            ) {
                uint i = uint(currentHaltLevel);
                if (
                    percentDecline >=
                    (halts[i + 1].haltLevelPercentage.mul(ACCURACY))
                ) {
                    //set Level index halt
                    _updateCurrentHaltInfo(i + 1, currentPrice);
                    return true;
                }
                return false;
            }
            return false;
        } else {
            return false;
        }
    }

    function resetHaltSequence() external onlyOwner {
        currentHaltPeriod = 0;
        currentHaltLevel = HaltLevelStatus.LEVEL0;
        lastThresholdPrice = 0;
    }

    function setLastThresholdPrice(uint _lastThresholdPrice)
        external
        onlyOwner
    {
        require(
            _lastThresholdPrice > 0,
            "lastThresholdPrice must be greater than zero"
        );
        require(
            currentHaltLevel == HaltLevelStatus.LEVEL3,
            "Can only set _lastThresholdPrice when currentHaltLevel is 3"
        );
        lastThresholdPrice = _lastThresholdPrice;
    }

    function toggleLockTransfer() external onlyOwner {
        lockTransfer = !lockTransfer;
    }

    function _updateCurrentHaltInfo(uint256 haltlevel, uint256 currentPrice)
        internal
    {
        currentHaltPeriod = block.timestamp + halts[haltlevel].haltLevelPeriod;
        currentHaltLevel = halts[haltlevel].haltLevel;
        lastThresholdPrice = currentPrice;
    }

    /**
     * @notice Delegate votes from `_msgSender()` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator) external view returns (address) {
        return _delegates[delegator];
    }

    /**
     * @notice Delegate votes from `_msgSender()` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external {
        return _delegate(_msgSender(), delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry)
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "RADIUS::delegateBySig: invalid signature"
        );
        require(
            nonce == nonces[signatory]++,
            "RADIUS::delegateBySig: invalid nonce"
        );
        require(
            block.timestamp <= expiry,
            "RADIUS::delegateBySig: signature expired"
        );
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return
            nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(
            blockNumber < block.number,
            "RADIUS::getPriorVotes: not yet determined"
        );

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0
                    ? checkpoints[srcRep][srcRepNum - 1].votes
                    : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0
                    ? checkpoints[dstRep][dstRepNum - 1].votes
                    : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal {
        uint32 blockNumber = safe32(
            block.number,
            "RADIUS::_writeCheckpoint: block number exceeds 32 bits"
        );

        if (
            nCheckpoints > 0 &&
            checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber
        ) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(
                blockNumber,
                newVotes
            );
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    receive() external payable {}

    function withdraw() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }
}
