// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//openzeppelin
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

//protocols contracts
import { IIdentityToken } from "../interfaces/IIdentityToken.sol";
import { Deal } from "../core/Deal.sol";


contract TokenDeal is ERC20, Ownable {

    IIdentityToken private identityToken;
    address conversionPool;
    address dealOwner;


    constructor(address _dealOwner, uint256 _amount, address _identityToken, address _conversionPool) ERC20("TOKENDEAL", "TDL") {
        dealOwner = _dealOwner;
        identityToken = IIdentityToken(_identityToken);
        conversionPool = _conversionPool;
        _mint(dealOwner, _amount);
    }

    /**
     * @dev hook for implement a limited trasfearable token only between KYC users
     * @param _from the sender
     * @param _to the receiver
     * @param _amount the amount of ERC20
    **/
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount)
        internal override virtual 
    {
        super._beforeTokenTransfer(_from, _to, _amount);
        if(_to != dealOwner){
            require(identityToken.getWhitelisted(_to) == true || _to == dealOwner || _to == conversionPool, "The receiver is not whitelisted");
        }
        //with this we modify the mapping investors in the Deal contract
        Deal(dealOwner).transactionConversion(_from,_to);
    }

    /**
     * @dev burn tokens when the originator repays the principal 
     * @param _from the address from which burn the tokens
     * @param _amount the amount of tokens to burn
    **/
    function burnTokens(address _from, uint256 _amount) 
        public
    {
        require (msg.sender == dealOwner, "You are not allowed to burn tokens");
        _burn(_from,_amount);
    }

}