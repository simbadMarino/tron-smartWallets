//SSWC Constants:
const SWTRXC = artifacts.require("./SmartWalletTRC20TRX.sol");

module.exports = function (deployer) {
  deployer.deploy(SWTRXC);  //SWTRXC contract (Basic contract with TRC20 & TRX capabilities)
};
