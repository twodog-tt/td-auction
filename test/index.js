const { ethers } = require("hardhat");

describe("Starting",async function () {
  it("Should create an auction", async function () {

    const MockNFT = await ethers.getContractFactory("MockNFT");
    const mockNFT = await MockNFT.deploy();
    await mockNFT.waitForDeployment();
    
    const Contract = await ethers.getContractFactory("NftAuction");
    const contract = await Contract.deploy();
    await contract.waitForDeployment();

    await contract.createAuction(
      100 * 1000,
      ethers.parseEther("0.000000000000001"),
      mockNFT.target, // ethers v6 用 .target 获取地址
      1
    );

    const auction = await contract.auctions(0);
    console.log("Auction created:", auction);
  });
});
