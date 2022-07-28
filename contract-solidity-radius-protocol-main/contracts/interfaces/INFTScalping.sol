// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INFTScalping is IERC165 {
    event NFTRented(
        uint256 indexed tokenId,
        address indexed tenant,
        Currency indexed currency,
        uint256 payment,
        RentalLevels
    );

    event RentalTerminated(uint256 indexed tokenId, address indexed tenant);
    event TotalAllocationLimitChanged(
        uint256 indexed oldLimit,
        uint256 indexed newLimit
    );
    event TimeIntervalForRewardsChanged(
        uint256 indexed oldInterval,
        uint256 indexed newInterval
    );
    event RewardsTransferred(
        uint256 indexed tokenId,
        address indexed tenant,
        uint256 totalRewards
    );
    // used for storing rental information for each level
    struct RentalLevelInfo {
        uint256 level; // rental level
        uint256 priceInAvax; // price for renting in AVAX
        uint256 priceInRadius; // price of renting in RADIUS
        uint256 duration; // duration for Renting
        uint256 scalpingPercentage; // percentage rewards
    }

    enum RentalLevels {
        LEVEL0,
        LEVEL1,
        LEVEL2,
        LEVEL3,
        LEVEL4,
        LEVEL5
    }

    // Currency options for payment
    enum Currency {
        AVAX,
        RADIUS
    }

    // used for storing rental information of each NFT
    struct NFTRentInfo {
        uint256 tokenId;
        address tenant; // rented to, otherwise tenant == 0
        uint256 rentalDuration; // time in seconds
        uint256 rentStartTime; // timestamp in unix epoch
        uint256 rentPaid; // rental paid
        uint256 scalpingPercentage; // percentage rewards
        uint256 nextScalpTime; // when rewards will be transferred next
    }

    function isRentActive(uint256 tokenId) external view returns (bool);

    function getTenant(uint256 tokenId) external view returns (address);

    function rentedByIndex(address tenant, uint256 index)
        external
        view
        returns (uint256);

    function isRentable(uint256 tokenId) external view returns (bool state);

    function rentedUntil(uint256 tokenId) external view returns (uint256);

    function rentNFT(
        uint256 tokenId,
        RentalLevels _rentalLevel,
        Currency _currency
    ) external payable;

    function terminateRental(uint256 tokenId) external;

    function setRentalInformation(
        RentalLevels _rentalLevel,
        uint256 _priceInAvax,
        uint256 _priceInRadius,
        uint256 _duration,
        uint256 _scalpingPercentage
    ) external;

    function transferRewards(uint256 tokenId) external;

    function setTotalAllocationLimit(uint256 _limit) external;

    function setTimeIntervalForRewards(uint256 _interval) external;

    function setScalperNFT(address _scalperNFT) external;

    function setRadiusToken(address _radiusToken) external;

    function withdraw() external;

    function withdrawTokens(IERC20 token) external;
}
