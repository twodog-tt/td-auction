const { ethers, upgrades } = require("hardhat");

async function upgrade() {
    const AuctionV2 = await ethers.getContractFactory("AuctionV2");
    const proxyAddress = "已部署的 Auction 代理地址";

    const auctionV2 = await upgrades.upgradeProxy(proxyAddress, AuctionV2);
    console.log("Upgrade done, new implementation at:", auctionV2.address);
}

upgrade();
