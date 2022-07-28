// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface RadiusNft {
    function mint(
        address _owner,
        string memory _metadata,
        uint256 _count
    ) external;

    function ownerOf(uint256 _tokenId) external view returns (address);

    function exists(uint256 _tokenId) external view returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}
