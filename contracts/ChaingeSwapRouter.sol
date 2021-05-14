pragma solidity =0.6.6;

import './interfaces/IChaingeDexRouter01.sol';
import './interfaces/IChaingeDexFactory.sol';
import './interfaces/IChaingeDexPair.sol';
import './TransferHelper.sol';
import '@uniswap/v2-periphery/contracts/libraries/SafeMath.sol';

import "@nomiclabs/buidler/console.sol";

interface IFRC758 {
    event Transfer(address indexed _from, address indexed _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    function balanceOf(address _owner, uint256 startTime, uint256 endTime)  external view returns (uint256);
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function transferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd, bytes calldata _data) external;
    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
}


library ChaingeDexLibrary {
    using SafeMath for uint;
    function pairFor(address factory, address tokenA, address tokenB, uint256[] memory time) internal view returns (address pair) {
        pair = IChaingeDexFactory(factory).getPair(tokenA, tokenB, time);
    }
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'ChaingeDexLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) =  (tokenA, tokenB);
        require(token0 != address(0), 'ChaingeDexLibrary: ZERO_ADDRESS');
    }
        // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB, uint256[] memory time) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IChaingeDexPair(pairFor(factory, tokenA, tokenB, time)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'ChaingeDexLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'ChaingeDexLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'ChaingeDexLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'ChaingeDexLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(998);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'ChaingeDexLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'ChaingeDexLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(998);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path, uint256[] memory time) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'ChaingeDexLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1], time);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path, uint256[] memory time) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'ChaingeDexLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i], time);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
contract ChaingeSwap is IChaingeDexRouter01 {
    using SafeMath for uint;

    address public immutable override factory;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'ChaingeDexRouter: EXPIRED');
        _;
    }

    constructor(address _factory) public {
        factory = _factory;
    }

    receive() external payable {
    }

    function getReserves(address factory, address tokenA, address tokenB, uint256[] memory time) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = ChaingeDexLibrary.sortTokens(tokenA, tokenB);
         address pair = IChaingeDexFactory(factory).getPair(tokenA, tokenB, time);
        (uint reserve0, uint reserve1,) = IChaingeDexPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256[] memory time
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IChaingeDexFactory(factory).getPair(tokenA, tokenB, time) == address(0)) {
            revert();
        }
        (uint256 reserveA, uint256 reserveB) = getReserves(factory, tokenA, tokenB, time);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = ChaingeDexLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'ChaingeDexRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = ChaingeDexLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'ChaingeDexRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        uint256[] memory time
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, time);
        liquidity = _addLiquidityByTimeSliceToken(
            tokenA,
            tokenB,
            amountA,
            amountB,
            to,
            time
        );
    }

    function _addLiquidityByTimeSliceToken(
            address tokenA,
            address tokenB,
            uint256 amountA,
            uint256 amountB,
            address to,
            uint256[] memory time
    ) internal returns(uint liquidity) {
        address pair = IChaingeDexFactory(factory).getPair(tokenA, tokenB, time);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA, time[0], time[1]);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB, time[2], time[3]);
        liquidity = IChaingeDexPair(pair).mint(to, time);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint256[] memory time
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = IChaingeDexFactory(factory).getPair(tokenA, tokenB, time);
        IChaingeDexPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IChaingeDexPair(pair).burn(to, time);
        (amountA, amountB) = (amount0, amount1);
        require(amountA >= amountAMin, 'ChaingeDexRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'ChaingeDexRouter: INSUFFICIENT_B_AMOUNT');
    }

    function _swap(uint[] memory amounts, address[] memory path, address _to, uint256[] memory time) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = ChaingeDexLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? ChaingeDexLibrary.pairFor(factory, output, path[i + 2], time) : _to;
            IChaingeDexPair(ChaingeDexLibrary.pairFor(factory, input, output, time)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        uint256[] calldata time
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = ChaingeDexLibrary.getAmountsOut(factory, amountIn, path, time);
        require(amounts[amounts.length - 1] >= amountOutMin, 'ChaingeDexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ChaingeDexLibrary.pairFor(factory, path[0], path[1], time), amounts[0], time[0], time[1]
        );
        _swap(amounts, path, to, time);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline,
        uint256[] calldata time
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = ChaingeDexLibrary.getAmountsIn(factory, amountOut, path, time);
        require(amounts[0] <= amountInMax, 'ChaingeDexRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, ChaingeDexLibrary.pairFor(factory, path[0], path[1], time), amounts[0], time[0], time[1]
        );
        _swap(amounts, path, to, time);
    }
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return ChaingeDexLibrary.quote(amountA, reserveA, reserveB);
    }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return ChaingeDexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return ChaingeDexLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }
    function getAmountsOut(uint amountIn, address[] memory path, uint256[] memory time)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return ChaingeDexLibrary.getAmountsOut(factory, amountIn, path, time);
    }

    function getAmountsIn(uint amountOut, address[] memory path, uint256[] memory time)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return ChaingeDexLibrary.getAmountsIn(factory, amountOut, path, time );
    }
}