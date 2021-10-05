// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "./SafeMath.sol";
import "./Address.sol";
import "./Ownable.sol";
import "./IUniswapV2Factory.sol";
import "./IERC20.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router02.sol";

contract Nexus is IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _owned;

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => uint256) private _addressToLastSwapTime;

    address[] private _excluded;
    address marketAddress;
    uint256 private constant MAX = ~uint256(0); //that is the max value in the type of uint256
    uint256 private _total = 10000000 * 10**9;

    uint256 private _tFeeTotal;

    string private constant _name = "Nexus";
    string private constant _symbol = "$NEXUS";
    uint8 private _decimals = 9;

    uint256 public marketFee = 5;

    uint256 private _previousMarketFee = marketFee;
    uint256 public maxTxAmount = 100000 * 10**9;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool public antiBot = true;

    uint256 public lockedBetweenBuys = 5;
    uint256 public lockedBetweenSells = 5;

    bool isInPresale = false;
    bool presaleDone = false;

    constructor(address uniswap) {
        require(owner() != address(0), "Nexus: owner must be set");

        _owned[_msgSender()] = _total;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(uniswap); 

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        marketAddress = owner();
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
        bool takeFee = true;
        if (
            to == uniswapV2Pair && // Sell
            (from != owner() && from != address(this))
        ) {

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
            uint256 market = amount.mul(marketFee).div(10**2);

            _owned[marketAddress] = _owned[marketAddress].add(market);
            transferAmount = transferAmount.sub(market);
            emit Transfer(sender, marketAddress, market);
        }
        _owned[sender] = _owned[sender].sub(amount);
        _owned[recipient] = _owned[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }

    function removeAllFee() private {
        if (marketFee != 0) {
            _previousMarketFee = marketFee;
        } 
            marketFee = 0;
        

        emit UpdateMarketFee(marketFee, _previousMarketFee);
    }

    function restoreAllFee() private {
        marketFee = _previousMarketFee;

        emit UpdateMarketFee(marketFee, _previousMarketFee);
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

    function setAntiBot() external onlyOwner {
        antiBot = !antiBot;

        emit UpdateAntibotEnabled( antiBot);
    }

    function setMarketFeePercent(uint256 newFee) external onlyOwner {
        require(newFee <= 5, "Marketing fee must be less than 5");
        _previousMarketFee = marketFee;
        marketFee = newFee;
        emit UpdateMarketFee(marketFee, _previousMarketFee);
    }

    function setLockTimeBetweenSells(uint256 newLockSeconds)
        external
        onlyOwner
    {
        require(newLockSeconds <= 15, "Time between sells must be less than 15 seconds");
        uint256 _previous = lockedBetweenSells;
        lockedBetweenSells = newLockSeconds;

        emit UpdateLockedBetweenSells(lockedBetweenSells, _previous);
    }

    function setLockTimeBetweenBuys(uint256 newLockSeconds) external onlyOwner {
        require(newLockSeconds <= 15, "Time between buys be less than 15 seconds");
        uint256 _previous = lockedBetweenBuys;
        lockedBetweenBuys = newLockSeconds;
        emit UpdateLockedBetweenBuys(lockedBetweenBuys, _previous);
    }

    function setMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        maxTxAmount = newMaxTxAmount;
    }

    function prepareForPreSale() external onlyOwner {
        require(!presaleDone, "Presale already done");
        
        removeAllFee();
        maxTxAmount = 2000000* 10**9;
        antiBot = false;

        lockedBetweenBuys = 0;
        lockedBetweenSells = 0;

        isInPresale = true;
    }

    function afterPreSale() external onlyOwner {
        require(isInPresale, "Not in presale phase");

        restoreAllFee();
        maxTxAmount = 40000 * 10**9;
        antiBot = true;

        lockedBetweenBuys = 15;
        lockedBetweenSells = 15;
        
        isInPresale = false;
        presaleDone = true;
    }

    function setMarketAddress(address market) public onlyOwner {
        address _previousMarketAddress = marketAddress;
        marketAddress = market;
        emit UpdateMarketAddress(marketAddress, _previousMarketAddress);
    }

    event UpdateMarketFee(uint256 marketFee, uint256 _previousMarketFee);

    event UpdateMarketAddress(address marketAddress, address previous);

    event UpdateMaxTxAmout(uint256 maxTxAmount, uint256 previous);
    event UpdateAntibotEnabled(bool enabled);
    event UpdateLockedBetweenBuys(uint256 cooldown, uint256 previous);
    event UpdateLockedBetweenSells(uint256 cooldown, uint256 previous);
}
