// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IScalperNFT.sol";
import "./interfaces/INFTScalping.sol";
import "./interfaces/IRadius.sol";

/**
 * @dev Implementation of ERC721 Non-Fungible Token Standard, including
 * a method to mint NFTs to only NFTScalping COntract
 */
contract NFTScalping is
    Context,
    ERC165,
    INFTScalping,
    Ownable,
    ReentrancyGuard,
    IERC721Receiver
{
    using SafeCast for uint256;

    // to check image hash
    mapping(string => bool) public exists;

    // RADIUS token contract
    IRadius private radiusToken;

    // ScalperNFT contract
    IScalperNFT private scalperNFT;

    // Mapping from token ID to NFTRentInfo
    mapping(uint256 => NFTRentInfo) public nftRentInfos;

    // Mapping from tenant address to count of rented NFTs
    mapping(address => uint256) public rentCount;

    // Mapping from tenant address to index to toked ID, to enumerate rented NFTs per tenant
    mapping(address => mapping(uint256 => uint256)) private _rentedNFTs;

    // Mapping from token ID to index in _rentedNFTs[tenant]
    mapping(uint256 => uint256) private _rentedNFTsIndex;

    // for percentages
    uint256 private constant DENOMINATOR = 10000;

    // reward interval
    uint256 public timeIntervalForRewards;

    // total number of minted NFTs
    uint256 public tokenCounter;

    // total allocated pool percentage
    uint256 public totalAllocatedpool;

    // limit in percentage for allocation of pool
    uint256 public totalAllocationLimit;

    // array of RentalLevelInfo to store information about 6 tiers of renting
    RentalLevelInfo[6] public rentalLevel;

    // ======== Admin functions ========
    constructor(address _scalperNFT, address _radiusToken) {
        require(
            _scalperNFT != address(0),
            "NFTScalping: _scalperNFT address can not be zero"
        ); // E0: addr err
        require(
            _radiusToken != address(0),
            "NFTScalping: _radiusToken address can not be zero"
        ); // E0: addr err
        totalAllocationLimit = 9900;
        timeIntervalForRewards = 7 days;
        scalperNFT = IScalperNFT(_scalperNFT);
        radiusToken = IRadius(_radiusToken);
    }

    modifier nftExists(uint256 _tokenId) {
        require(scalperNFT.exists(_tokenId), "NFT does not exist");
        _;
    }

    /// @notice used by owner to vacate tenant in case when rental period expires
    /// @notice tokenId must exist
    /// @notice NFT should be on rent
    /// @notice rental period should be over
    /// @param tokenId ID of the NFT
    function terminateRental(uint tokenId)
        external
        override
        nftExists(tokenId)
        onlyOwner
    {
        NFTRentInfo memory _nftRentInfo = nftRentInfos[tokenId];
        require(
            _nftRentInfo.tenant != address(0),
            "NFTScalping: NFT not on rent"
        );
        require(
            _nftRentInfo.rentalDuration + _nftRentInfo.rentStartTime <
                block.timestamp,
            "NFTScalping: NFt is in active rent duration"
        );

        address tenant = _nftRentInfo.tenant;
        emit RentalTerminated(tokenId, tenant);

        // removing NFT from the _rentedNFTs and the _rentedNFTsIndex
        rentCount[tenant]--;
        uint256 lastIndex = rentCount[tenant];
        uint256 tokenIndex = _rentedNFTsIndex[tokenId];

        // swap and purge if not the last one
        if (tokenIndex != lastIndex) {
            uint256 lastTokenId = _rentedNFTs[tenant][lastIndex];
            _rentedNFTs[tenant][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _rentedNFTsIndex[lastTokenId] = tokenIndex;
        }
        delete _rentedNFTsIndex[tokenId];
        delete _rentedNFTs[tenant][tokenIndex];
        totalAllocatedpool -= _nftRentInfo.scalpingPercentage;
        // set _nftRentInfo as un rented
        _nftRentInfo.tenant = address(0);
        _nftRentInfo.rentalDuration = 0;
        _nftRentInfo.rentStartTime = 0;
        _nftRentInfo.rentPaid = 0;
        _nftRentInfo.scalpingPercentage = 0;
        nftRentInfos[tokenId] = _nftRentInfo;
    }

    /// @notice function to mint NFTs, can be called by owner only
    /// @notice image hash of the NFT should be unique
    /// @param _imageHash hash of the image
    /// @param _metadata data about the NFTs
    /// @param _count number of NFTs to mint
    function mint(
        string memory _imageHash,
        string memory _metadata,
        uint256 _count
    ) external onlyOwner nonReentrant {
        require(!exists[_imageHash], "Image already exists");
        require(_count > 0, "cannot mint 0 NFTs");
        exists[_imageHash] = true;
        scalperNFT.mint(address(this), _metadata, _count);
        tokenCounter += _count;
    }

    /// @notice function to set the rental information
    /// @notice to be called after the deployment
    /// @param _rentalLevel a number from 0 to 6
    /// @param _priceInAvax rental price of the NFT in AVAX for the specified level
    /// @param _priceInRadius rental price of the NFT in Radius for the specified level
    /// @param _duration rental duration for the specified level
    function setRentalInformation(
        RentalLevels _rentalLevel,
        uint256 _priceInAvax,
        uint256 _priceInRadius,
        uint256 _duration,
        uint _scalpingPercentage
    ) external virtual override onlyOwner {
        _setRentalInformation(
            _rentalLevel,
            _priceInAvax,
            _priceInRadius,
            _duration,
            _scalpingPercentage
        );
    }

    function _setRentalInformation(
        RentalLevels _rentalLevel,
        uint256 _priceInAvax,
        uint256 _priceInRadius,
        uint256 _duration,
        uint256 _scalpingPercentage
    ) internal nonReentrant {
        require(
            _priceInAvax > 0,
            "NFTScalping: _priceInAvax must be greater than zero"
        );
        require(
            _priceInRadius > 0,
            "NFTScalping: _priceInRadius must be greater than zero"
        );
        require(
            _duration > 0,
            "NFTScalping: _duration must be greater than zero"
        );
        require(
            _scalpingPercentage > 0 && _scalpingPercentage < 10000,
            "NFTScalping: _scalpingPercentage must be within range (0 - 10000)"
        );

        RentalLevelInfo memory rentalLevelInfo = rentalLevel[
            uint256(_rentalLevel)
        ];
        rentalLevelInfo.level = uint256(_rentalLevel);
        rentalLevelInfo.priceInAvax = _priceInAvax;
        rentalLevelInfo.priceInRadius = _priceInRadius;
        rentalLevelInfo.duration = _duration;
        rentalLevelInfo.scalpingPercentage = _scalpingPercentage;
        rentalLevel[uint256(_rentalLevel)] = rentalLevelInfo;
    }

    /// @notice function to set the allocation limit, by the owner only
    /// @param _limit allocation limit of the pool (100% => 10000, 10% => 1000, 1% => 100)
    function setTotalAllocationLimit(uint256 _limit)
        external
        virtual
        override
        onlyOwner
    {
        require(
            _limit >= totalAllocatedpool,
            "NFTScalping: can not set limit less than current allocation pool"
        );
        uint oldLimit = totalAllocationLimit;
        totalAllocationLimit = _limit;
        emit TotalAllocationLimitChanged(oldLimit, totalAllocationLimit);
    }

    /// @notice function to set the time interval for the rewards
    /// @notice that means after how much time can we take the rewards
    /// @param _interval the time interval in seconds
    function setTimeIntervalForRewards(uint256 _interval)
        external
        virtual
        override
        onlyOwner
    {
        require(_interval > 0, "NFTScalping: interval must be greater than 0");
        uint oldInterval = timeIntervalForRewards;
        timeIntervalForRewards = _interval * 1 days;
        emit TimeIntervalForRewardsChanged(oldInterval, timeIntervalForRewards);
    }

    /// @notice function to set the scalper NFT address
    /// @param _scalperNFT address of the scalper NFT
    function setScalperNFT(address _scalperNFT)
        external
        virtual
        override
        onlyOwner
    {
        require(
            _scalperNFT != address(0),
            "NFTScalping: _scalperNFT address can not be zero"
        ); // E0: addr err
        scalperNFT = IScalperNFT(_scalperNFT);
    }

    /// @notice function to set the address of the radius token
    /// @param _radiusToken address of the Radius token
    function setRadiusToken(address _radiusToken)
        external
        virtual
        override
        onlyOwner
    {
        require(
            _radiusToken != address(0),
            "NFTScalping: _radiusToken address can not be zero"
        ); // E0: addr err
        radiusToken = IRadius(_radiusToken);
    }

    /// @notice function to withdraw the AVAX amount earned by the owner
    function withdraw() external override onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }

    /// @notice function to withdraw the token
    function withdrawTokens(IERC20 token) external override onlyOwner {
        uint256 balance = token.balanceOf(address(this));

        require(balance > 0, "Contract has no balance");
        require(token.transfer(_msgSender(), balance), "Transfer failed");
    }

    // ======== Public functions ========

    /// @notice used to rent the NFT
    /// @param tokenId ID of the NFT
    /// @param _rentalLevel number from 0 to 6, level in which to rent
    /// @param _currency AVAX or RADIUS, currency with which the user want to rent
    function rentNFT(
        uint256 tokenId,
        RentalLevels _rentalLevel,
        Currency _currency
    ) external payable virtual override nftExists(tokenId) nonReentrant {
        // check if NFT is rentable
        require(
            scalperNFT.ownerOf(tokenId) == address(this),
            "NFTScalping: This NFT is not available for rent"
        );
        NFTRentInfo memory _nftRentInfo = nftRentInfos[tokenId];
        if (_nftRentInfo.tenant != address(0)) {
            // if rented previously
            require(
                _nftRentInfo.rentalDuration + _nftRentInfo.rentStartTime <
                    block.timestamp,
                "NFTScalping: already rented to another address"
            );
        }

        RentalLevelInfo memory _requestedRentalLevel = rentalLevel[
            uint256(_rentalLevel)
        ];

        require(
            _requestedRentalLevel.level >= 0 && _requestedRentalLevel.level < 6,
            "NFTScalping: rental information not set"
        );
        require(
            _requestedRentalLevel.priceInAvax > 0,
            "NFTScalping: rental information not set"
        );
        require(
            _requestedRentalLevel.priceInRadius > 0,
            "NFTScalping: rental information not set"
        );
        require(
            _requestedRentalLevel.duration > 0,
            "NFTScalping: rental information not set"
        );
        require(
            _requestedRentalLevel.scalpingPercentage > 0,
            "NFTScalping: rental information not set"
        );

        require(
            totalAllocatedpool + _requestedRentalLevel.scalpingPercentage <=
                totalAllocationLimit,
            "NFTScalping: Pool allocation limit reached"
        );
        // perform payment operations
        uint256 price = _currency == Currency.AVAX
            ? _requestedRentalLevel.priceInAvax
            : _requestedRentalLevel.priceInRadius;
        if (_currency == Currency.AVAX) {
            uint256 paymentAmount = msg.value;
            require(
                paymentAmount >= price,
                "NFTScalping: payment insufficient for requested Rental level and duration "
            );
            uint256 refund = paymentAmount - price;
            if (refund > 0) {
                payable(msg.sender).transfer(refund);
            }
        } else {
            // for IRadius
            uint256 allowance = radiusToken.allowance(
                msg.sender,
                address(this)
            );
            require(
                allowance >= price,
                "NFTScalping: price amount not approved"
            );
            radiusToken.transferFrom(msg.sender, address(this), price);
            if (msg.value > 0) {
                payable(msg.sender).transfer(msg.value);
            }
        }

        // set rental info in nftRentInfos
        address sender = _msgSender();
        _nftRentInfo.tokenId = tokenId;
        _nftRentInfo.tenant = sender;
        _nftRentInfo.rentStartTime = block.timestamp;
        _nftRentInfo.rentPaid += price; // needed ?
        _nftRentInfo.rentalDuration = _requestedRentalLevel.duration;
        _nftRentInfo.scalpingPercentage = _requestedRentalLevel
            .scalpingPercentage;
        _nftRentInfo.nextScalpTime = block.timestamp + timeIntervalForRewards;
        nftRentInfos[tokenId] = _nftRentInfo;

        totalAllocatedpool += _nftRentInfo.scalpingPercentage;
        uint256 count = rentCount[sender];
        _rentedNFTs[sender][count] = tokenId;
        _rentedNFTsIndex[tokenId] = count;
        rentCount[sender]++;
        emit NFTRented(tokenId, sender, _currency, price, _rentalLevel);
    }

    /// @notice used to claim the rewards earned by renting NFT
    /// @param tokenId ID of the NFT rented
    function transferRewards(uint256 tokenId) external virtual override {
        NFTRentInfo memory _nftRentInfo = nftRentInfos[tokenId];
        require(
            _nftRentInfo.tenant != address(0),
            "NFTScalping: NFT not on rent"
        );

        require(
            _nftRentInfo.nextScalpTime != 0,
            "NFTScalping: rewards transferred maximum number of times"
        );
        require(
            _nftRentInfo.nextScalpTime <= block.timestamp,
            "NFTScalping: can not transfer rewards before next scalp time"
        );
        uint256 totalRewardsPercentage = 0;
        while (_nftRentInfo.nextScalpTime <= block.timestamp) {
            totalRewardsPercentage += _nftRentInfo.scalpingPercentage;
            _nftRentInfo.nextScalpTime += timeIntervalForRewards;
        }
        if (
            _nftRentInfo.nextScalpTime >
            _nftRentInfo.rentalDuration + _nftRentInfo.rentStartTime
        ) {
            _nftRentInfo.nextScalpTime = 0;
        }

        nftRentInfos[tokenId] = _nftRentInfo;
        uint256 tBalance = radiusToken.balanceOf(address(this));
        uint256 totalRewards = (tBalance * totalRewardsPercentage) /
            DENOMINATOR;
        radiusToken.transfer(_nftRentInfo.tenant, totalRewards);
        emit RewardsTransferred(tokenId, _nftRentInfo.tenant, totalRewards);
    }

    // ======== View only functions ========

    /// @notice used check whether the nft is on rent or not
    function isRentActive(uint256 tokenId)
        external
        view
        override
        nftExists(tokenId)
        returns (bool)
    {
        return nftRentInfos[tokenId].tenant != address(0);
    }

    /// @notice used to get the tenant of rented NFT
    function getTenant(uint256 tokenId)
        external
        view
        override
        nftExists(tokenId)
        returns (address)
    {
        return nftRentInfos[tokenId].tenant;
    }

    /// @notice used to get the token ID of rented NFT by tenant and index
    /// @param tenant address of the tenant
    /// @param index index of the NFT for the tenant
    function rentedByIndex(address tenant, uint256 index)
        external
        view
        virtual
        override
        returns (uint256)
    {
        require(index < rentCount[tenant], "NFTScalping: index out of bounds"); // EI: index out of bounds
        return _rentedNFTs[tenant][index];
    }

    /// @notice used to check if this NFT is rentable
    function isRentable(uint256 tokenId)
        external
        view
        virtual
        override
        nftExists(tokenId)
        returns (bool state)
    {
        NFTRentInfo memory _nftRentInfo = nftRentInfos[tokenId];
        state = (scalperNFT.ownerOf(tokenId) == address(this));

        if (_nftRentInfo.tenant != address(0)) {
            // if previously rented
            state =
                state &&
                (_nftRentInfo.rentalDuration + _nftRentInfo.rentStartTime <
                    block.timestamp);
        }
    }

    /// @notice used to get the end time for rental
    function rentedUntil(uint256 tokenId)
        external
        view
        virtual
        override
        nftExists(tokenId)
        returns (uint256)
    {
        NFTRentInfo memory _nftRentInfo = nftRentInfos[tokenId];
        require(
            _nftRentInfo.tenant != address(0),
            "NFTScalping: NFT not on rent"
        );
        return _nftRentInfo.rentalDuration + _nftRentInfo.rentStartTime;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(INFTScalping).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice used to transfer NFT from this address to an address
    function transfer(address to, uint256 tokenId) external onlyOwner {
        scalperNFT.safeTransferFrom(address(this), to, tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
