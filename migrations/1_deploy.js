const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const NexusFolio = artifacts.require('NexusFolioV3');

module.exports = async function (deployer) {
  await deployProxy(NexusFolio, { deployer, initializer: 'initialize' });
};