/**
 *Submitted for verification at Etherscan.io on 2020-08-30
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface LongChef {
    function userInfo(uint, address) external view returns (uint, uint);
}

contract LongVoterProxy {

    IERC20 public constant votes = IERC20(0x8F224BA738572ded533B4386b077033E21683D7d); //LONG-ETH
    LongChef public constant chef = LongChef(0x324c8B4C19c467b976014e323b2CF954556BB876);
    uint public constant pool = uint(12);

    function decimals() external pure returns (uint8) {
        return uint8(18);
    }

    function name() external pure returns (string memory) {
        return "LONGPOWER";
    }

    function symbol() external pure returns (string memory) {
        return "LONG";
    }

    function totalSupply() external view returns (uint) {
        return votes.totalSupply();
    }

    function balanceOf(address _voter) external view returns (uint) {
        (uint _votes,) = chef.userInfo(pool, _voter);
        return _votes;
    }

    constructor() public {}
}