const Nexus = artifacts.require('F');
//0x10ED43C718714eb63d5aA57B78B54704E256024E -> mainnet
// 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 -> pink sale PCS testnet
// 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 -> testnet
module.exports = async function (deployer) {
  await deployer.deploy(Nexus, "0xD99D1c33F9fC3444f8101754aBC46c52416550D1", 5 * 60);
};