// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "./SafeMath.sol";
import "./Address.sol";
import "./Ownable.sol";
import "./IUniswapV2Factory.sol";
import "./IERC20.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";

contract Supernova is IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _owned;

    
}
