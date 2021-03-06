pragma solidity =0.5.16;

import './interfaces/IChaingeDexPair.sol';
import '@uniswap/v2-core/contracts/libraries/Math.sol';
import '@uniswap/v2-core/contracts/libraries/UQ112x112.sol';
import '@uniswap/v2-core/contracts/interfaces/IERC20.sol';
import './interfaces/IChaingeDexFactory.sol';

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';

import './interfaces/IFRC758.sol';
import './ChaingeDexFRC758.sol';
import "@nomiclabs/buidler/console.sol";

contract ChaingeDexPair is IChaingeDexPair, ChaingeDexFRC758 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;

    // safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) 
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('timeSliceTransferFrom(address,address,uint256,uint256,uint256)')));

    address public factory;
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'ChaingeDex: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value, uint256 tokenStart, uint256 tokenEnd) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, address(this), to, value, tokenStart, tokenEnd));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() public {
        factory = msg.sender;
    }

    struct SliceAccount {
        address _address; //token amount
        uint256 tokenStart; //token start blockNumber or timestamp (in secs from unix epoch)
        uint256 tokenEnd; //token end blockNumber or timestamp, use MAX_UINT for timestamp, MAX_BLOCKNUMBER for blockNumber.
    }

    SliceAccount public token0;
    SliceAccount public token1;

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1, uint256[] calldata time) external {
        require(msg.sender == factory, 'ChaingeDex: FORBIDDEN'); // sufficient check
        token0 = SliceAccount(_token0, time[0], time[1]);
        token1 = SliceAccount(_token1, time[2], time[3]);
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'ChaingeDex: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/2th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IChaingeDexFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(1).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to, uint256[] calldata time) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings

        uint256 balance0 = getAllBalance(token0._address, address(this), time[0], time[1]);
        uint256 balance1 = getAllBalance(token1._address, address(this), time[2], time[3]);
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'ChaingeDex: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    function getAllBalance(address token, address from, uint256 start, uint256 end) internal returns(uint256) {
        uint256 balance0 = IFRC758(token).timeBalanceOf(from, start, end);
        uint256 balance = IFRC758(token).balanceOf(from);
        return balance0 + balance;
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to, uint256[] calldata time) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0._address;
        address _token1 = token1._address;                             // gas savings
        uint256 balance0 = getAllBalance(token0._address, address(this), token0.tokenStart, token0.tokenEnd);
        uint256 balance1 = getAllBalance(token1._address, address(this), token1.tokenStart, token1.tokenEnd);

         uint liquidity = IFRC758(token0._address).balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

        console.log(liquidity, balance0, _totalSupply);
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'ChaingeDex: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0, token0.tokenStart, token0.tokenEnd);
        _safeTransfer(_token1, to, amount1, token1.tokenStart, token1.tokenEnd);
        balance0 = getAllBalance(token0._address, address(this), token0.tokenStart, token0.tokenEnd);
        balance1 = getAllBalance(token1._address, address(this), token1.tokenStart, token1.tokenEnd);
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'ChaingeDex: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'ChaingeDex: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0._address;
            address _token1 = token1._address;
            require(to != _token0 && to != _token1, 'ChaingeDex: INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out, token0.tokenStart, token0.tokenEnd); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out, token1.tokenStart, token1.tokenEnd); // optimistically transfer tokens
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = getAllBalance(_token0, address(this), token0.tokenStart, token0.tokenEnd);
            balance1 = getAllBalance(_token1, address(this), token1.tokenStart, token1.tokenEnd);

        }

        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, 'ChaingeDex: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(2));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(2));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'ChaingeDex: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0._address; // gas savings
        address _token1 = token1._address; // gas savings
        _safeTransfer(_token0, to, IFRC758(_token0).timeBalanceOf(address(this), token0.tokenStart, token0.tokenEnd).sub(reserve0), token0.tokenStart, token0.tokenEnd);
        _safeTransfer(_token1, to, IFRC758(_token1).timeBalanceOf(address(this), token0.tokenStart, token0.tokenEnd).sub(reserve1), token0.tokenStart, token0.tokenEnd);
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IFRC758(token0._address).timeBalanceOf(address(this), token0.tokenStart, token0.tokenEnd), IFRC758(token1._address).timeBalanceOf(address(this), token0.tokenStart, token0.tokenEnd), reserve0, reserve1);
    }
}