
pragma solidity >=0.5.16 <0.8.0;


import "@nomiclabs/buidler/console.sol";
import './interfaces/IChaingeDexPair.sol';

import './interfaces/IERC777Recipient.sol';
import './interfaces/IERC777Sender.sol';

import './ERC1820Implementer.sol';
import './interfaces/IERC1820Registry.sol';

// import './interfaces/IMinning.sol';

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
    
    event Withdraw(address indexed chaingeDexPair, address indexed from, uint256 amount);

    using SafeMath for uint256;

    address public owner;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

    // IERC777 _token;
    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    // keccak256("ERC777TokensRecipient")
    bytes32 constant private TOKENS_RECIPIENT_INTERFACE_HASH =
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;
    
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");

    // mapping ( address => uint256 ) reward; // 奖励倍数, 奖励倍数设置了，才可以计算收益

    // 多账户情况下换成map
    // uint256 public rewardValue;
    // uint256 public rewardPairDirection;
    // uint256 public chng;
    // address public cashbox;
    // address public rewardToken;

    struct Pool{
        uint256  rewardValue;
        uint256  rewardPairDirection;
        uint256  chng;
        address  cashbox;
        address  rewardToken;
        uint256  totalAmount; // 池子里所有的LP
    }
    
    mapping (address => Pool) rewardConfig;

    struct User{
        uint256 totalRewardBalance; // 总收益
        uint256 rewardBalance; // 已结算余额
        uint256 lastSettleTime; // 上次结算时间
        uint256 LPAmount; // LP数量
    }

    mapping (address => mapping (address => User)) balances; // 奖励金额缓存

    modifier onlyOwner() {
        require(owner == msg.sender, 'ChaingeDex: require sender is feeToSetter');
        _;
    }

    constructor(address _owner) public {
        owner = _owner;
    }

    function setRewardConfig(address _chaingeDexPair, uint256 _rewardValue,  uint256 _rewardPairDirection, address _cashbox, address _rewardToken ) public onlyOwner {
         uint256 chng = 2993519;
        require(_rewardPairDirection == 0 || _rewardPairDirection == 1, 'Hooks setRewardPairDirection: Invalid value');
        rewardConfig[_chaingeDexPair] = Pool(_rewardValue,_rewardPairDirection, chng, _cashbox,_rewardToken, 0);

         _registerInterfaceForAddress(_TOKENS_SENDER_INTERFACE_HASH, _chaingeDexPair);
    }

    function setReward(address _chaingeDexPair,uint256 value) public onlyOwner {
        rewardConfig[_chaingeDexPair].rewardValue = value;
    }

    function setRewardPairDirection(address _chaingeDexPair,uint256 value) public onlyOwner {
      require(value == 0 || value == 1, 'Hooks setRewardPairDirection: Invalid value');
       rewardConfig[_chaingeDexPair].rewardPairDirection = value;
    }

    function setCashbox(address _chaingeDexPair, address _cashbox) public onlyOwner {
        rewardConfig[_chaingeDexPair].cashbox = _cashbox;
    }

    function setCHNG(address _chaingeDexPair, uint256 amount) public onlyOwner {
        rewardConfig[_chaingeDexPair].chng = amount;
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

    require(operator == msg.sender, 'Permission denied');

    if(rewardConfig[operator].rewardValue ==0){
        return; // 未设置倍数， 但是这里不能报错，未设置只是不记账而已。
    }

    if(from == address(0)) { // mint
      settlementReward(operator, to);
      addBalance(operator ,to, amount);
      
    } else {
        // 转账出去, 不管你转给谁，都视为移除LP, 这里取form
        if( balances[operator][from].lastSettleTime == 0) { // 根本没入账。
            return;
        }
        settlementReward(operator, from);
        subBalance(operator, from, amount); // 减去 amount

        // uint256 rewardAmount = rewardOf(operator, from); 
        // _withdraw(operator, from, rewardAmount);
        if(to != operator && to != address(0)) { // 如果不是转个pair 合约，那么就给新地址上账
          settlementReward(operator, to);
          addBalance(operator, to, amount);
        }
    }
  }
    // 每天的奖励 = 奖励倍数 * 0.0025CHNG * B池子数量 * 用户占池子比例
  function computeReward(User memory user, uint256 endTime, uint256 _reserve, Pool memory pool) internal  pure  returns(uint256 _reward) {
    if( user.LPAmount == 0 || user.lastSettleTime == 0) {
        return 0;
    }

    uint256 timeDiff = endTime - user.lastSettleTime;

    _reward = (timeDiff * pool.rewardValue * pool.chng * _reserve * ( (user.LPAmount * 10000000000000000000000000000) / pool.totalAmount  )) / 1000000000000000 / 10000000000000000000000000000;
  }

  // 结算奖励
  function settlementReward(address chaingeDexPair, address from) internal {
      User storage user =  balances[chaingeDexPair][from];
      ( uint reserve0, uint reserve1,) = IChaingeDexPair(chaingeDexPair).getReserves(); 
      uint256 _reserve = rewardConfig[chaingeDexPair].rewardPairDirection == 0 ? reserve0: reserve1;

      uint256 reward = computeReward( user, block.timestamp, _reserve, rewardConfig[chaingeDexPair]);

      user.lastSettleTime = block.timestamp;

      if(reward == 0) {
          return;
      }

      user.rewardBalance += reward;
      user.totalRewardBalance += reward;
  }

    // 收益余额 = 动态计算出里的余额 + 已结算余额
  function rewardOf(address chaingeDexPair, address from) view public returns (uint256) {
      User storage user =  balances[chaingeDexPair][from];
      ( uint reserve0, uint reserve1, ) = IChaingeDexPair(chaingeDexPair).getReserves();

      uint256 _reserve = rewardConfig[chaingeDexPair].rewardPairDirection == 0 ? reserve0: reserve1;

      uint256 reward = computeReward(user , block.timestamp, _reserve, rewardConfig[chaingeDexPair]);

      return reward + user.rewardBalance;
  } 

    // 提取余额 
  function withdraw(address chaingeDexPair, uint256 amount) public {
      _withdraw(chaingeDexPair, msg.sender, amount);
  }

  function _withdraw(address chaingeDexPair, address from, uint256 amount) private {
      User storage user =  balances[chaingeDexPair][from];
      settlementReward(chaingeDexPair, from);
      require(user.rewardBalance > 0, 'Hooks: rewardBalance = 0');

      _safeTransfer(rewardConfig[chaingeDexPair].rewardToken, rewardConfig[chaingeDexPair].cashbox, from, amount);
      user.rewardBalance = user.rewardBalance.sub(amount);
      emit Withdraw(chaingeDexPair, from, amount);
  }

  // 添加余额, 测试的时候设置为public从外部调用。 上线后，则不允许外部调用。需要哎回调钩子里调用。
  function addBalance(address chaingeDexPair, address from, uint256 amount) private {
    balances[chaingeDexPair][from].LPAmount += amount;
    rewardConfig[chaingeDexPair].totalAmount += amount;

    if( balances[chaingeDexPair][from].lastSettleTime == 0) {
        balances[chaingeDexPair][from].lastSettleTime = block.timestamp;
    }
  }

  function subBalance(address chaingeDexPair, address from, uint256 amount) private {
     require(balances[chaingeDexPair][from].LPAmount >= amount, 'Minning: subBalance error');
     require(rewardConfig[chaingeDexPair].totalAmount >= amount, 'Minning: subBalance error');
     
     balances[chaingeDexPair][from].LPAmount = balances[chaingeDexPair][from].LPAmount.sub(amount);
     rewardConfig[chaingeDexPair].totalAmount = rewardConfig[chaingeDexPair].totalAmount.sub(amount);
  }

  function _safeTransfer(address token, address from, address to, uint value) private {
      (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, from, to, value));
      require(success && (data.length == 0 || abi.decode(data, (bool))), 'Minning: TRANSFER_FAILED');
  }
}