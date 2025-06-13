// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NftAuctionUpgradeableV2 is Initializable {
    struct Auction {
        // 是否结束（1 byte）
        bool ended;
        // 地址类变量（每个 20 字节）
        address seller;
        address highestBidder;
        address nftContract;
        // 数值类变量（每个 32 字节）
        uint256 duration;
        uint256 startPrice;
        uint256 startTime;
        uint256 highestBid;
        uint256 nftId;
    }

    // 状态变量
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;

    function initialize() public initializer {
        admin = msg.sender; // 部署合约的地址为管理员
    }

    // 创建拍卖
    function createAuction(
        uint256 _duration,
        uint256 _startPrice,
        address _nftContract,
        uint256 _nftId
    ) public {
        // 只有管理员可以创建拍卖
        require(msg.sender == admin, "Only admin can create auctions");
        // 验证输入参数
        require(_duration > 0, "Duration must be greater than 0");
        require(_startPrice > 0, "Start price must be greater than 0");
        require(
            _nftContract != address(0),
            "NFT contract address cannot be zero"
        );
        auctions[nextAuctionId] = Auction({
            seller: msg.sender,
            duration: _duration,
            startPrice: _startPrice,
            startTime: block.timestamp,
            ended: false,
            highestBidder: address(0),
            highestBid: 0,
            nftContract: _nftContract,
            nftId: _nftId
        });

        nextAuctionId++;
    }

    // 买家参与买单
    function placeBid(uint256 _auctionId) public payable {
        Auction storage auction = auctions[_auctionId];
        // 验证拍卖是否存在
        require(_auctionId < nextAuctionId, "Auction does not exist");
        // 验证拍卖是否结束
        require(
            !auction.ended &&
                block.timestamp > auction.startTime + auction.duration,
            "Auction has ended"
        );
        // 验证出价是否高于当前最高出价
        require(
            msg.value > auction.highestBid && msg.value >= auction.startPrice,
            "Bid must be higher than current highest bid and start price"
        );

        // 如果有出价者，退还之前的最高出价
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        // 更新拍卖信息
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
    }

    function testHello() public pure returns (string memory) {
        return "Hello, world!";
    }
}
