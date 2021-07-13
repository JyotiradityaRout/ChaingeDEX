pragma solidity >=0.5.16;
import './interfaces/IChaingeDexFactory.sol';
import './ChaingeDexPair.sol';

import "@nomiclabs/buidler/console.sol";

contract ChaingeDexFactory is IChaingeDexFactory {
    address public feeTo;
    address public feeToSetter;
        
    uint256 public constant MAX_TIME = 18446744073709551615;

    mapping ( bytes32 => address) _getPair;

    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint, uint256[] time);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        require(feeToSetter != address(0), 'ChaingeDex: ZERO_ADDRESS');
    }
    
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
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

    function createPair(address tokenA, address tokenB, uint256[] calldata time) external returns (address pair) {
        (address token0, address token1) = (tokenA, tokenB);

        require(time[2] < block.timestamp && time[3] == MAX_TIME, 'ChaingeDex: tokenB not full');

        uint256[] memory _time = time;
        if(tokenA > tokenB || (tokenA == tokenB && time[0] > time[2])) {
            ( token0, token1) = (tokenB, tokenA);
            (_time[2], _time[3], _time[0], _time[1]) = (time[0], time[1], time[2], time[3]);
        }

        bytes32 tokenHash = keccak256(abi.encodePacked(token0, token1, _time));

        uint256[4] memory time1 = [_time[2], _time[3], _time[0], _time[1]];

        bytes32 tokenHash1 = keccak256(abi.encodePacked(token1, token0, time1));

        require(token0 != address(0), 'ChaingeDex: ZERO_ADDRESS');

        require(_getPair[tokenHash] == address(0), 'ChaingeDex: PAIR_EXISTS');
        require(_getPair[tokenHash1] == address(0), 'ChaingeDex: PAIR_EXISTS1');

        require(tokenHash1 != tokenHash, 'ChaingeDex: PAIR_ERROR');

        require(!((time[0] > block.timestamp || time[2] > block.timestamp) && (tokenA != tokenB)), 'ChaingeDex: PAIR_ERROR2');

        bytes memory bytecode = type(ChaingeDexPair).creationCode;

        assembly {
            pair := create(0, add(bytecode, 32), mload(bytecode))
        }

        IChaingeDexPair(pair).initialize(token0, token1, time);
        _getPair[tokenHash] = pair;
        _getPair[tokenHash1] = pair;
        allPairs.push(pair);


        emit PairCreated(token0, token1, pair, allPairs.length, _time);
    }

    // function initializeHooks(address pair, address hooks) public {
    //     require(msg.sender == feeToSetter, 'ChaingeDex: FORBIDDEN');
    //     console.log('initializeHooks', pair, hooks);
    //     // IChaingeDexPair(pair).initializeHooks(hooks);
    // }
}