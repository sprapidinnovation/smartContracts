// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface IRadius {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function balanceOf(address _address) external view returns (uint256);

    function mint(uint256 _amount) external;

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function isExcluded(address account) external view returns (bool);

    function reflectionFromToken(uint256 _amount, bool _deductFee)
        external
        view
        returns (uint256);
}
