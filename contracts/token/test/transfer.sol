// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC20XIBC {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

contract TestTransfer {
    /**
     * @dev burn coins
     */
    function burn(
        address dstContract,
        address account,
        uint256 amount
    ) public returns (bool) {
        try IERC20XIBC(dstContract).burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    /**
     * @dev mint coins
     */
    function mint(
        address dstContract,
        address to,
        uint256 amount
    ) public returns (bool) {
        try IERC20XIBC(dstContract).mint(to, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}
