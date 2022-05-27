pragma solidity ^0.8.0;

interface IERC20XIBC {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

contract TestTransfer {
    function burn(
        address destContract,
        address account,
        uint256 amount
    ) public returns (bool) {
        try IERC20XIBC(destContract).burnFrom(account, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }

    function mint(
        address destContract,
        address to,
        uint256 amount
    ) public returns (bool) {
        try IERC20XIBC(destContract).mint(to, amount) {
            return true;
        } catch (bytes memory) {
            return false;
        }
    }
}
