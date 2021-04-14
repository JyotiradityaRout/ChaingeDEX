pragma solidity =0.5.16;

// import "@nomiclabs/buidler/console.sol";

import './interfaces/IUniswapV2Factory.sol';

import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // function getPair(address token0, address token1) public {
    //     return getPair[token0][token1];
    // }

    function createPair(address tokenA, address tokenB, uint256[] calldata time) external returns (address pair) {
        // require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        console.log('aaaaaaaaaaa');
        // bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            // pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
            pair := create(0, add(bytecode, 32), mload(bytecode))
        }
        
        console.log('bbbbb', time[0]);

        IUniswapV2Pair(pair).initialize(token0, token1, time);
             console.log('cccccc', time[0]);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}