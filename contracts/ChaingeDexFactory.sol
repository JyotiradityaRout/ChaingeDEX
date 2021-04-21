pragma solidity =0.5.16;
import './interfaces/IChaingeDexFactory.sol';
import './ChaingeDexPair.sol';

import "@nomiclabs/buidler/console.sol";

contract ChaingeDexFactory is IChaingeDexFactory {
    address public feeTo;
    address public feeToSetter;

    struct SliceAccount {
        address _address; //token amount
        uint256 tokenStart; //token start blockNumber or timestamp (in secs from unix epoch)
        uint256 tokenEnd; //token end blockNumber or timestamp, use MAX_UINT for timestamp, MAX_BLOCKNUMBER for blockNumber.
    }

    // mapping(uint256  => mapping(SliceAccount => address)) internal _getPair;

    // mapping(address => mapping(address => uint256)) internal _getPair;

    // mapping (uint256 => SliceAccount) name;

    mapping ( bytes32 => address) _getPair;

    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
    function createPair(address tokenA, address tokenB, uint256[] calldata time) external returns (address pair) {
        // require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        // (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (address token0, address token1) = (tokenA, tokenB);
        bytes32 tokenHash = keccak256(abi.encodePacked(token0, token1, time));

        console.log('aaaaddddeeeee', time[0], time[2]);
        console.logBytes32( tokenHash);

        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(_getPair[tokenHash] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(ChaingeDexPair).creationCode;
        // bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            // pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
            pair := create(0, add(bytecode, 32), mload(bytecode))
        }
        IChaingeDexPair(pair).initialize(token0, token1, time);
        _getPair[tokenHash] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    function getPair(address token0, address token1, uint256[] memory time) public view returns(address) {
        bytes32 tokenHash = keccak256(abi.encodePacked(token0, token1, time));
        console.log('getPair', time[0], time[2]);
        console.logBytes32( tokenHash);
        return _getPair[tokenHash];
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