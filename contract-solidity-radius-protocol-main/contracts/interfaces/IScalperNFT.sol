// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IScalperNFT is IERC721 {
    // function mint(uint tokenId) external;

    // function mint(address to, uint tokenId) external;
        function mint(
        address _owner,
        string memory _metadata,
        uint256 _count
    ) external;


    function exists(uint256 _tokenId) external view returns (bool);

    function setBaseURI(string memory _baseUri) external;
    function setNFTScalpingAddress(address _nftScalping) external;
}
