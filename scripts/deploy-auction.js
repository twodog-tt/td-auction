const { ethers, upgrades } = require("hardhat");

async function main() {
    const Auction = await ethers.getContractFactory("Auction");
    const auction = await upgrades.deployProxy(Auction, [
        "0xSellerAddressHere",        // seller
        "0xNFTContractAddressHere",   // nftAddress
        1,                           // tokenId
        ethers.utils.parseEther("1"), // startingPrice = 1 ETH
        86400,                       // biddingTime = 1 天
        ethers.constants.AddressZero // paymentToken = ETH
    ], { initializer: "initialize" });

    await auction.deployed();
    console.log("Auction proxy deployed to:", auction.address);
}

main().catch(console.error);
