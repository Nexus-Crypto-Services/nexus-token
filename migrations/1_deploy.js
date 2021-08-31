const NexusFolio = artifacts.require('NexusFolio');

module.exports = async function (deployer) {
  await deployer.deploy(NexusFolio);
};