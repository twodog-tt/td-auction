// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Auction} from "./Auction.sol";

contract AuctionFactory {
    address[] public allAuctions; // 存储所有拍卖场地址

    /// 事件：当创建新的拍卖场时触发
    /// @param auctionAddress 新创建的拍卖场地址
    /// @param seller 拍卖的卖家地址
    /// @param nftAddress NFT 的合约地址
    /// @param tokenId NFT 的唯一标识符
    /// @param paymentToken 支付的代币地址（如果是 ETH 则为 address(0)）
    event AuctionCreated(
        address indexed auctionAddress,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        address paymentToken
    );

    /**
     * 创建新的拍卖场
     * @param nftAddress NFT 的合约地址
     * @param tokenId NFT 的唯一标识符
     * @param startingPrice 起拍价
     * @param biddingTime 拍卖持续时间（秒）
     * @param paymentToken 支持的支付代币地址（如果是 ETH 则为 address(0)）
     */
    /// @return 新创建的拍卖场地址
    /// @dev 该函数会创建一个新的 Auction 合约实例，并将其地址存储在 allAuctions 数组中
    /// @notice 该函数只能由合约的调用者（通常是卖家）调用
    function createAuction(
        address nftAddress,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 biddingTime,
        address paymentToken // 支持 ERC20 或 address(0) 表示 ETH
    ) external returns (address) {
        Auction newAuction = new Auction(
            msg.sender,
            nftAddress,
            tokenId,
            startingPrice,
            biddingTime,
            paymentToken
        );

        allAuctions.push(address(newAuction));

        emit AuctionCreated(
            address(newAuction),
            msg.sender,
            nftAddress,
            tokenId,
            paymentToken
        );

        return address(newAuction);
    }

    /**
     * 获取所有拍卖场地址
     * @return allAuctions 数组，包含所有拍卖场的地址
     * @dev 该函数返回一个包含所有拍卖场地址的数组
     * @notice 该函数可以被任何人调用，用于查询当前所有的拍卖场
     */
    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }

    /**
     * 获取拍卖总数
     * @return uint256 拍卖场的数量
     * @dev 该函数返回当前所有拍卖场的数量
     * @notice 该函数可以被任何人调用，用于查询当前拍卖场的总数
     */
    function getAuctionCount() external view returns (uint256) {
        return allAuctions.length;
    }
}
