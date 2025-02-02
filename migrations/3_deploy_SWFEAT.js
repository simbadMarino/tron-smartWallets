//SSWC Constants:

const SWFEAT = artifacts.require("./SmartWalletFeatured.sol");



module.exports = function (deployer) {
  deployer.deploy(SWFEAT);  //SWFEAT contract (Basic contract with TRC20 & TRX and extended functions)
};
