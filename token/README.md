# Nexus

This is Nexus Token contract!

<br>

## Setup

This contract is deployed with Openzeppelin and Truffle for upgradeability

After cloning it run:

    $ npm install

Create a new file named `.secret` in the main directory and write the secret phrase from your deployment wallet

Create a new file named `.apKey` in the main directory and write the api-key from BSCscan

<br>

## Test


### Testnet


    npx truffle test --network testnet
### Interact with the contract

Deploy the contract and copy its address

    npx truffle console --network testnet

    let instance = await Nexus.at(address)

    let accounts = await web3.eth.getAccounts()

    let pcs = IUniswapV2Pair.at("0xD99D1c33F9fC3444f8101754aBC46c52416550D1")

    

You can call any contract function after that

<br>

## Deploy procedure and presale

1. Check the address for the UniswapRouter and change it inside the `1_deploy.js` migration
2. Deploy the contract running the migration command
   
        npx truffle migrate --network {NetworkName} --to 1
    
3. Verify the contract running the verification command

        npx truffle run verify {ContractClassName}@{ContractAddress} --network {NetworkName}

4. Activate the function `prepareForPreSale` so all taxes get turned off
5. Change the marketing wallet for the correct one adn exclude from fee using `excludeFromFee`
6. Fill the VIP list with all the VIP, Whitelist and private-sale addresses using `addToVIP`
7. Create the pre-sale in [PinkSale](https://www.pinksale.finance/) filling all the information, whitelist and paying the fee
8. Set the presale Address 
9. After pre-sale is finalized and liquidity is created no one will be able to buy or sell yet. To officially open the VIP market call `afterPreSale`
10. Let it pass some good 30 seconds and then disable the VIP market using `toggleVipMarket`. At this point anybody will be able to buy and sell
11. After guarantee that everything is running smoothly transfer the contract to gnosis safe

**IMPORTANT: DON'T FORGET TO LOWER THE MAX TX AMOUNT AS THE PRICE GOES UP AND RAISE IT AS THE PRICE GOES DOWN! MAKE SURE THE CORRECT UNISWAP ROUTER IS IN USE!** 

<br>

## Tokenomics

Total Supply: 10,000,000 (ten million)

Initial max transfer amount: 20,000 (twenty thousand)

- 2% Staking
- 2% Marketing
- 1% Liquidity

**Fees only applicable to buys and sells, not transfers

<br>

## Functionalities
This contract have some unique functionalities to protect from bots and make a safer deploy

### Pre-sale and after pre-sale

These two functions enable ease of operation during the critical phase of pre-sale.

`prepareForPreSale`: Removes all fees and anti-bot features. This puts the contract in a pre-sale state in which is impossible to buy and sell in PCS
`afterPreSale`: This will enable the VPI market, restore fees and anti-bot and enable buys and sells on PCS.

This sequence of functions can only be called once so be careful not to call it before time.

### AntiBot

The anti-bot features is a set of functionalities designed to prevent frontrunning and bot buy-sell attacks. This happens in two ways. First there is a cool down period of 10 seconds between buy and sell transaction that don't allow the same wallet to make two buy or sell transactions under 10 seconds. Secondly there is a max limit for buys and sells that is kep low at the first hours of market in order to increase the transaction costs of a buy-sell attack.

It is important to remember that there is a anti-bot list in place that will blacklist any bot if the dev choses so. However all the tokens in possession of a bot can be considered burned tokens since it cannot do transactions anymore.

### VPI Market

This is a simple and yet clever functionality. For the first 5 minutes of open market only addresses that are in the VIP list will be able to buy and sell the tokens. After this 5 minutes the function is disable and cannot be enable again. What determines the initial time of market is the `afterPreSale` function that takes the timestamp from the last block and add 5*60 seconds to it creating the `openAllMarketTime` variable

This functionality only applies to buys and sells on the Uniswap Router set in the contract. Transfers to other wallets is not blocked.