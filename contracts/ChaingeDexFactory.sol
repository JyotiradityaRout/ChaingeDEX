pragma solidity >=0.5.16;
import './interfaces/IChaingeDexFactory.sol';
import './ChaingeDexPair.sol';

// import "@nomiclabs/buidler/console.sol";

contract ChaingeDexFactory is IChaingeDexFactory {
    address public feeTo;
    address public feeToSetter;

    mapping ( bytes32 => address) _getPair;

    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        require(feeToSetter != address(0), 'ChaingeDex: ZERO_ADDRESS');
    }
    
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
    
    function createPair(address tokenA, address tokenB, uint256[] calldata time) external returns (address pair) {
        (address token0, address token1) = (tokenA, tokenB);
        bytes32 tokenHash = keccak256(abi.encodePacked(token0, token1, time));

        uint256[4] memory time1 = [time[2], time[3], time[0], time[1]];

        bytes32 tokenHash1 = keccak256(abi.encodePacked(token1, token0, time1));

        require(token0 != address(0), 'ChaingeDex: ZERO_ADDRESS');

        require(_getPair[tokenHash] == address(0), 'ChaingeDex: PAIR_EXISTS');
        require(_getPair[tokenHash1] == address(0), 'ChaingeDex: PAIR_EXISTS1');

        bytes memory bytecode = type(ChaingeDexPair).creationCode;

        assembly {
            pair := create(0, add(bytecode, 32), mload(bytecode))
        }

        IChaingeDexPair(pair).initialize(token0, token1, time);
        _getPair[tokenHash] = pair;
        _getPair[tokenHash1] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function getPair(address token0, address token1, uint256[] memory time) public view returns(address) {
        bytes32 tokenHash = keccak256(abi.encodePacked(token0, token1, time));
        return _getPair[tokenHash];
    }
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'ChaingeDex: FORBIDDEN');
        require(_feeTo != address(0), 'ChaingeDex: ZERO_ADDRESS');
        feeTo = _feeTo;
    }
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'ChaingeDex: FORBIDDEN');
        require(_feeToSetter != address(0), 'ChaingeDex: ZERO_ADDRESS');
        feeToSetter = _feeToSetter;
    }

    // function createTimePair(bytes tokenA, bytes tokenB) external returns (address pair) {
    //     (bytes token0, address tokenB) = (tokenA, tokenB);
    //     bytes32 tokenHash = keccak256(abi.encodePacked(token0, token1));

    //     // uint256[4] memory time1 = [time[2], time[3], time[0], time[1]];

    //     // bytes32 tokenHash1 = keccak256(abi.encodePacked(token1, token0, time1));

    //     // require(token0 != address(0), 'ChaingeDex: ZERO_ADDRESS');

    //     // require(_getPair[tokenHash] == address(0), 'ChaingeDex: PAIR_EXISTS');
    //     // require(_getPair[tokenHash1] == address(0), 'ChaingeDex: PAIR_EXISTS1');

    //     bytes memory bytecode = type(ChaingeDexPair).creationCode;

    //     assembly {
    //         pair := create(0, add(bytecode, 32), mload(bytecode))
    //     }

    //     IChaingeDexPair(pair).initialize(token0, token1, time);
    //     _getPair[tokenHash] = pair;
    //     allPairs.push(pair);
    //     emit PairCreated(token0, token1, pair, allPairs.length);
    // }
}