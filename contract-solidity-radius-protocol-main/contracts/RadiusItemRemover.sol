// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

interface RadiusNft {
    function exists(uint256 _id) external returns (bool);
}

contract RadiusItemRemover is Ownable {
    RadiusNft private nft;

    /// @notice a mapping to store the visibility status of NFTs
    mapping(uint256 => bool) public hidden;

    event RemoveNft(uint256 id);
    event AddNft(uint256 id);

    constructor(address _nft) {
        nft = RadiusNft(_nft);
    }

    /// @notice used to hide multiple NFTs at once
    /// @param nfts an array of NFT IDs
    function removeItems(uint256[] memory nfts) external onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            require(nft.exists(nfts[i]), "Item does not exist");
            hidden[nfts[i]] = true;
            emit RemoveNft(nfts[i]);
        }
    }

    /// @notice used to hide single NFT
    /// @param _id the ID of the NFT
    function removeItem(uint256 _id) external onlyOwner {
        require(nft.exists(_id), "Item does not exist");
        hidden[_id] = true;
        emit RemoveNft(_id);
    }

    /// @notice used to unhide multiple NFTs at once
    /// @param nfts an array of nft IDs
    function addItems(uint256[] memory nfts) external onlyOwner {
        for (uint256 i = 0; i < nfts.length; i++) {
            require(nft.exists(nfts[i]), "Item does not exist");
            hidden[nfts[i]] = false;
            emit AddNft(nfts[i]);
        }
    }

    /// @notice used to unhide single NFT
    /// @param _id the ID of the NFT
    function addItem(uint256 _id) external onlyOwner {
        require(nft.exists(_id), "Item does not exist");
        hidden[_id] = false;
        emit AddNft(_id);
    }
}
