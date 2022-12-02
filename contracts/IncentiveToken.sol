// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract IncentiveToken is Ownable, ERC20 {
    address incentiveManager;

modifier onlyManager() {
      require(msg.sender == incentiveManager, "You are not manager");
      _;
    }

    modifier isNotDeployed(){
        require(address(incentiveManager) == address(0), "Manager address is already set");
        _;
    }
    
    constructor(address _incentiveManager) ERC20("IncentiveToken","IT") {
    }

    function mintReward(uint _amount) public onlyManager{
        _burn(incentiveManager,balanceOf(incentiveManager));
        _mint(incentiveManager, _amount);
    }

    function setIncentiveManager(address _incentiveManager) public isNotDeployed onlyOwner{
        incentiveManager = _incentiveManager;
    }
}