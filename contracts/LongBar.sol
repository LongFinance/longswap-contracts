pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract LongBar is ERC20("LongBar", "xLONG"){
    using SafeMath for uint256;
    IERC20 public long;

    constructor(IERC20 _long) public {
        long = _long;
    }

    // Enter the bar. Pay some LONGs. Earn some shares.
    function enter(uint256 _amount) public {
        uint256 totalLong = long.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalLong == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalLong);
            _mint(msg.sender, what);
        }
        long.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your LONGs.
    function leave(uint256 _share) public {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(long.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        long.transfer(msg.sender, what);
    }
}