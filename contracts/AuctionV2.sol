// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AuctionV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address public seller;
    ERC721Upgradeable public nft;
    uint256 public tokenId;
    uint256 public startingPrice;
    uint256 public auctionEndTime;
    address public paymentToken;

    // Custom errors
    error AuctionNotEnded();
    error AuctionAlreadyEnded();
    error BidTooLow();
    error OnlySellerCanFinalize();

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public bids;

    // 新增事件：竞拍出价
    event NewBid(address indexed bidder, uint256 amount);

    // 初始化函数，必须和 V1 保持一致
    function initialize(
        address _seller,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _biddingTime,
        address _paymentToken
    ) public reinitializer(2) {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        seller = _seller;
        nft = ERC721Upgradeable(_nftAddress);
        tokenId = _tokenId;
        startingPrice = _startingPrice;
        auctionEndTime = block.timestamp + _biddingTime;
        paymentToken = _paymentToken;
    }

    // 竞拍出价函数示例，支持 ETH 竞拍（可扩展 ERC20）
    function bid() external payable {
        if (block.timestamp >= auctionEndTime) revert AuctionAlreadyEnded();
        if (!(msg.value > highestBid && msg.value >= startingPrice)) {
            revert BidTooLow();
        }
        // 先更新状态变量，再进行外部调用，防止重入攻击
        address previousBidder = highestBidder;
        uint256 previousBid = highestBid;

        highestBidder = msg.sender;
        highestBid = msg.value;
        bids[msg.sender] = msg.value;

        // 退回上一个最高出价者的金额
        if (previousBidder != address(0)) {
            payable(previousBidder).transfer(previousBid);
        }

        emit NewBid(msg.sender, msg.value);
    }

    function finalize() external {
        if (msg.sender != seller) revert OnlySellerCanFinalize();

        if (highestBidder != address(0)) {
            nft.transferFrom(address(this), highestBidder, tokenId);
            payable(seller).transfer(highestBid);
        } else {
            // 无竞拍者，NFT 返还卖家
            nft.transferFrom(address(this), seller, tokenId);
        }
    }

    // 升级权限控制
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
