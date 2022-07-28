// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface RadiusStaking {
    function getStake(address _address, uint256 _id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        );
}

contract RadiusStakingNft is ERC721URIStorage, Ownable {
    RadiusStaking private staking;

    uint256 public tokenIdCounter;

    struct Item {
        string image;
        string metadata;
        uint256 count;
    }

    enum Tier {
        TIER_0,
        TIER_1,
        TIER_2,
        TIER_3,
        TIER_4,
        TIER_5,
        TIER_6,
        TIER_7
    }

    mapping(string => bool) private itemExists;
    mapping(string => Tier) private itemTier;
    mapping(string => uint256) private itemPosition;
    mapping(Tier => uint256) public tierUpperLimit;
    mapping(Tier => Item[]) public tierCollection;
    mapping(address => mapping(uint256 => bool)) public hasClaimed;

    string public baseURI;
    uint256 public minimumStakeAmount;
    uint256 public minimumStakeDuration;

    event ItemAddedToTierCollection(
        Tier indexed tier,
        string image,
        string indexed metadata,
        uint256 indexed count
    );
    event Mint(address indexed account, uint256 indexed tokenId);
    event NFTClaimed(
        address indexed account,
        Tier indexed tier,
        uint256 indexed tokenId,
        string metadata
    );

    constructor(
        string memory _name,
        string memory _symbol,
        address _staking
    ) ERC721(_name, _symbol) {
        staking = RadiusStaking(_staking);

        baseURI = "https://ipfs.io/ipfs/";
        minimumStakeAmount = 300000000000 * 10**9;
        minimumStakeDuration = 6;

        tierUpperLimit[Tier.TIER_0] = 3000000000000 * 10**9; // 3 trillion
        tierUpperLimit[Tier.TIER_1] = 10000000000000 * 10**9; // 10 trillion
        tierUpperLimit[Tier.TIER_2] = 25000000000000 * 10**9; // 25 trillion
        tierUpperLimit[Tier.TIER_3] = 50000000000000 * 10**9; // 50 trillion
        tierUpperLimit[Tier.TIER_4] = 100000000000000 * 10**9; // 100 trillion
        tierUpperLimit[Tier.TIER_5] = 500000000000000 * 10**9; // 500 trillion
        tierUpperLimit[Tier.TIER_6] = 1000000000000000 * 10**9; // 1 quadrillion
        // tierUpperLimit[Tier.TIER_7] = 100000000000000000 * 10 ** 9; // 100 quadrillion
    }

    function addToCollection(
        string memory _hash,
        string memory _metadata,
        Tier _tier,
        uint256 _count
    ) external onlyOwner {
        require(_count > 0, "Item count cannot be zero");

        if (itemExists[_hash]) {
            require(
                itemTier[_hash] == _tier,
                "Item already exists in different tier collection"
            );

            uint256 index = itemPosition[_hash];
            Item storage item = tierCollection[_tier][index];
            item.count = item.count + _count;
        } else {
            itemExists[_hash] = true;
            itemTier[_hash] = _tier;
            itemPosition[_hash] = tierCollection[_tier].length;

            tierCollection[_tier].push(Item(_hash, _metadata, _count));
        }

        emit ItemAddedToTierCollection(
            _tier,
            _hash,
            _metadata,
            tierCollection[_tier][itemPosition[_hash]].count
        );
    }

    function removeFromCollection(Tier _tier, uint256 _index)
        external
        onlyOwner
    {
        Item[] storage items = tierCollection[_tier];
        Item memory item = items[_index];

        require(_index < items.length, "Item index not valid");

        items[_index] = items[items.length - 1];
        items.pop();

        delete itemExists[item.image];
        delete itemPosition[item.image];
        delete itemTier[item.image];
    }

    function claimNFT(uint256 _stakeId) external {
        Tier tier = calculateTier(msg.sender, _stakeId);

        require(
            !hasClaimed[msg.sender][_stakeId],
            "Already claimed NFT for stake"
        );
        require(tierCollection[tier].length > 0, "No items in tier");

        hasClaimed[msg.sender][_stakeId] = true;

        uint256 itemId = uint256(
            keccak256(abi.encodePacked(block.timestamp, _stakeId, msg.sender))
        ) % tierCollection[tier].length;
        Item storage item = tierCollection[tier][itemId];
        item.count--;

        if (item.count == 0) {
            uint256 itemIndex = itemPosition[item.image];

            delete itemExists[item.image];
            delete itemPosition[item.image];

            Item[] storage items = tierCollection[tier];
            items[itemIndex] = items[items.length - 1];
            itemPosition[items[itemIndex].image] = itemIndex;
            items.pop();
        }

        uint256 tokenId = ++tokenIdCounter;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, item.metadata);

        emit Mint(msg.sender, tokenId);
        emit NFTClaimed(msg.sender, tier, tokenId, item.metadata);
    }

    function calculateTier(address _address, uint256 _stakeId)
        internal
        view
        returns (Tier)
    {
        (uint256 tAmount, , , uint256 period, , ) = staking.getStake(
            _address,
            _stakeId
        );

        require(
            tAmount >= minimumStakeAmount,
            "Staked amount not eligible for NFT"
        );
        require(
            period >= minimumStakeDuration,
            "Staked duration not eligible for NFT"
        );

        if (tAmount <= tierUpperLimit[Tier.TIER_0]) {
            return Tier.TIER_0;
        } else if (tAmount <= tierUpperLimit[Tier.TIER_1]) {
            return Tier.TIER_1;
        } else if (tAmount <= tierUpperLimit[Tier.TIER_2]) {
            return Tier.TIER_2;
        } else if (tAmount <= tierUpperLimit[Tier.TIER_3]) {
            return Tier.TIER_3;
        } else if (tAmount <= tierUpperLimit[Tier.TIER_4]) {
            return Tier.TIER_4;
        } else if (tAmount <= tierUpperLimit[Tier.TIER_5]) {
            return Tier.TIER_5;
        } else if (tAmount <= tierUpperLimit[Tier.TIER_6]) {
            return Tier.TIER_6;
        } else {
            return Tier.TIER_7;
        }
    }

    function viewTierCollection(Tier _tier)
        external
        view
        returns (Item[] memory)
    {
        return tierCollection[_tier];
    }

    function viewItemPosition(string memory _hash)
        external
        view
        returns (uint256)
    {
        require(itemExists[_hash], "Item does not exist");
        return itemPosition[_hash];
    }

    function viewItemTier(string memory _hash) external view returns (Tier) {
        require(itemExists[_hash], "Item does not exist");
        return itemTier[_hash];
    }

    function setBaseURI(string memory _baseUri) external onlyOwner {
        baseURI = _baseUri;
    }

    function setMinimumStakeDuration(uint256 _minimumStakeDuration)
        external
        onlyOwner
    {
        minimumStakeDuration = _minimumStakeDuration;
    }

    function setMinimumStakeAmount(uint256 _minimumStakeAmount)
        external
        onlyOwner
    {
        minimumStakeAmount = _minimumStakeAmount;
    }

    function setTierUpperLimit(Tier _tier, uint256 _upperLimit)
        external
        onlyOwner
    {
        if (_tier == Tier.TIER_0) {
            require(
                _upperLimit < tierUpperLimit[Tier(uint8(_tier) + 1)],
                "Limit should be less than next tier"
            );
        } else if (_tier == Tier.TIER_7) {
            require(
                _upperLimit > tierUpperLimit[Tier(uint8(_tier) - 1)],
                "Limit should be more than previous tier"
            );
        } else {
            require(
                _upperLimit > tierUpperLimit[Tier(uint8(_tier) - 1)],
                "Limit should be more than previous tier"
            );
            require(
                _upperLimit < tierUpperLimit[Tier(uint8(_tier) + 1)],
                "Limit should be less than next tier"
            );
        }

        tierUpperLimit[_tier] = _upperLimit;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
