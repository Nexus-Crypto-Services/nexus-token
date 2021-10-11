# NexusFolio

{Intro Text HERE}

## Setup

This contract is deployed with Openzeppelin and Truffle for upgradeability

After cloning it run:

    $ npm install

Create a new file named `.secret` in the main directory and write the secret phrase from your deployment wallet

Create a new file named `.apKey` in the main directory and write the api-key from BSCscan

** After the deploy on the Main Net is advised to transfer the contract to a safe such gnosis safe (refer to [this](https://forum.openzeppelin.com/t/openzeppelin-upgrades-step-by-step-tutorial-for-hardhat/3580))

## Test

### Local



ganache-cli --fork https://bsc-dataseed1.defibit.io/ -m "$(<.local)"

npx truffle test --network development

### Testnet

## Deploy

    npx truffle migrate --network {NetworkName} --to 1

## Verify

    npx truffle run verify {ContractClassName}@{ContractAddress} --network {NetworkName}


## Tokenomics

Total Supply: 10,000,000 (ten million)

Initial max transfer amount: 20,000 (twenty thousand)

2% Staking
2% Marketing
1% Liquidity


## Functionalities

### Pre-sale and after pre-sale

### Swap and Liquify

### AntiBot

### Redistribution

### Pre sale/After Sale

