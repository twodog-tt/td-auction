// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// OpenZeppelin 的 ERC721 合约本身就已经实现了 approve(), transferFrom(), ownerOf() 等所有标准方法。
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Ownable 是 OpenZeppelin 提供的一个智能合约模块，用于管理合约的所有权（Ownership）控制。它的核心目的是为合约增加一个「只有合约拥有者可以执行的权限机制」。

/**
 * @title MyNFT
 * @dev 简单的 ERC721 实现，用于测试 NFT 拍卖
 */
contract MyNFT is ERC721, Ownable {
    uint256 public nextTokenId;

    constructor() ERC721("TdNFT", "TNFT") Ownable(msg.sender) {}

    /**
     * 铸造 NFT，分配给指定地址
     * 仅合约拥有者可调用（你也可以开放给任何用户）
     */
    function mint(address to) external onlyOwner {
        _safeMint(to, nextTokenId);
        nextTokenId++;
    }

     // approve, transferFrom, ownerOf 等已经继承，无需再写
}

