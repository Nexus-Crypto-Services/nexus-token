const Nexus = artifacts.require('Nexus');
//0x10ED43C718714eb63d5aA57B78B54704E256024E
module.exports = async function (deployer) {
  await deployer.deploy(Nexus, "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3");
};