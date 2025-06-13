// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 尽量使用 { SymbolName } 的导入方式。
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title Auction
 * @dev 实现一个简单的 NFT 拍卖合约
 * 核心逻辑：NFT 拍卖、出价、结束、资产转移
 * ReentrancyGuard：保护提现函数，避免重入攻击。
 */
contract Auction is ReentrancyGuard {
    address public seller; // 拍卖发起人（NFT 当前持有人）
    IERC721 public nft; // 被拍卖的 NFT 合约
    uint256 public tokenId; // NFT 的 tokenId
    uint256 public startTime; // 拍卖开始时间
    uint256 public endTime; // 拍卖结束时间
    uint256 public startingPrice; // 起拍价（以 ETH 计价）
    address public highestBidder; // 当前最高出价者
    bool public ended; // 拍卖是否已结束
    address public paymentToken; // if address(0), use ETH
    IERC20 public erc20; // optional
    struct SupportedToken {
        address tokenAddress; // 支持的代币合约地址
        address priceFeedAddress; // Chainlink 价格预言机地址
        uint8 decimals; // Chainlink 价格预言机小数位数
    }

    struct BidInfo {
        address bidder;
        address token;
        uint256 amount;
        uint256 amountUsd;
    }
    BidInfo public highestBid;
    // AggregatorV3Interface internal priceFeed; // Chainlink 价格预言机接口，用于获取 ETH/USD 价格
    mapping(bytes32 => SupportedToken) public supportedTokens; // 支持的代币列表，key 为代币地址
    mapping(address => mapping(address => uint256)) public pendingReturns; // 允许未中标者提取出价 防止因为直接退钱导致重入攻击

    event AuctionStarted(
        address seller,
        address nft,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 endTime
    );
    event BidPlaced(address bidder, address tokenAddress, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);
    event NewHighestBid(
        address bidder,
        address token,
        uint256 amount,
        uint256 amountUsd
    );

    /// @dev Custom error for not seller
    error NotSeller(); // 仅允许卖家调用

    modifier onlySeller() {
        if (msg.sender != seller) revert NotSeller(); // 仅允许卖家调用
        _;
    }
    /**
     * 构造函数，初始化拍卖
     * @param _nft NFT 合约地址
     * @param _tokenId 拍卖的 NFT tokenId
     * @param _startingPrice 起拍价（单位：wei）
     * @param _duration 拍卖时长（单位：秒）
     * @param _priceFeed Chainlink 价格预言机地址（用于获取 ETH/USD 价格）
     * 注意：合约部署者必须拥有 NFT 的所有权，并已授权此合约管理其 NFT。
     */
    /// @dev Custom error for ownership check
    error SellerMustOwnTheNFT();
    /// @dev Custom error for approval check
    error ContractNotApprovedToTransferNFT();

    constructor(
        address _seller,
        address _nft,
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _biddingTime,
        address _paymentToken
    ) {
        seller = _seller;
        nft = IERC721(_nft);
        tokenId = _tokenId;
        startingPrice = _startingPrice;
        startTime = block.timestamp;
        endTime = block.timestamp + _biddingTime;
        paymentToken = _paymentToken;

        // 合约必须先拥有 NFT 所有权
        if (nft.getApproved(tokenId) != address(this))
            revert ContractNotApprovedToTransferNFT();
        if (nft.ownerOf(_tokenId) != msg.sender) revert SellerMustOwnTheNFT();

        emit AuctionStarted(seller, _nft, _tokenId, _startingPrice, endTime);
        if (paymentToken != address(0)) {
            erc20 = IERC20(paymentToken);
        }
        // NFT 转入合约托管
        nft.transferFrom(_seller, address(this), _tokenId);
    }

    /// @dev Custom error for auction already ended
    error AuctionAlreadyEnded();
    /// @dev Custom error for bid must be higher than current highest bid
    error BidMustBeHigherThanCurrent();
    /// @dev Custom error for bid must be at least starting price
    error BidMustBeAtLeastStartingPrice();
    /// @dev Custom error for already highest bidder
    error AlreadyHighestBidder();
    /// @dev Custom error for invalid ETH/USD price
    error InvalidEthUsdPrice();
    /// @dev Custom error for bid must be greater than zero USD
    error BidMustBeGreaterThanZeroUSD();

    event TokenRegistered(
        string symbol,
        address tokenAddress,
        address priceFeed
    ); // 注册代币事件

    // 注册支持的代币
    function registerToken(
        string memory symbol, // 代币符号（如 "USDC"）
        address tokenAddress, // 代币合约地址
        address priceFeed, // Chainlink 价格预言机地址
        uint8 decimals // 代币精度（如 USDC 为 6）
    ) external onlySeller {
        bytes32 key = keccak256(abi.encodePacked(symbol)); // 使用代币符号生成唯一键
        supportedTokens[key] = SupportedToken(
            tokenAddress,
            priceFeed,
            decimals
        );
        emit TokenRegistered(symbol, tokenAddress, priceFeed); // 触发事件通知注册
    }

    /// @dev Custom error for token not supported
    error TokenNotSupported(); // 代币不受支持

    /// @dev Custom error for ETH amount mismatch
    error EthAmountMismatch();

    /// @dev Custom error for bid too low
    error BidTooLow(); // 出价过低

    /**
     * 出价函数
     * 必须高于当前最高出价
     * 必须大于等于起拍价
     * 允许任何人出价，除非拍卖已结束
     * 出价必须为 ETH
     * 出价必须为非零值
     * @dev 出价时会检查当前时间是否在拍卖期间内，出价金额是否满足要求，并更新最高出价者和金额。
     * @notice 出价时会触发 NewHighestBid 事件
     */
    function bid(
        string calldata symbol,
        uint256 amount
    ) external payable nonReentrant {
        if (block.timestamp >= endTime) revert AuctionAlreadyEnded(); // 结束拍卖后禁止继续出价
        if (msg.value < startingPrice) revert BidMustBeAtLeastStartingPrice(); // 出价必须大于等于起拍价
        if (msg.sender == highestBidder) revert AlreadyHighestBidder(); // 防止出价最高者重复出价

        // int256 ethUsdPrice = getLatestPrice();
        // if (ethUsdPrice <= 0) revert InvalidEthUsdPrice();
        // 把 wei 转成 ETH，1 ETH = 1e18 wei
        // uint256 ethAmount = msg.value;
        // 计算美元金额（单位同 price 的精度 1e8）
        // ethAmount (wei) * ethUsdPrice (1e8) / 1e18 = USD金额 (1e-10)
        // uint256 amountUsd = (ethAmount * uint256(ethUsdPrice)) / 1e18;
        // if (amountUsd == 0) revert BidMustBeGreaterThanZeroUSD();
        // emit NewHighestBid(msg.sender, ethAmount, amountUsd);

        // 获取代币信息
        bytes32 key = keccak256(abi.encodePacked(symbol));
        SupportedToken memory token = supportedTokens[key];
        if (
            token.tokenAddress != address(0) &&
            token.priceFeedAddress == address(0)
        ) revert TokenNotSupported();
        if (msg.value != amount) revert EthAmountMismatch();

        uint256 amountUsd;
        if (token.tokenAddress == address(0)) {
            // 如果是 ETH 出价
            if (msg.value != amount) revert EthAmountMismatch();
            amountUsd = convertEthToUsd(amount);
        } else {
            // 如果是 ERC20 代币出价
            IERC20(token.tokenAddress).transferFrom(
                msg.sender,
                address(this),
                amount
            );
            if (msg.value != 0) revert EthAmountMismatch();
            amountUsd = convertErc20ToUsd(amount, token);
        }

        // 如果有之前的最高出价者，记录其未中标的出价金额
        if (highestBid.amount > 0) {
            pendingReturns[highestBid.bidder][highestBid.token] += highestBid
                .amount;
        }

        highestBid = BidInfo({
            bidder: msg.sender,
            token: token.tokenAddress,
            amount: amount,
            amountUsd: amountUsd
        });

        emit NewHighestBid(msg.sender, token.tokenAddress, amount, amountUsd);
        emit BidPlaced(msg.sender, token.tokenAddress, amount);
    }

    /**
     * 提现未中标者的出价
     */
    /// @dev Custom error for no funds to withdraw
    error NoFundsToWithdraw();

    /// @dev Custom error for failed ETH transfer
    error TransferFailed();

    function withdraw(address token) external nonReentrant {
        uint256 amount = pendingReturns[msg.sender][token];
        if (amount == 0) revert NoFundsToWithdraw();
        pendingReturns[msg.sender][token] = 0;
        // payable(msg.sender).transfer(amount);
        // ** Solidity 推荐尽量使用 call 替代 transfer，以应对部分账户对gas限制的变化： **
        if (token == address(0)) {
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    /**
     * 结束拍卖，转移 NFT 和资金
     */
    /// @dev Custom error for auction not yet ended
    error AuctionNotYetEnded();

    /// @dev Custom error for auction already ended
    error AuctionAlreadyEndedErr();

    function endAuction() external {
        if (block.timestamp < endTime) revert AuctionNotYetEnded();
        if (ended) revert AuctionAlreadyEndedErr(); // 防止重复结束拍卖

        ended = true;

        if (highestBidder != address(0)) {
            // 转移 NFT 给赢家
            nft.transferFrom(seller, highestBidder, tokenId);
            // 支付资金给卖家
            if (highestBid.token == address(0)) {
                (bool success, ) = seller.call{value: highestBid.amount}("");
                if (!success) revert TransferFailed();
            } else {
                IERC20(highestBid.token).transfer(seller, highestBid.amount);
            }
        } else {
            // 无人出价，不做任何转移
        }

        emit AuctionEnded(highestBid.token, highestBid.amount);
    }

    /**
     * 返回最新价格，带有 8 位小数精度（如 176500000000 => $1765.00000000）
     */
    // function getLatestPrice() public view returns (int256) {
    //     (
    //         ,
    //         /*uint80 roundID*/ int256 price /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
    //         ,
    //         ,

    //     ) = priceFeed.latestRoundData();

    //     // emit PriceUpdated(price);  // 这里触发事件

    //     return price;
    // }

    /// @dev Custom error for invalid price
    error InvalidPrice();

    // 获取最新的 USD 价格
    /// @notice 获取最新的 USD 价格和小数位数
    /// @param feed Chainlink 价格预言机地址
    /// @return price 最新的 USD 价格（单位：最小单位，如 176500000000 表示 $1765.00000000）
    /// @return decimals 价格的小数位数
    function getLatestUsdPrice(
        address feed
    ) public view returns (uint256 price, uint8 decimals) {
        AggregatorV3Interface aggregator = AggregatorV3Interface(feed);
        (, int256 answer, , , ) = aggregator.latestRoundData();
        if (answer <= 0) revert InvalidPrice();
        decimals = aggregator.decimals();
        price = uint256(answer);
    }

    // 转换 ETH 到 USD
    /// @notice 将 ETH 金额转换为 USD
    /// @param amountWei 以 wei 为单位的 ETH 金额
    /// @return 转换后的 USD 金额（单位：最小单位，如 176500000000 表示 $1765.00000000）
    /// @dev 使用 Chainlink 价格预言机获取最新的 ETH/USD 价格
    /// @dev 注意：此函数假设 ETH 的价格预言机地址已在 supportedTokens 中注册
    function convertEthToUsd(
        uint256 amountWei
    ) internal view returns (uint256) {
        (uint256 price, uint8 decimals) = getLatestUsdPrice(
            supportedTokens[keccak256(abi.encodePacked("ETH"))].priceFeedAddress
        );
        return (amountWei * price) / (10 ** (18 - decimals));
    }

    // 转换 ERC20 代币到 USD
    /// @notice 将 ERC20 代币金额转换为 USD
    /// @param amount 代币金额（单位：最小单位，如 USDC 为 6 位小数）
    /// @param token 支持的代币信息
    /// @return 转换后的 USD 金额（单位：最小单位，如 176500000000 表示 $1765.00000000）
    /// @dev 使用 Chainlink 价格预言机获取最新的代币/USD 价格
    /// @dev 注意：此函数假设代币的价格预言机地址已在 supportedTokens 中注册
    function convertErc20ToUsd(
        uint256 amount,
        SupportedToken memory token
    ) internal view returns (uint256) {
        (uint256 price, uint8 priceDecimals) = getLatestUsdPrice(
            token.priceFeedAddress
        );
        return (amount * price) / (10 ** (token.decimals - priceDecimals));
    }
}
