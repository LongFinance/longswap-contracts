pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LongToken.sol";


interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to LongSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // LongSwap must mint EXACTLY the same amount of LongSwap LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// LongChef is the master of Long. He can make Long and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once LONG is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract LongChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of LONGs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accLongPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accLongPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. LONGs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that LONGs distribution occurs.
        uint256 accLongPerShare; // Accumulated LONGs per share, times 1e12. See below.
    }

    // The LONG TOKEN!
    LongToken public long;
    // Dev address.
    address public devaddr;
    // Block number when bonus LONG period ends.
    uint256 public bonusEndBlock;
    // LONG tokens created per block.
    uint256 public longPerBlock;
    // Bonus muliplier for early long makers.
    uint256[6] public BONUS_MULTIPLIER = [uint256(10), 9, 8, 7, 6, 5];
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when LONG mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        LongToken _long,
        address _devaddr,
        uint256 _longPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        long = _long;
        devaddr = _devaddr;
        longPerBlock = _longPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accLongPerShare: 0
        }));
    }

    // Update the given pool's LONG allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        }

        uint256 fromBlockRel = _from.sub(startBlock);
        uint256 toBlockRel = _to.sub(startBlock);
        uint256 totalReward = 0;
        uint256 blocksPerStage = 21000;

        for (uint256 i = 0; i < BONUS_MULTIPLIER.length; i++) {
            // try to find start-stage i
            if (fromBlockRel >= i.mul(blocksPerStage) && fromBlockRel < i.add(1).mul(blocksPerStage)) {
                bool endFound = false;
                for (uint256 j = i; j < BONUS_MULTIPLIER.length; j++) {
                    // try to find end-stage j
                    if (toBlockRel >= j.mul(blocksPerStage) && toBlockRel < j.add(1).mul(blocksPerStage)) { // found end
                        if (i == j) { // start-stage(i) is as same as end-stage(j)
                            totalReward = totalReward.add(toBlockRel.sub(fromBlockRel).mul(BONUS_MULTIPLIER[j]));
                        } else { // add the final stage reward
                            totalReward = totalReward.add(toBlockRel.sub(j.mul(blocksPerStage)).mul(BONUS_MULTIPLIER[j]));
                        }
                        endFound = true;
                        break;
                    } else { // end not found
                        if (i == j) { // the first one(i stage)
                            totalReward = totalReward.add(j.add(1).mul(blocksPerStage).sub(fromBlockRel).mul(BONUS_MULTIPLIER[j]));
                        } else { // not same, add current full stage reward, and the loop will go on
                            totalReward = totalReward.add(blocksPerStage.mul(BONUS_MULTIPLIER[j]));
                        }
                    }
                }
                if (!endFound) { // did not find an end, which means _to > startBlock, too. Add the no-bonus part reward
                    totalReward = totalReward.add(_to.sub(bonusEndBlock));
                }
                break;
            }
        }
        return totalReward;
    }

    // View function to see pending LONGs on frontend.
    function pendingLong(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLongPerShare = pool.accLongPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 longReward = multiplier.mul(longPerBlock);
            accLongPerShare = accLongPerShare.add(longReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accLongPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 longReward = multiplier.mul(longPerBlock);
        long.mint(devaddr, longReward.div(10));
        long.mint(address(this), longReward);
        pool.accLongPerShare = pool.accLongPerShare.add(longReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to LongChef for LONG allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accLongPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeLongTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accLongPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from LongChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accLongPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeLongTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accLongPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe long transfer function, just in case if rounding error causes pool to not have enough LONGs.
    function safeLongTransfer(address _to, uint256 _amount) internal {
        uint256 longBal = long.balanceOf(address(this));
        if (_amount > longBal) {
            long.transfer(_to, longBal);
        } else {
            long.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
