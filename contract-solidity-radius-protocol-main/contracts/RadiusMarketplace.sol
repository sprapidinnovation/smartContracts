// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRadius.sol";
import "./interfaces/IRadiusNFT.sol";

contract RadiusMarketplace is Ownable, ReentrancyGuard {
    IRadius private token;
    RadiusNft private nft;

    /// @notice basis point for percentage precision
    /// @notice 100% => 10000, 10% => 1000, 1% => 100
    uint256 private constant DENOMINATOR = 10000;

    /// @notice maximum duration for auction in days
    uint256 public maxAuctionDuration = 14;

    /// @notice minimum bid rise
    uint256 public minBidRise = 500;

    /// @notice enum for acceptable currencies
    enum Currency {
        TOKEN,
        NATIVE
    }

    /// @notice structure to store the sale record
    struct Sale {
        uint256 id;
        address originalOwner;
        uint256 price;
        Currency currency;
    }

    /// @notice structure to store the Auction record
    struct Auction {
        uint256 id;
        address originalOwner;
        uint256 startingBid;
        uint256 startingTime;
        uint256 duration;
        address highestBidder;
        uint256 highestBid;
        Currency currency;
    }

    uint256 public royalty;
    uint256 public mintFee;
    uint256 public minTokenBalance;
    uint256 public saleCounter;
    uint256 public auctionCounter;
    uint256 public tokenRoyaltyReceived;
    uint256 public nativeRoyaltyReceived;
    uint256 public mintFeeReceived;
    uint256 public auctionDurationIncrease;

    mapping(string => bool) public exists;
    mapping(uint256 => Sale) public nftSales;
    mapping(uint256 => Auction) public auctions;

    event NFTPutOnSale(
        uint256 indexed saleId,
        uint256 indexed tokenId,
        uint256 price,
        Currency currency
    );
    event NFTSalePriceUpdated(
        uint256 indexed saleId,
        uint256 tokenId,
        uint256 price,
        Currency currency
    );
    event NFTRemovedFromSale(uint256 indexed saleId, uint256 indexed tokenId);
    event NFTSold(
        uint256 indexed saleId,
        uint256 indexed tokenId,
        uint256 price,
        Currency currency
    );
    event AuctionStart(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 startingBid,
        uint256 startingTime,
        uint256 duration,
        Currency currency
    );
    event AuctionCancel(uint256 indexed auctionId, uint256 indexed tokenId);
    event PlaceBid(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        uint256 bid
    );
    event AuctionEnd(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address highestBidder,
        uint256 highestBid
    );

    modifier isSaleOwner(uint256 _tokenId) {
        require(
            msg.sender == nftSales[_tokenId].originalOwner,
            "Only owner can call"
        );
        _;
    }

    modifier isAuctionOwner(uint256 _tokenId) {
        require(
            msg.sender == auctions[_tokenId].originalOwner,
            "Only owner can call"
        );
        _;
    }

    modifier nftExists(uint256 _tokenId) {
        require(nft.exists(_tokenId), "NFT does not exist");
        _;
    }

    modifier isOnSale(uint256 _tokenId) {
        require(
            nftSales[_tokenId].price > 0 &&
                address(this) == nft.ownerOf(_tokenId),
            "NFT is not on sale"
        );
        _;
    }

    modifier notOnSale(uint256 _tokenId) {
        require(nftSales[_tokenId].price == 0, "NFT is on sale");
        _;
    }

    modifier isOnAuction(uint256 _tokenId) {
        require(
            auctions[_tokenId].startingTime > 0 &&
                address(this) == nft.ownerOf(_tokenId),
            "NFT not being auctioned"
        );
        _;
    }

    modifier notOnAuction(uint256 _tokenId) {
        require(
            auctions[_tokenId].startingTime == 0,
            "NFT already being auctioned"
        );
        _;
    }

    constructor(
        address _nft,
        address _token,
        uint256 _mintFee,
        uint256 _minTokenBalance,
        uint256 _royalty,
        uint256 _auctionDurationIncrease
    ) {
        token = IRadius(_token);
        nft = RadiusNft(_nft);
        mintFee = _mintFee;
        minTokenBalance = _minTokenBalance;
        royalty = _royalty;
        auctionDurationIncrease = _auctionDurationIncrease;
    }

    function mint(
        string memory _imageHash,
        string memory _metadata,
        uint256 _count
    ) external payable nonReentrant {
        require(!exists[_imageHash], "Image already exists");
        require(msg.value >= mintFee * _count, "Insufficient funds received");
        require(
            token.balanceOf(msg.sender) >= minTokenBalance,
            "Not enough Radius tokens"
        );

        exists[_imageHash] = true;
        mintFeeReceived += mintFee * _count;
        payable(msg.sender).transfer(msg.value - mintFee * _count);

        nft.mint(msg.sender, _metadata, _count);
    }

    /// @notice used to put an NFT on sale by the owner of NFT
    /// @param _tokenId the id of the NFT
    /// @param _price the price of the NFT
    /// @param _currency it can be AVAX or RadiusCoin
    function putOnSale(
        uint256 _tokenId,
        uint256 _price,
        Currency _currency
    ) external nftExists(_tokenId) notOnSale(_tokenId) notOnAuction(_tokenId) {
        require(_price > 0, "Price cannot be zero");
        require(msg.sender == nft.ownerOf(_tokenId), "Only owner can call");

        nftSales[_tokenId] = Sale(++saleCounter, msg.sender, _price, _currency);

        nft.transferFrom(msg.sender, address(this), _tokenId);

        emit NFTPutOnSale(saleCounter, _tokenId, _price, _currency);
    }

    /// @notice used to update the sale price of an NFT
    /// @param _tokenId the id of the NFT
    /// @param _price the new price of the NFT
    /// @param _currency it can be AVAX or RadiusCoin
    function updateSalePrice(
        uint256 _tokenId,
        uint256 _price,
        Currency _currency
    ) external nftExists(_tokenId) isSaleOwner(_tokenId) isOnSale(_tokenId) {
        require(_price > 0, "Price cannot be zero");

        nftSales[_tokenId].price = _price;
        nftSales[_tokenId].currency = _currency;

        emit NFTSalePriceUpdated(
            nftSales[_tokenId].id,
            _tokenId,
            _price,
            _currency
        );
    }

    /// @notice used to remove the NFT from sale
    /// @param _tokenId the id of the NFT
    function removeFromSale(uint256 _tokenId)
        external
        nftExists(_tokenId)
        isSaleOwner(_tokenId)
        isOnSale(_tokenId)
    {
        uint256 saleId = nftSales[_tokenId].id;
        delete nftSales[_tokenId];

        nft.transferFrom(address(this), msg.sender, _tokenId);

        emit NFTRemovedFromSale(saleId, _tokenId);
    }

    /// @notice used to buy the NFT
    /// @param _tokenId the id of the NFT
    function buyNft(uint256 _tokenId)
        external
        payable
        nonReentrant
        nftExists(_tokenId)
        isOnSale(_tokenId)
    {
        require(
            nftSales[_tokenId].currency == Currency.TOKEN ||
                msg.value >= nftSales[_tokenId].price,
            "Insufficient funds sent"
        );

        address originalOwner = nftSales[_tokenId].originalOwner;
        uint256 price = nftSales[_tokenId].price;
        uint256 royaltyFee = (price * royalty) / DENOMINATOR;
        uint256 saleId = nftSales[_tokenId].id;
        Currency currency = nftSales[_tokenId].currency;

        delete nftSales[_tokenId];

        if (currency == Currency.NATIVE) {
            payable(originalOwner).transfer(price - royaltyFee);
            payable(msg.sender).transfer(msg.value - price);

            nativeRoyaltyReceived += royaltyFee;
        } else {
            token.transferFrom(msg.sender, originalOwner, price - royaltyFee);
            token.transferFrom(msg.sender, address(this), royaltyFee);
            payable(msg.sender).transfer(msg.value);

            tokenRoyaltyReceived += royaltyFee;
        }

        nft.transferFrom(address(this), msg.sender, _tokenId);

        emit NFTSold(saleId, _tokenId, price, currency);
    }

    /// @notice used to start the auction
    /// @param _tokenId the id of the token
    /// @param _startingBid ??
    /// @param _duration the duration of the auction in seconds
    /// @param _currency the currency AVAX or RadiusCoin
    function startAuction(
        uint256 _tokenId,
        uint256 _startingBid,
        uint256 _duration,
        Currency _currency
    ) external nftExists(_tokenId) notOnSale(_tokenId) notOnAuction(_tokenId) {
        require(msg.sender == nft.ownerOf(_tokenId), "Only owner can call");
        require(_duration <= maxAuctionDuration, "Decrease auction duration");

        auctions[_tokenId] = Auction(
            ++auctionCounter,
            msg.sender,
            _startingBid,
            block.timestamp,
            _duration * 1 days,
            address(0),
            0,
            _currency
        );

        nft.transferFrom(msg.sender, address(this), _tokenId);

        emit AuctionStart(
            auctionCounter,
            _tokenId,
            _startingBid,
            block.timestamp,
            _duration * 1 days,
            _currency
        );
    }

    /// @notice used to delete the auction of NFT
    /// @param _tokenId the id of the NFT
    function deleteAuction(uint256 _tokenId)
        external
        nftExists(_tokenId)
        isAuctionOwner(_tokenId)
        isOnAuction(_tokenId)
    {
        require(
            auctions[_tokenId].highestBid == 0,
            "Cannot delete once bid is placed"
        );

        uint256 auctionId = auctions[_tokenId].id;
        delete auctions[_tokenId];

        nft.transferFrom(address(this), msg.sender, _tokenId);

        emit AuctionCancel(auctionId, _tokenId);
    }

    /// @notice used to place the Bid for the NFT
    /// @param _tokenId the id of the NFT
    /// @param _bid the amount of bid placed for the NFT
    function placeBid(uint256 _tokenId, uint256 _bid)
        external
        payable
        nonReentrant
        nftExists(_tokenId)
        isOnAuction(_tokenId)
    {
        Auction storage item = auctions[_tokenId];

        uint256 bid = item.currency == Currency.NATIVE ? msg.value : _bid;
        uint256 auctionEndTime = item.startingTime + item.duration;

        require(bid >= nextAllowedBid(_tokenId), "Increase bid");
        require(block.timestamp <= auctionEndTime, "Auction duration ended");

        uint256 prevBid = item.highestBid;
        address prevBidder = item.highestBidder;

        item.highestBid = bid;
        item.highestBidder = msg.sender;

        if (block.timestamp >= auctionEndTime - 10 minutes) {
            item.duration += auctionDurationIncrease * 1 minutes;
        }

        if (item.currency == Currency.NATIVE) {
            payable(prevBidder).transfer(prevBid);
        } else {
            if (prevBidder != address(0)) {
                token.transfer(prevBidder, prevBid);
            }
            // check for eop limit
            token.transferFrom(msg.sender, address(this), bid);
        }

        emit PlaceBid(item.id, _tokenId, bid);
    }

    /// @notice used to claim the NFT
    /// @param _tokenId the id of the token
    function claimAuctionNft(uint256 _tokenId)
        external
        nonReentrant
        nftExists(_tokenId)
        isOnAuction(_tokenId)
    {
        Auction memory item = auctions[_tokenId];

        require(
            (msg.sender == item.highestBidder &&
                block.timestamp > item.startingTime + item.duration) ||
                msg.sender == item.originalOwner,
            "Only highest bidder or owner can call"
        );

        Currency currency = item.currency;
        address originalOwner = item.originalOwner;
        uint256 highestBid = item.highestBid;
        address highestBidder = item.highestBidder;
        uint256 royaltyFee = (highestBid * royalty) / DENOMINATOR;
        uint256 auctionId = auctions[_tokenId].id;

        delete auctions[_tokenId];

        if (currency == Currency.NATIVE) {
            payable(originalOwner).transfer(highestBid - royaltyFee);

            nativeRoyaltyReceived += royaltyFee;
        } else {
            token.transfer(originalOwner, highestBid - royaltyFee);

            tokenRoyaltyReceived += royaltyFee;
        }

        nft.transferFrom(address(this), highestBidder, _tokenId);

        emit AuctionEnd(auctionId, _tokenId, highestBidder, highestBid);
    }

    // ------------ VIEW FUNCTIONS ------------

    /// @notice used to check whether the user can claim auction or not
    /// @param _address address of the user
    /// @param _tokenId the ID of the NFT
    function canClaimAuctionNft(address _address, uint256 _tokenId)
        external
        view
        nftExists(_tokenId)
        isOnAuction(_tokenId)
        returns (bool)
    {
        Auction memory item = auctions[_tokenId];
        return (item.highestBid > 0 &&
            ((block.timestamp > item.startingTime + item.duration &&
                _address == item.highestBidder) ||
                _address == item.originalOwner));
    }

    /// @notice used to get the next bid that is allowed
    /// @param _tokenId the id of the NFT
    function nextAllowedBid(uint256 _tokenId)
        public
        view
        nftExists(_tokenId)
        isOnAuction(_tokenId)
        returns (uint256)
    {
        Auction memory item = auctions[_tokenId];
        return
            item.highestBid == 0
                ? item.startingBid
                : item.highestBid +
                    (item.highestBid * minBidRise) /
                    DENOMINATOR;
    }

    // ------------ ONLY OWNER FUNCTIONS ------------

    /// @notice used to update the mint fees only by the owner
    function updateMintFee(uint256 _mintFee) external onlyOwner {
        mintFee = _mintFee;
    }

    /// @notice used to update the royalty fees by the owner
    /// @param _royaltyFee the royalty fees
    function updateRoyaltyFee(uint256 _royaltyFee) external onlyOwner {
        require(_royaltyFee != royalty, "already set");
        royalty = _royaltyFee;
    }

    /// @notice used to update the max auction duration by the owner
    /// @param _duration the maximum duration of the auction
    function updateMaxAuctionDuration(uint256 _duration) external onlyOwner {
        require(maxAuctionDuration != _duration, "already set");
        maxAuctionDuration = _duration;
    }

    /// @notice used to update the minimum bid rise only by the owner
    /// @param _bidRise the amount of bid to rise by
    function updateMinBidRise(uint256 _bidRise) external onlyOwner {
        require(minBidRise != _bidRise, "already set");
        minBidRise = _bidRise;
    }

    /// @notice used to update the auction duration only by the owner
    /// @param _auctionDurationIncrease the duration of the auction
    function updateAuctionDurationIncrease(uint256 _auctionDurationIncrease)
        external
        onlyOwner
    {
        require(
            auctionDurationIncrease != _auctionDurationIncrease,
            "alread set"
        );
        auctionDurationIncrease = _auctionDurationIncrease;
    }

    /// @notice used to update the minimum token balance
    /// @param _minTokenBalance the minimum amount of token balance to update by
    function updateMinimumTokenBalance(uint256 _minTokenBalance)
        external
        onlyOwner
    {
        require(minTokenBalance != _minTokenBalance, "already set");
        minTokenBalance = _minTokenBalance;
    }

    /// @notice used to withdraw the royalty earned only by the owner
    /// @param _address the address to send the royalty
    function withdrawRoyalty(address payable _address) external onlyOwner {
        require(_address != address(0), "Address cannot be zero address");

        _address.transfer(nativeRoyaltyReceived);
        token.transfer(_address, tokenRoyaltyReceived);
    }

    receive() external payable {}
}
