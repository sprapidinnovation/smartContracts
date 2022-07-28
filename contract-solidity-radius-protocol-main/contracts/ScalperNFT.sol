// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IScalperNFT.sol";

/// @title A Scalper NFT contract
/// @notice Scalper NFTs are NFTs which will be minted by the NFT Scalping Contract
/// @notice scalper NFTs are put on rent by the owner and the tenant earns rewards
contract ScalperNFT is IScalperNFT, ERC721URIStorage, Ownable {
    using Address for address;

    string public baseURI;

    /// @notice address of NFTScalping contract
    address private _NFTScalpingAddress;

    /// @notice count of minted NFTs
    uint256 public tokenCounter;

    modifier onlyNFTScalping() {
        require(
            msg.sender == _NFTScalpingAddress,
            "Caller not NFTScalping contract"
        );
        _;
    }

    event NFTScalpingAddressChanged(
        address indexed oldAddress,
        address indexed newAddress
    );

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {
        baseURI = "https://ipfs.io/ipfs/";
    }

    /// @notice function to mint NFTs, can be called by owner only
    /// @notice only the Scalping Contract can mint the NFT
    /// @param _owner address of owner of the NFT
    /// @param _metadata data about the NFTs
    /// @param _count number of NFTs to mint
    function mint(
        address _owner,
        string memory _metadata,
        uint256 _count
    ) external override onlyNFTScalping {
        require(_owner != address(0), "owner cannot be zero address");
        for (uint256 i = 0; i < _count; i++) {
            _safeMint(_owner, tokenCounter + i);
            _setTokenURI(tokenCounter + i, _metadata);
        }
        tokenCounter += _count;
    }

    /// @notice used to check if NFT exists
    function exists(uint256 _tokenId) external view override returns (bool) {
        return _exists(_tokenId);
    }

    /// @notice function to set the NFT scalping contract address
    /// @param _nftScalping address of the NFT scalping contract
    function setNFTScalpingAddress(address _nftScalping)
        external
        override
        onlyOwner
    {
        require(
            _nftScalping != address(0),
            "ScalperNFT:  NFTScalping address cannot be zero"
        );
        require(
            _nftScalping.code.length > 0,
            "ScalperNFT: address is not a contract"
        );
        address oldAddress = _NFTScalpingAddress;
        _NFTScalpingAddress = _nftScalping;
        emit NFTScalpingAddressChanged(oldAddress, _nftScalping);
    }

    /// @notice used to set the base URI of the NFT
    function setBaseURI(string memory _baseUri) external override onlyOwner {
        baseURI = _baseUri;
    }

    /// @notice used to fetch the current base URI
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /// @notice emergency function to withdraw native currency
    function emergencyWithdraw(address _to) external onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    /// @notice emegency function to withdraw ERC20 tokens
    function emergencyTokenWithdraw(address _token, address _to)
        external
        onlyOwner
    {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance > 0, "ScalperNFT: no tokens to withdraw");
        IERC20(_token).transfer(_to, balance);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IScalperNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
