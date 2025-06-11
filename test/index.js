const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("test upgrade", async function () {
  it("Should create an auction", async function () {

    const MockNFT = await ethers.getContractFactory("MockNFT");
    const mockNFT = await MockNFT.deploy();
    await mockNFT.waitForDeployment();


    // 1.部署业务合约
    await deployments.fixture("deployNFTAuction");
    const nftAuctionProxy = await deployments.get("NftAuctionUpgradeable");
    // 2.调用createAuction方法创建拍卖
    const nftAuction = await ethers.getContractAt("NftAuctionUpgradeable", nftAuctionProxy.address);

    await nftAuction.createAuction(
      100 * 1000,
      ethers.parseEther("0.01"),
      mockNFT.target, // ethers v6 用 .target 获取地址
      1
    );

    const auction = await nftAuction.auctions(0);
    console.log("拍卖创建成功", auction);

    const implAddress1 = await upgrades.erc1967.getImplementationAddress(nftAuctionProxy.address);

    // 3.升级合约
    await deployments.fixture("upgradeNFTAuction");

    const implAddress2 = await upgrades.erc1967.getImplementationAddress(nftAuctionProxy.address);

    // 4.读取合约的 auction[0]
    const auction2 = await nftAuction.auctions(0);
    console.log("升级后拍卖信息", auction2);
    console.log("implAddress1", implAddress1);
    console.log("implAddress2", implAddress2);

    expect(auction2.startTime).to.equal(auction.startTime);
  });
});
