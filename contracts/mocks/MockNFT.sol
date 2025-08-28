// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title MockNFT
 * @notice Mock NFT contract for testing IPO auction system
 * @dev Simple ERC721 with minting capability
 */
contract MockNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    string private _baseTokenURI;

    constructor() ERC721("Mock ALX NFT", "mALX") Ownable(msg.sender) {}

    /**
     * @notice Mint a new NFT to an address
     * @param to Address to mint to
     * @return Token ID of the minted NFT
     */
    function mint(address to) external onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(to, newTokenId);
        return newTokenId;
    }

    /**
     * @notice Mint a specific token ID to an address
     * @param to Address to mint to
     * @param tokenId Specific token ID to mint
     */
    function mintSpecific(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    /**
     * @notice Get the next token ID
     * @return Next available token ID
     */
    function getNextTokenId() external view returns (uint256) {
        return _tokenIds.current() + 1;
    }

    /**
     * @notice Set base URI for token metadata
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @notice Get base URI for token metadata
     * @return Base URI string
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}
