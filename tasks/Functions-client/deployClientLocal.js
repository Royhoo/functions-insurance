const { types } = require("hardhat/config")
const { VERIFICATION_BLOCK_CONFIRMATIONS, networkConfig } = require("../../network-config")

task("functions-deploy-client-local", "Deploys the ParametricInsurance contract")
  .addOptionalParam("verify", "Set to true to verify client contract", false, types.boolean)
  .setAction(async (taskArgs) => {
    if (network.name != "hardhat") {
      throw Error(
        'This command only be used on a local hardhat chain.'
      )
    }

    console.log(`Deploying ParametricInsurance contract to ${network.name}`)

    console.log("\n__Compiling Contracts__")
    await run("compile")

    const clientContractFactory = await ethers.getContractFactory("ParametricInsurance")
    const clientContract = await clientContractFactory.deploy("0xaAE1091eF5e7D262a12bBaf1c3Bf162B2041F26f")
    console.log(`ParametricInsurance contract deployed to ${clientContract.address} on ${network.name}`)

    const txInj = await clientContract.capitalInjection({
      value: ethers.utils.parseEther("0.1"),
    });

    const txPur = await clientContract.purchaseInsurance({
      value: ethers.utils.parseEther("0.01"),
    });

    // const txFulfill = await clientContract.mockFulfill();
    // const txClintDraw = await clientContract.clintDraw();
    // const txCapDraw = await clientContract.capitalDraw();

  })