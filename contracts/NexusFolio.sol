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

    address payable public innovationAddress =
        payable(0xCc164Ac80cB42aBf31B5f5590571BBdB37fBB139);
    address payable public liquidityAddress =
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
    uint256 private _total = 1000000000 * 10**3 * 10**9;

    uint256 private _tFeeTotal;

    string private constant _name = "Nexus";
    string private constant _symbol = "$NEXUS";
    uint8 private _decimals = 9;

    uint256 public innovationFee = 1;
    uint256 public liquidityFee = 1;
    uint256 private _previousLiquidityFee = liquidityFee;
    uint256 private _previousInnovationFee = innovationFee;
    uint256 public maxTxAmount = 3000000 * 10**3 * 10**9;

    uint256 private minimumTokensBeforeSwap = 200 * 10**3 * 10**9;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;
    bool public antiBot = true;

    uint256 public swapAndLiquifyCooldown = 30;
    uint256 private _lastSwapAndLiquifyTimestap;

    uint256 public lockedBetweenBuys = 5;
    uint256 public lockedBetweenSells = 5;

    event RewardLiquidityProviders(uint256 tokenAmount);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SwapETHForTokens(uint256 amountIn, address[] path);

    event SwapTokensForETH(uint256 amountIn, address[] path);

    event UpdateTaxFee(uint256 taxFee, uint256 _previousTaxFee);
    event UpdateLiquidityFee(uint256 liquidityFee, uint256 previous);
    event UpdateMarketingDivisor(uint256 marketingDivisor, uint256 previous);
    event UpdateInnovationDivisor(uint256 innovationDivisor, uint256 previous);
    event UpdateLiquidityDivisor(uint256 liquidityDivisor, uint256 previous);
    event UpdateMarketingAddress(address marketingAddress, address previous);
    event UpdateInnovationAddress(address innovationAddress, address previous);
    event UpdateLiquidityAddress(address liquidityAddress, address previous);
    event UpdateMinimumTokensBeforeSwap(
        uint256 minimumTokensBeforeSwap,
        uint256 previous
    );
    event UpdateMaxTxAmout(uint256 maxTxAmount, uint256 previous);
    event UpdateSwapAndLiquifyEnabled(bool enabled, bool previous);
    event UpdateSwapAndLiquifyCooldown(uint256 cooldown, uint256 previous);
    event UpdateAntibotEnabled(bool enabled, bool previous);
    event UpdateLockedBetweenBuys(uint256 cooldown, uint256 previous);
    event UpdateLockedBetweenSells(uint256 cooldown, uint256 previous);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

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

    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
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

        if (
            !inSwapAndLiquify && swapAndLiquifyEnabled && from != uniswapV2Pair
        ) {
            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinimumTokenBalance = contractTokenBalance >=
                minimumTokensBeforeSwap;

            bool overCooldownPeriod = _timestamp.sub(
                _lastSwapAndLiquifyTimestap
            ) >= swapAndLiquifyCooldown;

            if (overMinimumTokenBalance && overCooldownPeriod) {
                swapTokens(minimumTokensBeforeSwap);
                _lastSwapAndLiquifyTimestap = block.timestamp;
            }
        }

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapTokens(uint256 contractTokenBalance) private lockTheSwap {
        uint256 liqTokens = contractTokenBalance.div(2);
        swapTokensForEth(contractTokenBalance.sub(liqTokens));

        uint256 liquidityBNBShare = address(this).balance;
        //Send to Marketing address

        addLiquidity(liqTokens, liquidityBNBShare);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this), // The contract
            block.timestamp
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

    function swapETHForTokens(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(
            0, // accept any amount of Tokens
            path,
            deadAddress, // Burn address
            block.timestamp.add(300)
        );

        emit SwapETHForTokens(amount, path);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityAddress,
            block.timestamp
        );
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
            uint256 innovation = amount.mul(innovationFee).div(10**2);
            _owned[address(this)] = _owned[address(this)].add(liquidity);
            _owned[innovationAddress] = _owned[innovationAddress].add(
                innovation
            );
            transferAmount = transferAmount.sub(liquidity).sub(innovation);
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
        if (innovationFee != 0) {
            _previousInnovationFee = innovationFee;
        } else {
            innovationFee = 0;
        }
    }

    function restoreAllFee() private {
        liquidityFee = _previousLiquidityFee;
        innovationFee = _previousInnovationFee
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

    function setInnovationFeePercent(uint256 newFee) external onlyOwner {
        require(newFee <= 2, "Liquidity fee must be less than 10");

        innovationFee = newFee;
    }

    function setLockTimeBetweenSells(uint256 newLockSeconds)
        external
        onlyOwner
    {
        require(newLockSeconds <= 60, "Liquidity fee must be less than 60");
        lockedBetweenSells = newLockSeconds;
    }

    function setLockTimeBetweenBuys(uint256 newLockSeconds) external onlyOwner {
        require(newLockSeconds <= 60, "Liquidity fee must be less than 60");
        lockedBetweenBuys = newLockSeconds;
    }

    function setSALCooldown(uint256 newCooldown) external onlyOwner {
        require(newCooldown >= 10, "Liquidity fee must be greater than 10");
        swapAndLiquifyCooldown = newCooldown;
    }

    function setMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        maxTxAmount = newMaxTxAmount;
    }

    function setNumTokensSellToAddToLiquidity(uint256 _minimumTokensBeforeSwap)
        external
        onlyOwner
    {
        uint256 previous = minimumTokensBeforeSwap;
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap;
        emit UpdateMinimumTokensBeforeSwap(minimumTokensBeforeSwap, previous);
    }

    function setInnovationAddress(address account) external onlyOwner {
        address previous = innovationAddress;
        innovationAddress = payable(account);
        emit UpdateInnovationAddress(innovationAddress, previous);
    }

    function setLiquidityAddress(address account) external onlyOwner {
        address previous = liquidityAddress;
        liquidityAddress = payable(account);
        emit UpdateLiquidityAddress(liquidityAddress, previous);
    }

    function setSwapAndLiquifyEnabled(bool enabledDisable) public onlyOwner {
        bool previous = swapAndLiquifyEnabled;
        swapAndLiquifyEnabled = enabledDisable;
        emit UpdateSwapAndLiquifyEnabled(enabledDisable, previous);
    }

    function prepareForPreSale() external onlyOwner {
        setSwapAndLiquifyEnabled(false);

        removeAllFee();
        maxTxAmount = 1000000000 * 10**6 * 10**9;
        antiBot = false;

        lockedBetweenBuys = 0;
        lockedBetweenSells = 0;
    }

    function afterPreSale() external onlyOwner {
        setSwapAndLiquifyEnabled(true);

        restoreAllFee();
        maxTxAmount = 3000000 * 10**6 * 10**9;
        antiBot = true;

        lockedBetweenBuys = 5;
        lockedBetweenSells = 5;
    }

    function transferToAddressETH(address payable recipient, uint256 amount)
        private
    {
        recipient.transfer(amount);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}
}
