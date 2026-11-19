const CloneFactory = artifacts.require('./DeployClone.sol');
const ImplementationTemplate = artifacts.require('./SmartSweeperAccount.sol');
const MockTRC20 = artifacts.require('MockTRC20');
const { TronWeb } = require('tronweb');

const tronWeb = new TronWeb({
  fullHost: 'https://nile.trongrid.io',
  privateKey: process.env.PRIVATE_KEY_NILE,
});

const TOKEN_NAME = 'Mock Sweeper Token';
const TOKEN_SYMBOL = 'MST';
const TOKEN_SUPPLY = '1000000000000000000000'; // 1000 tokens (18 decimals)
const TOKEN_SWEEP_AMOUNT = '100000000000000000000'; // 100 tokens
const TRX_SWEEP_AMOUNT = 1_000_000; // 1 TRX in SUN

contract('#### TEST: SmartSweeperAccount ####', () => {
  let factoryInstance;
  let templateInstance;
  let mockToken;
  let cloneInstance;
  let ownerAddress;

  before(async () => {
    factoryInstance = await CloneFactory.deployed();
    templateInstance = await ImplementationTemplate.deployed();
    mockToken = await MockTRC20.new(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_SUPPLY);
    ownerAddress = tronWeb.defaultAddress.base58;

    console.log('Factory contract address (base58):', tronWeb.address.fromHex(factoryInstance.address));
    console.log('Template (Asset Sweeper) contract address (base58):', tronWeb.address.fromHex(templateInstance.address));
    console.log('Mock TRC20 token address (base58):', tronWeb.address.fromHex(mockToken.address));

    // Immutable clone args are appended as raw bytes (see Clones._cloneCodeWithImmutableArgs),
    // so the owner address must be packed as its plain 20 bytes, not abi-encoded/padded.
    const ownerArg = `0x${toHexAddress(ownerAddress).slice(2)}`;
    const tx = await factoryInstance.cloneCreateWithArgs(templateInstance.address, ownerArg);
    await waitForConfirmation(tx);
    const deployEvent = await waitForEvent(tx, 'DeployCREATEClone');
    const cloneAddress = `41${deployEvent.result[0].slice(2)}`;
    cloneInstance = await ImplementationTemplate.at(cloneAddress);

    console.log('Clone (Sweeper) contract address (base58):', tronWeb.address.fromHex(cloneAddress));
  });

  describe('Ownership', () => {
    it('should expose the owner address baked in at clone deployment time', async () => {
      const owner = await cloneInstance.owner();
      assert.equal(toHexAddress(owner), toHexAddress(ownerAddress));
    });
  });

  describe('TRX Sweeping', () => {
    it('should let the owner sweep TRX out of the clone', async () => {
      const fundTx = await tronWeb.trx.sendTransaction(tronWeb.address.fromHex(cloneInstance.address), TRX_SWEEP_AMOUNT);
      await waitForConfirmation(fundTx.txid);

      const tx = await cloneInstance.sweepTRX(TRX_SWEEP_AMOUNT, ownerAddress);
      await waitForConfirmation(tx);
      const sweepEvent = await waitForEvent(tx, 'SweepedTRX');

      assert.equal(toHexAddress(sweepEvent.result[0]), toHexAddress(ownerAddress));
      assert.equal(sweepEvent.result[1], String(TRX_SWEEP_AMOUNT));

      const cloneBalance = await tronWeb.trx.getBalance(tronWeb.address.fromHex(cloneInstance.address));
      assert.equal(cloneBalance, 0);
    });
  });

  describe('TRC20 Sweeping', () => {
    it('should let the owner sweep standard TRC20 tokens out of the clone', async () => {
      const fundTx = await mockToken.transfer(cloneInstance.address, TOKEN_SWEEP_AMOUNT);
      await waitForConfirmation(fundTx);

      const tx = await cloneInstance.sweepTRC20(mockToken.address, ownerAddress);
      await waitForConfirmation(tx);
      const sweepEvent = await waitForEvent(tx, 'SweepedToken');

      assert.equal(toHexAddress(sweepEvent.result[0]), toHexAddress(mockToken.address));

      const cloneTokenBalance = await mockToken.balanceOf(cloneInstance.address);
      assert.equal(cloneTokenBalance.toString(), '0');
    });
  });

  describe('USDT-style Sweeping', () => {
    it('should let the owner sweep USDT-style tokens out of the clone', async () => {
      const fundTx = await mockToken.transfer(cloneInstance.address, TOKEN_SWEEP_AMOUNT);
      await waitForConfirmation(fundTx);

      const tx = await cloneInstance.sweepUSDT(mockToken.address, ownerAddress);
      await waitForConfirmation(tx);
      const sweepEvent = await waitForEvent(tx, 'SweepedToken');

      assert.equal(toHexAddress(sweepEvent.result[0]), toHexAddress(mockToken.address));

      const cloneTokenBalance = await mockToken.balanceOf(cloneInstance.address);
      assert.equal(cloneTokenBalance.toString(), '0');
    });
  });

  describe('Rescue Tokens (Implementation Safety Net)', () => {
    it('should let the rescuer recover tokens mistakenly sent to the implementation contract', async () => {
      const fundTx = await mockToken.transfer(templateInstance.address, TOKEN_SWEEP_AMOUNT);
      await waitForConfirmation(fundTx);

      const tx = await templateInstance.rescueTokens(mockToken.address, ownerAddress);
      await waitForConfirmation(tx);

      const implementationBalance = await mockToken.balanceOf(templateInstance.address);
      assert.equal(implementationBalance.toString(), '0');
    });
  });
});

function toHexAddress(address) {
  return tronWeb.address.toHex(address).toLowerCase();
}

async function waitForConfirmation(txID) {
  let attempts = 0;
  while (attempts < 20) {
    const info = await tronWeb.trx.getTransactionInfo(txID);
    if (info && info.id) {
      return info;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
    attempts++;
  }
  throw new Error(`Transaction ${txID} was not confirmed in time`);
}

async function waitForEvent(txID, eventName) {
  let attempts = 0;
  while (attempts < 20) {
    const res = await tronWeb.event.getEventsByTransactionID(txID, { only_unconfirmed: false });
    const match = (res.data || []).find((event) => event.event_name === eventName);
    if (match) {
      return match;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
    attempts++;
  }
  throw new Error(`Event ${eventName} not found for transaction ${txID}`);
}
