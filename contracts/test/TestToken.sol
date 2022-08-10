// // SPDX-License-Identifier: Apache-2.0

// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "../interfaces/IERC20XIBC.sol";

// contract TestToken is ERC20, IERC20XIBC {
//     uint8 private _decimals;

//     constructor(string memory name, string memory symbol) public ERC20(name, symbol) {}

//     function mint(address to, uint256 amount) external override {
//         _mint(to, amount);
//     }

//     function burnFrom(address account, uint256 amount) external override {
//         _burn(account, amount);
//     }

//     function approve(address spender, uint256 amount) public virtual override returns (bool) {
//         _approve(_msgSender(), spender, amount);
//         return true;
//     }
// }
