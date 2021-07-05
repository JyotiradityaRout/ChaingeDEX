
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

/*
*   流动性挖矿合约
    tokensReceived 方法被注册到ERC1820 上，到用户收到了流动性代币，就会触发记账，
*/
contract Minning is IERC777Recipient, IERC777Sender, ERC1820Implementer {

    mapping(address => uint) public givers;

    address public _owner;

    address public chaingeDexPair;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

    // IERC777 _token;

    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    // keccak256("ERC777TokensRecipient")
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH =
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;
    
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");

    mapping ( address => uint256 ) reward; // 奖励倍数, 奖励倍数设置了，才可以计算收益

    struct User{
        uint256 totalRewardBalance; // 总收益
        uint256 rewardBalance; // 已结算余额
        uint256 lastSettleTime; // 上次结算时间
        uint256 LPAmount; // LP数量
    }

    mapping (address => User) balances; // 奖励金额缓存

    uint256 public totalAmount;

    constructor(address _chaingeDexPair) public {

        // _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));

        _owner = msg.sender;
        // _token = token;
        chaingeDexPair = _chaingeDexPair;

        reward[chaingeDexPair] = 40; // 测试

        _registerInterfaceForAddress(TOKENS_RECIPIENT_INTERFACE_HASH, _chaingeDexPair);
        _registerInterfaceForAddress(_TOKENS_SENDER_INTERFACE_HASH, _chaingeDexPair);
    }

    function setReward(address pair, uint256 value) public {
        reward[pair] = value;
    }

    // 收款时被回调
    // operator 就是pir合约地址。因此在这里判断是否记账，  reward[pair] == operator;
  function tokensReceived(
      address operator,
      address from,
      address to,
      uint amount,
      bytes calldata userData,
      bytes calldata operatorData
  ) external override {
    //   if(reward[pair] ==0){
    //       return; // 未设置倍数， 但是这里不能报错，未设置只是不记账而已。
    //   }

    console.log('Minning tokensReceived', from, to, amount);

    // givers[from] += amount;
    // 1 结算已有的动态计算收益到 amount字段
    settlementReward(from);
    // // 2 根据传如的 amount 修改 User的 amount
    subBalance(to, amount);

    // balances[from].
  }

  function tokensToSend(
      address operator,
      address from,
      address to,
      uint amount,
      bytes calldata userData,
      bytes calldata operatorData
  ) external override {
    //   if(reward[pair] ==0){
    //       return; // 未设置倍数， 但是这里不能报错，未设置只是不记账而已。
    //   }
    console.log('Minning tokensToSend', from, to, amount);

    // givers[from] += amount;
    // 1 结算已有的动态计算收益到 amount字段
    settlementReward(from);
    // 2 根据传如的 amount 修改 User的 amount
    addBalance(to, amount);


  }

    // 每天的奖励 = 奖励倍数 * 0.0025CHNG * B池子数量 * 用户占池子比例
    /*
        reserve1 是b池的数量
    */
  function computeReward(address from, User memory user, uint256 _totalAmount, uint256 endTime, uint reserve1, uint256 rewardMultiple) internal  pure  returns(uint256 _reward) {
    if( user.LPAmount == 0 || user.lastSettleTime == 0) {
        return 0;
    }

    uint256 timeDiff = endTime - user.lastSettleTime;

    // 每秒的收益为 0.000000002993519;
    uint256 chng = 2993519;

    // reward = timeDiff * 0.0025 * user.LPAmount / _totalAmount;
    // 奖励倍数  
    _reward = (timeDiff * rewardMultiple * chng * reserve1 * (user.LPAmount  / _totalAmount)) / 1000000000000000;
  }

  // 结算奖励
  function settlementReward(address from) internal {
      User storage user =  balances[from];
      ( uint reserve0, uint reserve1,) = IChaingeDexPair(chaingeDexPair).getReserves();
      uint256 reward = computeReward(from, user, totalAmount , block.timestamp, reserve1, reward[chaingeDexPair]);
      if(reward == 0) {
          return;
      }

      user.lastSettleTime = block.timestamp;
      user.rewardBalance += reward;
      user.totalRewardBalance += reward;
  }

    // 收益余额 = 动态计算出里的余额 + 已结算余额
  function balanceOf(address from) view public returns (uint256) {
       User storage user =  balances[from];

      // ( uint reserve0, uint reserve1, ) = IChaingeDexPair(chaingeDexPair).getReserves();

      ( uint reserve0, uint reserve1 ) = (100, 100000000000000); // 测试

       uint256 reward = computeReward(from, user, totalAmount , block.timestamp, reserve1, reward[chaingeDexPair]);
       return reward + user.rewardBalance;
  }

    // 提取余额 
  function withdraw(address from, uint256 amount) public {
    
  }

  // 添加余额, 测试的时候设置为public从外部调用。 上线后，则不允许外部调用。需要哎回调钩子里调用。
  function addBalance(address from, uint256 amount) public {
    balances[from].LPAmount += amount;
    totalAmount += amount;

    if( balances[from].lastSettleTime == 0) {
        balances[from].lastSettleTime = block.timestamp - 10000000; // 测试: 把时间往前移 100000 秒
    }
  }

  function subBalance(address from, uint256 amount) public {
     balances[from].LPAmount -= amount;
     totalAmount -= amount;
  }

  function _safeTransfer(address token, address to, uint value) private {
      (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, address(this), to, value));
      require(success && (data.length == 0 || abi.decode(data, (bool))), 'Minning: TRANSFER_FAILED');
  }
}