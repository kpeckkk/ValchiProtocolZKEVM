// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from"@openzeppelin/contracts/utils/Counters.sol";


//a soulbound identity token given after the KYC/KYB to the contract address created with ERC4337
contract IdentityToken is ERC721URIStorage, Ownable {
   
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    mapping (address => uint256) private whitelistedUsers; //list of KYC users

    constructor() ERC721("IdentityToken", "IDT") {}

    /**
     * @dev mint identity token
     * @param _to the contract address of the token owner
     * @param _uri the data of the identity nft
    **/
    function approveIdentity(address _to, string memory _uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);
        whitelistedUsers[_to] = 1;
    }

   /**
     * @dev hook for implement a soulbound token
     * @param _from the sender
     * @param _to the receiver
     * @param _amount the amount of ERC721
     * @param _batchSize -
    **/
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount, uint256 _batchSize)
        internal override virtual 
    {
        super._beforeTokenTransfer(_from, _to, _amount,_batchSize);
        require(_from == address(0) || _to == address(0), "This a Soulbound token. It cannot be transferred. It can only be burned by the token owner.");
    }

   /**
     * @dev for cancel own account
     * @param _tokenId id of the identity token
    **/
   function burn(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "Only the owner of the token can burn it.");
        whitelistedUsers[msg.sender] = 0;
        _burn(_tokenId);
    }

    /**
     * @dev for cancel accounts lost
     * @param _tokenId id of the identity token
    **/
    function forceBurn(uint256 _tokenId) external onlyOwner{
        whitelistedUsers[ownerOf(_tokenId)] = 0;
        _burn(_tokenId);
    }

    function _burn(uint256 _tokenId) internal override(ERC721URIStorage) {
        super._burn(_tokenId);
    }

    /**
     * @dev return if a user is whitelisted
     * @param _user address of the user
    **/ 
    function getWhitelisted (address _user) public view returns (bool){
        if(whitelistedUsers[_user]>0)
        {
            return true;
        }
        else{
            return false;
        }
       
    }
}

