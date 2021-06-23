pragma solidity >=0.5.16;

interface IChaingeDexFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint, uint256[] time);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB, uint256[] calldata time) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, uint256[] calldata time) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}