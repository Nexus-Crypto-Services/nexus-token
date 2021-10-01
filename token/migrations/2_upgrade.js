const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

// const NexusFolio = artifacts.require('NexusFolio');
const NexusFolio = artifacts.require('NexusFolioV3');

module.exports = async function (deployer) {
  // const existing = await NexusFolio.deployed();
  await upgradeProxy("0xE9bC1E13FD59EF117C9F85c82B1f70b9746bc7F2", NexusFolio, { deployer });
};