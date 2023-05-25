pragma solidity ^0.8.16;

contract UniswapV2FactoryMock {
    function feeTo() external pure returns (address) {
        return address(0);
    }
}
