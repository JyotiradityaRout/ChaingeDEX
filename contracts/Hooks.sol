
pragma solidity >=0.5.16 <0.8.0;

// import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
// import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
// import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
// import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
// import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@nomiclabs/buidler/console.sol";
import './interfaces/IChaingeDexPair.sol';

import './interfaces/IERC777Recipient.sol';
import './interfaces/IERC777Sender.sol';

import './ERC1820Implementer.sol';
import './interfaces/IERC1820Registry.sol';

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

// import '@uniswap/v2-core/contracts/libraries/SafeMath.sol';

/*
*   流动性挖矿合约
    tokensReceived 方法被注册到ERC1820 上，到用户收到了流动性代币，就会触发记账，
*/
contract Minning is IERC777Sender, ERC1820Implementer {

    using SafeMath for uint256;

    address public _owner;

    address public chaingeDexPair;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

    // IERC777 _token;
    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    // keccak256("ERC777TokensRecipient")
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH =
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;
    
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");

    // mapping ( address => uint256 ) reward; // 奖励倍数, 奖励倍数设置了，才可以计算收益

    uint256 public rewardValue;
    uint256 public rewardPairDirection;
    uint256 public chng;
    address public cashbox;
    address public rewardToken;
    

    struct User{
        uint256 totalRewardBalance; // 总收益
        uint256 rewardBalance; // 已结算余额
        uint256 lastSettleTime; // 上次结算时间
        uint256 LPAmount; // LP数量
    }

    mapping (address => User) balances; // 奖励金额缓存

    uint256 public totalAmount;

    modifier onlyOwner() {
        require(_owner == msg.sender, 'ChaingeDex: require sender is feeToSetter');
        _;
    }

    constructor(address _chaingeDexPair, uint256 _rewardValue,  uint256 _rewardPairDirection, address _cashbox, address _rewardToken ) public {
        // _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
        _owner = msg.sender;
        // _token = token;
        chaingeDexPair = _chaingeDexPair;

        rewardValue = _rewardValue; // 测试

        require(_rewardPairDirection == 0 || _rewardPairDirection == 1, 'Hooks setRewardPairDirection: Invalid value');
        rewardPairDirection = _rewardPairDirection;

        cashbox = _cashbox;

        rewardToken = _rewardToken;

        chng = 2993519;

        _registerInterfaceForAddress(TOKENS_RECIPIENT_INTERFACE_HASH, _chaingeDexPair);
        _registerInterfaceForAddress(_TOKENS_SENDER_INTERFACE_HASH, _chaingeDexPair);
    }

    function setReward(uint256 value) public onlyOwner {
       rewardValue = value;
    }

    function setRewardPairDirection(uint256 value) public onlyOwner {
      require(value == 0 || value == 1, 'Hooks setRewardPairDirection: Invalid value');
      rewardPairDirection = value;
    }

    function setCashbox(address _cashbox) public onlyOwner {
        cashbox = _cashbox;
    }

    function setCHNG(uint256 amount) public onlyOwner {
        chng = amount;
    }


  // 只需要监听send就够了。 当mint发送的时候。 全0地址为from， 上账。 当不是全0地址为from，下账。
  function tokensToSend(
      address operator,
      address from,
      address to,
      uint amount,
      bytes calldata userData,
      bytes calldata operatorData
  ) external override {

    if(rewardValue ==0){
        return; // 未设置倍数， 但是这里不能报错，未设置只是不记账而已。
    }

    if(from == address(0)) { // mint
      
      settlementReward(to);
      addBalance(to, amount);
      
    } else {
        // 转账出去, 不管你转给谁，都视为移除LP, 这里取form
        settlementReward(from);
        subBalance(from, amount); // 减去 amount
        uint256 amount = rewardOf(from); 
        _withdraw(from, amount);

        if(to != chaingeDexPair) { // 如果不是转个pair 合约，那么就给新地址上账
          settlementReward(to);
          addBalance(to, amount);
        }
    }
  }
    // 每天的奖励 = 奖励倍数 * 0.0025CHNG * B池子数量 * 用户占池子比例
  function computeReward(address from, User memory user, uint256 _totalAmount, uint256 endTime, uint256 pool, uint256 rewardMultiple, uint256 chng) internal  pure  returns(uint256 _reward) {
    if( user.LPAmount == 0 || user.lastSettleTime == 0) {
        return 0;
    }

    uint256 timeDiff = endTime - user.lastSettleTime;
    _reward = (timeDiff * rewardMultiple * chng * pool * ( user.LPAmount / _totalAmount  )) / 1000000000000000;
  }

  // 结算奖励
  function settlementReward(address from) internal {
      User storage user =  balances[from];
      ( uint reserve0, uint reserve1,) = IChaingeDexPair(chaingeDexPair).getReserves(); 
      uint256 _pool = rewardPairDirection == 0 ? reserve0: reserve1;

      console.log('timeDiff', block.timestamp - user.lastSettleTime);

      uint256 reward = computeReward(from, user, totalAmount, block.timestamp, _pool, rewardValue, chng);
      if(reward == 0) {
          return;
      }

      user.lastSettleTime = block.timestamp;
      user.rewardBalance += reward;
      user.totalRewardBalance += reward;
  }

    // 收益余额 = 动态计算出里的余额 + 已结算余额
  function rewardOf(address from) view public returns (uint256) {
      User storage user =  balances[from];
      ( uint reserve0, uint reserve1, ) = IChaingeDexPair(chaingeDexPair).getReserves();

      uint256 _pool = rewardPairDirection == 0 ? reserve0: reserve1;
      
      uint256 reward = computeReward(from, user, totalAmount , block.timestamp, _pool, rewardValue, chng);
      return reward + user.rewardBalance;
  } 

    // 提取余额 
  function withdraw(uint256 amount) public {
      _withdraw(msg.sender, amount);
  }

  function _withdraw(address from, uint256 amount) private {
      User storage user =  balances[from];
      settlementReward(from);
      require(user.rewardBalance > 0, 'Hooks: rewardBalance = 0');

      _safeTransfer(rewardToken, cashbox, from, amount);
      user.rewardBalance = user.rewardBalance.sub(amount);
  }

  // 添加余额, 测试的时候设置为public从外部调用。 上线后，则不允许外部调用。需要哎回调钩子里调用。
  function addBalance(address from, uint256 amount) private {
    balances[from].LPAmount += amount;
    totalAmount += amount;

    if( balances[from].lastSettleTime == 0) {
        balances[from].lastSettleTime = block.timestamp - 600; // 测试: 把时间往前移 100000 秒
    }
  }

  function subBalance(address from, uint256 amount) private {
     balances[from].LPAmount = balances[from].LPAmount.sub(amount);
     totalAmount = totalAmount.sub(amount);
  }

  function _safeTransfer(address token, address from, address to, uint value) private {
      (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, from, to, value));
      require(success && (data.length == 0 || abi.decode(data, (bool))), 'Minning: TRANSFER_FAILED');
  }
}