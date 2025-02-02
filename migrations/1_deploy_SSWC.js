//SSWC Constants:
const SSWC = artifacts.require("./SimpleSmartWallet.sol");

module.exports = function (deployer) {
  deployer.deploy(SSWC);  //SSWC contract (Basic contract)
};

