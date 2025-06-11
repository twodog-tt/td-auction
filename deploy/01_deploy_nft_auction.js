const { deployments, upgrades } = require("hardhat");
const path = require("path");
const fs = require("fs");


module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("部署用户地址", deployer);
    const NftAuctionUpgradeable = await ethers.getContractFactory("NftAuctionUpgradeable");

    // 通过代理合约部署
    const NftAuctionUpgradeableProxy = await upgrades.deployProxy(NftAuctionUpgradeable, [], {
        initializer: "initialize",
    });

    await NftAuctionUpgradeableProxy.waitForDeployment();
    const proxyAddress = await NftAuctionUpgradeableProxy.getAddress();
    console.log("代理合约地址:", proxyAddress);
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("实现合约地址:", implAddress);

    const storePath = path.resolve(__dirname, "./.cache/proxyNftAuctionUpgradeable.json");

    fs.writeFileSync(
        storePath,
        JSON.stringify({
            proxyAddress,
            implAddress,
            abi: NftAuctionUpgradeable.interface.format("json"),
        })
    );

    await save("NftAuctionUpgradeable", {
        address: proxyAddress,
        abi: NftAuctionUpgradeable.interface.format("json"),
    });


    // console.log("代理合约地址、实现合约地址和管理员地址已保存到", storePath);

    // const { deployer } = await getNamedAccounts();
    // await deploy("NFTAuction", {
    //     from: deployer,
    //     args: [],
    //     log: true,
    // });
};
module.exports.tags = ["deployNFTAuction"]; 