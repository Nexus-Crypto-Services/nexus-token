// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "./SafeMath.sol";
import "./Address.sol";
import "./Ownable.sol";
import "./IUniswapV2Factory.sol";
import "./IERC20.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";

contract NexusFolio is IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    address payable public marketingAddress =
        payable(0xCc164Ac80cB42aBf31B5f5590571BBdB37fBB139);

    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _owned;

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => uint256) private _addressToLastSwapTime;

    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0); //that is the max value in the type of uint256
    uint256 private _total = 10000000 * 10**9;

    uint256 private _tFeeTotal;

    string private constant _name = "Nexus";
    string private constant _symbol = "$NEXUS";
    uint8 private _decimals = 9;

    uint256 public marketingFee = 1;
    uint256 public liquidityFee = 1;
    uint256 private _previousLiquidityFee = liquidityFee;
    uint256 private _previousMarketingFee = marketingFee;
    uint256 public maxTxAmount = 1000000 * 10**9;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public antiBot = true;

    uint256 public lockedBetweenBuys = 5;
    uint256 public lockedBetweenSells = 5;

    constructor() {
        require(owner() != address(0), "NexusFolio: owner must be set");

        _owned[_msgSender()] = _total;

        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        ); //testNet

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _total);
    }

    function setRouterAddress(address newRouter) public onlyOwner {
        IUniswapV2Router02 _newPancakeRouter = IUniswapV2Router02(newRouter);

        uniswapV2Pair = IUniswapV2Factory(_newPancakeRouter.factory())
            .createPair(address(this), _newPancakeRouter.WETH());
        uniswapV2Router = _newPancakeRouter;
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _total;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _owned[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 _timestamp = block.timestamp;
        bool takeFee = false;
        if (
            to == uniswapV2Pair && // Sell
            (from != owner() && from != address(this))
        ) {
            takeFee = true;
            if (antiBot) {
                uint256 lastSwapTime = _addressToLastSwapTime[from];
                require(
                    _timestamp - lastSwapTime >= lockedBetweenSells,
                    "Lock time has not been released from last swap"
                );
                _addressToLastSwapTime[from] = block.timestamp;
            }
        }

        if (
            from == uniswapV2Pair && // buys
            (to != owner() && to != address(this)) &&
            antiBot
        ) {
            uint256 lastSwapTime = _addressToLastSwapTime[to];
            require(
                _timestamp - lastSwapTime >= lockedBetweenBuys,
                "Lock time has not been released from last swap"
            );
            _addressToLastSwapTime[to] = block.timestamp;
        }

        if (from != owner() && to != owner()) {
            require(
                amount <= maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        }

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        _tokenTransfer(from, to, amount, takeFee);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        uint256 transferAmount = amount;
        if (takeFee) {
            uint256 liquidity = amount.mul(liquidityFee).div(10**2);
            uint256 marketing = amount.mul(marketingFee).div(10**2);
            _owned[address(this)] = _owned[address(this)].add(liquidity);
            _owned[marketingAddress] = _owned[marketingAddress].add(marketing);
            transferAmount = transferAmount.sub(liquidity).sub(marketing);
        }
        _owned[sender] = _owned[sender].sub(amount);
        _owned[recipient] = _owned[recipient].add(transferAmount);
    }

    function removeAllFee() private {
        if (liquidityFee != 0) {
            _previousLiquidityFee = liquidityFee;
        } else {
            liquidityFee = 0;
        }
        if (marketingFee != 0) {
            _previousMarketingFee = marketingFee;
        } else {
            marketingFee = 0;
        }
    }

    function restoreAllFee() private {
        liquidityFee = _previousLiquidityFee;
        marketingFee = _previousMarketingFee;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setAntiBot(bool enabledDisable) external onlyOwner {
        antiBot = enabledDisable;
    }

    function setLiquidityFeePercent(uint256 newFee) external onlyOwner {
        require(newFee <= 5, "Liquidity fee must be less than 10");

        liquidityFee = newFee;
    }

    function setMarketingFeePercent(uint256 newFee) external onlyOwner {
        require(newFee <= 2, "Liquidity fee must be less than 10");

        marketingFee = newFee;
    }

    function setLockTimeBetweenSells(uint256 newLockSeconds)
        external
        onlyOwner
    {
        require(newLockSeconds <= 15, "Liquidity fee must be less than 15");
        lockedBetweenSells = newLockSeconds;
    }

    function setLockTimeBetweenBuys(uint256 newLockSeconds) external onlyOwner {
        require(newLockSeconds <= 15, "Liquidity fee must be less than 15");
        lockedBetweenBuys = newLockSeconds;
    }

    function setMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        maxTxAmount = newMaxTxAmount;
    }

    function prepareForPreSale() external onlyOwner {
        removeAllFee();
        maxTxAmount = 5000000 * 10**9;
        antiBot = false;

        lockedBetweenBuys = 0;
        lockedBetweenSells = 0;
    }

    function afterPreSale() external onlyOwner {
        restoreAllFee();
        maxTxAmount = 1000000 * 10**9;
        antiBot = true;

        lockedBetweenBuys = 5;
        lockedBetweenSells = 5;
    }

    event UpdateMarketingFee(
        uint256 marketingFee,
        uint256 _previousMarketingFee
    );
    event UpdateLiquidityFee(uint256 liquidityFee, uint256 previous);
    event UpdateMarketingAddress(address marketingAddress, address previous);
    event UpdateLiquidityAddress(address liquidityAddress, address previous);
    event UpdateMaxTxAmout(uint256 maxTxAmount, uint256 previous);
    event UpdateAntibotEnabled(bool enabled, bool previous);
    event UpdateLockedBetweenBuys(uint256 cooldown, uint256 previous);
    event UpdateLockedBetweenSells(uint256 cooldown, uint256 previous);
}
