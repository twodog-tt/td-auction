// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// 价格消费者合约
// 该合约用于获取 ETH/USD 的最新价格
// 使用 Chainlink 预言机获取价格数据
// 注意：在实际部署前，请确保已安装 Chainlink 依赖
// https://docs.chain.link/docs/get-a-price-feed/
// https://docs.chain.link/docs/ethereum-addresses/
// https://docs.chain.link/docs/price-feeds/introduction/
// https://docs.chain.link/docs/price-feeds/addresses/
// https://docs.chain.link/docs/price-feeds/price-feeds-api/        
contract PriceConsumer {
    AggregatorV3Interface internal priceFeed;

    /**
     * Sepolia ETH/USD 预言机地址
     * 详情见：https://docs.chain.link/data-feeds/price-feeds/addresses/?network=ethereum&page=1
     */
    constructor() {
        priceFeed = AggregatorV3Interface(
            0x72AFAECF99C9d9C8215fF44C77B94B99C28741e8
        );
    }

    /**
     * 返回最新价格，带有 8 位小数精度（如 176500000000 => $1765.00000000）
     */
    function getLatestPrice() public view returns (int256) {
        (
            /*uint80 roundID*/,
            int256 price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();

        return price;
    }
}
