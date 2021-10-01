# NexusFolio

{Intro Text HERE}

## Setup

This contract is deployed with Openzeppelin and Truffle for upgradeability

After cloning it run:

    $ npm install

Create a new file named `.secret` in the main directory and write the secret phrase from your deployment wallet

Create a new file named `.apKey` in the main directory and write the api-key from BSCscan

** After the deploy on the Main Net is advised to transfer the contract to a safe such gnosis safe (refer to [this](https://forum.openzeppelin.com/t/openzeppelin-upgrades-step-by-step-tutorial-for-hardhat/3580))

## Deploy

    npx truffle migrate --network {NetworkName} --to 1

## Verify

    npx truffle run verify {ContractClassName}@{ContractAddress} --network {NetworkName}


## Tokenomics

Total Supply: 1,000,000,000,000 (one trillion)

Initial max transfer amount: 3,000,000,000 (tree Million)

3% Redistribution
2% Marketing
2% Innovation
1% Liquidity


## Functionalities

### Pre-sale and after pre-sale

In order to automate the precess of pre-sale two functions were put in place: `prepareForPreSale` and `afterPreSale`.

<br>

#### *prepareForPreSale*

This function turns *off* every special transfer feature off and removes all fees of transfer. This *MUST* be called before starting a pre-sale on dxSale. If it is not called the pre-sale will *not* succeed. This can only be called by the contract owner.


#### *afterPreSale*

This function turns *on* every special transfer feature off and adds all fees of transfer. This *MUST* be called  after the pre-sale tokens are transferred, ideally call this immediately after to avoid bots. This can only be called by the contract owner.

### Swap and Liquify

### AntiBot

### Redistribution

### Pre sale/After Sale

