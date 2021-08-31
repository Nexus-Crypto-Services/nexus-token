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
        payable(0x7eb1fAb57D9aCEf77403184d81C30a5592b72438);
    address payable public innovationAddress =
        payable(0xCc164Ac80cB42aBf31B5f5590571BBdB37fBB139);
    address payable public liquidityAddress =
        payable(0xCc164Ac80cB42aBf31B5f5590571BBdB37fBB139);
    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => uint256) private _addressToLastSwapTime;

    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0); //that is the max value in the type of uint256
    uint256 private _tTotal = 1000000000 * 10**3 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private constant _name = "Nexus";
    string private constant _symbol = "$NEXUS";
    uint8 private _decimals = 9;
    uint256 public taxFee = 3;
    uint256 private _previousTaxFee = taxFee;
    uint256 public liquidityFee = 5;
    uint256 private _previousLiquidityFee = liquidityFee;
    uint256 public marketingDivisor = 2;
    uint256 public innovationDivisor = 2;
    uint256 public liquidityDivisor = 1;
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

        _rOwned[_msgSender()] = _rTotal;

        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        ); //testNet

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
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
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
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

    function deliver(uint256 tAmount) public onlyOwner {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
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
        if (
            to == uniswapV2Pair && // Sell
            (from != owner() && from != address(this)) &&
            antiBot
        ) {
            uint256 lastSwapTime = _addressToLastSwapTime[from];
            require(
                _timestamp - lastSwapTime >= lockedBetweenSells,
                "Lock time has not been released from last swap"
            );
            _addressToLastSwapTime[from] = block.timestamp;
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

        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapTokens(uint256 contractTokenBalance) private lockTheSwap {
        uint256 liqTokens = contractTokenBalance
            .div(liquidityFee)
            .mul(liquidityDivisor)
            .div(2);
        swapTokensForEth(contractTokenBalance.sub(liqTokens));

        uint256 maketingBNBShare = address(this).balance.div(liquidityFee).mul(
            marketingDivisor
        );

        uint256 innovationBNBShare = address(this)
            .balance
            .div(liquidityFee)
            .mul(innovationDivisor);

        uint256 liquidityBNBShare = address(this)
            .balance
            .sub(maketingBNBShare)
            .sub(maketingBNBShare);
        //Send to Marketing address
        transferToAddressETH(marketingAddress, maketingBNBShare);
        transferToAddressETH(innovationAddress, innovationBNBShare);
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
        if (!takeFee) removeAllFee();

        _transferStandard(sender, recipient, amount);

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(taxFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(liquidityFee).div(10**2);
    }

    function removeAllFee() private {
        if (taxFee == 0 && liquidityFee == 0) return;

        _previousTaxFee = taxFee;
        _previousLiquidityFee = liquidityFee;

        taxFee = 0;
        liquidityFee = 0;
        
    }

    function restoreAllFee() private {
        taxFee = _previousTaxFee;
        liquidityFee = _previousLiquidityFee;
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

    function setTaxFeePercent(uint256 newFee) external onlyOwner {
        taxFee = newFee;
    }

    function setAntiBot(bool enabledDisable) external onlyOwner {
        antiBot = enabledDisable;
    }

    function setLiquidityFeePercent(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Liquidity fee must be less than 10");
        require(
            marketingDivisor.add(innovationDivisor).add(liquidityDivisor) <=
                newFee,
            "Sum of divisors must be lower than liquidityFee"
        );

        liquidityFee = newFee;
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

    function setMarketingDivisor(uint256 divisor) external onlyOwner {
        require(
            innovationDivisor.add(liquidityDivisor).add(divisor) <=
                liquidityFee,
            "Sum of divisors must be lower than liquidityFee"
        );
        marketingDivisor = divisor;
    }

    function setInnovationDivisor(uint256 divisor) external onlyOwner {
        require(
            marketingDivisor.add(liquidityDivisor).add(divisor) <= liquidityFee,
            "Sum of divisors must be lower than liquidityFee"
        );
        innovationDivisor = divisor;
    }

    function setLiquidityDivisor(uint256 divisor) external onlyOwner {
        require(divisor >= 1, "Divisor must be greater than 1");
        require(
            marketingDivisor.add(innovationDivisor).add(divisor) <=
                liquidityFee,
            "Sum of divisors must be lower than liquidityFee"
        );
        liquidityDivisor = divisor;
    }

    function setNumTokensSellToAddToLiquidity(uint256 _minimumTokensBeforeSwap)
        external
        onlyOwner
    {
        uint256 previous = minimumTokensBeforeSwap;
        minimumTokensBeforeSwap = _minimumTokensBeforeSwap;
        emit UpdateMinimumTokensBeforeSwap(minimumTokensBeforeSwap, previous);
    }

    function setMarketingAddress(address account) external onlyOwner {
        address previous = marketingAddress;
        marketingAddress = payable(account);
        emit UpdateMarketingAddress(marketingAddress, previous);
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
        // taxFee = 0;
        // liquidityFee = 0;
        removeAllFee();
        maxTxAmount = 1000000000 * 10**6 * 10**9;
        antiBot = false;

        lockedBetweenBuys = 0;
        lockedBetweenSells = 0;
    }

    function afterPreSale() external onlyOwner {
        setSwapAndLiquifyEnabled(true);
        // taxFee = 3;
        // liquidityFee = 5;
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