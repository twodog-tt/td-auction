const hre = require("hardhat");

async function main() {
  const PriceConsumer = await hre.ethers.getContractFactory("PriceConsumer");

  // v6 deploy() 已经等待部署完成，返回合约实例
  const priceConsumer = await PriceConsumer.deploy();

  // 不需要调用 priceConsumer.deployed();

  console.log("PriceConsumer deployed to:", priceConsumer.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
