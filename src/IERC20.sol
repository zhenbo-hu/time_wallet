// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external returns (uint256);
    function totalSupply() external returns (uint256);
    function balanceOf(address from) external returns (uint256);
}
