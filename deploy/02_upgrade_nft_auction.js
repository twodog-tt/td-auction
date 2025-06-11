const { ethers , upgrades } = require("hardhat");
const path = require("path");
const fs = require("fs");

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址", deployer);

    const storePath = path.resolve(__dirname, "./.cache/proxyNftAuctionUpgradeable.json");
    const storeData = fs.readFileSync(storePath, "utf8");
    const { proxyAddress, implAddress, abi } = JSON.parse(storeData);

    // 升级版的业务合约
    const NftAuctionUpgradeableV2 = await ethers.getContractFactory("NftAuctionUpgradeableV2");

    // 升级代理合约
    const NftAuctionUpgradeableProxyV2 = await upgrades.upgradeProxy(proxyAddress, NftAuctionUpgradeableV2);
    await NftAuctionUpgradeableProxyV2.waitForDeployment();
    const proxyAddressV2 = await NftAuctionUpgradeableProxyV2.getAddress();

    // fs.writeFileSync(
    //     storePath,
    //     JSON.stringify({
    //         proxyAddress: proxyAddressV2,
    //         implAddress: await upgrades.erc1967.getImplementationAddress(proxyAddressV2),
    //         abi: NftAuctionUpgradeableV2.interface.format("json"),
    //     })
    // );
    await save("NftAuctionUpgradeableV2", {
        address: proxyAddressV2,
        abi,
    });
}

  module.exports.tags = ["upgradeNFTAuction"]; 