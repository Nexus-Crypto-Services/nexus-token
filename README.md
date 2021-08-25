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

## Upgrade

    npx truffle migrate --network {NetworkName} -f 2

## Tokenomics

Total Supply: 1,000,000,000,000 (one trillion)

Initial max transfer amount: 3,000,000,000 (tree Millionx)

4% Redistribution
2% Marketing
2% Innovation
1% Liquidity


## Functionalities

### Swap and Liquify

### AntiBot

### Redistribution

### Pre sale/After Sale

