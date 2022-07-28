// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RadiusNft is ERC721URIStorage, Ownable {
    string public baseURI;
    uint256 public tokenCounter;
    address public marketplaceAddress;

    modifier onlyMarketplace() {
        require(
            msg.sender == marketplaceAddress,
            "Caller not marketplace contract"
        );
        _;
    }

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {
        baseURI = "https://ipfs.io/ipfs/";
    }

    /// @notice mint the NFTs
    /// @param _owner address of the owner of NFTs
    /// @param _metadata the data about the NFTs
    /// @param _count number of NFTs to mint for that metadata
    function mint(
        address _owner,
        string memory _metadata,
        uint256 _count
    ) external onlyMarketplace {
        for (uint256 i = 0; i < _count; i++) {
            _safeMint(_owner, ++tokenCounter);
            _setTokenURI(tokenCounter, _metadata);
        }
    }

    /// @notice check whether the NFT exists
    /// @param _tokenId id of the NFT
    /// @return Boolean value true if NFT exists otherwise false
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    /// @notice sets the new marketplace address
    /// @param _marketplaceAddress address of the marketplace
    function setMarketplaceAddress(address _marketplaceAddress)
        external
        onlyOwner
    {
        require(
            _marketplaceAddress != address(0),
            "marketplace address is zero"
        );
        require(
            _marketplaceAddress.code.length > 0,
            "marketplace address is not a contract"
        );
        require(
            _marketplaceAddress != marketplaceAddress,
            "marketplace address already set"
        );
        marketplaceAddress = _marketplaceAddress;
    }

    /// @notice sets the new base URI for the NFTs
    /// @param _baseUri the new base URI
    function setBaseURI(string memory _baseUri) external onlyOwner {
        baseURI = _baseUri;
    }

    /// @notice function to get the current base URI
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
