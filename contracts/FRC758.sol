//SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

library SafeMath256 {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function pow(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        if (b == 0) return 1;

        uint256 c = a ** b;
        assert(c / (a ** (b - 1)) == a);
        return c;
    }
}

abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function _validateAddress2(address _addr) internal pure {
        require(_addr != address(0), "invalid address");
    }

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not a contract owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _validateAddress2(newOwner);
        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
    }
}

abstract contract Controllable is Ownable {
    mapping(address => bool) controllers;

    modifier onlyController {
        require(_isController(msg.sender), "no controller rights");
        _;
    }

    function _isController(address _controller) internal view returns (bool) {
        //owner defaults to controller
        return msg.sender == owner || controllers[_controller];
    }

    function addControllers(address[] calldata _controllers) external onlyOwner {
        for (uint256 i = 0; i < _controllers.length; i++) {
            _validateAddress2(_controllers[i]);
            controllers[_controllers[i]] = true;
        }
    }
    
    function removeControllers(address[] calldata _controllers) external onlyOwner {
        for (uint256 i = 0; i < _controllers.length; i++) {
            _validateAddress2(_controllers[i]);
            controllers[_controllers[i]] = false;
        }
    }
}

interface IFRC758 {
    event Transfer(address indexed _from, address indexed _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function sliceOf(address _owner) external view returns (uint256[] memory, uint256[] memory, uint256[] memory);
    function timeBalanceOf(address _owner, uint256 tokenStart, uint256 tokenEnd) external view returns (uint256);
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function transferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) external;
}

interface ITimeSlicedTokenReceiver {
    function onTimeSlicedTokenReceived(address _operator, address _from, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd )  external returns(bytes4);
}

abstract contract FRC758 is IFRC758 {
    string internal name_;
    string internal symbol_;
    uint256 internal decimals_;

    constructor(string memory _name, string memory _symbol, uint256 _decimals) {
        name_ = _name;
        symbol_ = _symbol;
        decimals_ = _decimals;
    }
    
    function name() public view override returns (string memory) {
        return name_;
    }

    function symbol() public view override returns (string memory) {
        return symbol_;
    }
    
    function decimals() public view override returns (uint256) {
        return decimals_;
    }
    
    using SafeMath256 for uint256;

    bytes4 private constant _TIMESLICEDTOKEN_RECEIVED = 0xb005a606;
    
    uint256 public constant MAX_UINT = 2**256 - 1;

    uint256 public constant MAX_TIME = 666666666666;
    
    struct SlicedToken {
        uint256 amount;
        uint256 tokenStart;
        uint256 tokenEnd;
        uint256 next;
    }
    
    mapping (address => mapping (uint256 => SlicedToken)) internal balances;
    mapping (address => uint256) internal ownedSlicedTokensCount;
    mapping (address => mapping (address => bool)) internal operatorApprovals;
    uint256 internal _totalSupply;
    mapping (address => uint256 ) headerIndex;

    function _checkRights(bool _has) internal pure {
        require(_has, "no rights to manage");
    }

    function _validateAddress(address _addr) internal  pure {
        require(_addr != address(0), "invalid address");
    }
    
    function _validateAmount(uint256 amount) internal pure {
        require(amount > 0, "invalid amount");
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function _validateTokenStartAndEnd(uint256 tokenStart, uint256 tokenEnd) internal view {
        require(tokenEnd >= tokenStart, "tokenStart greater than tokenEnd");
        require((tokenEnd >= block.timestamp) || (tokenEnd >= block.number), "blockEnd less than current blockNumber or timestamp");
    }

    function sliceOf(address from) public view override returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        _validateAddress(from);
       uint header = headerIndex[from];
       if(header == 0) {
           return (new uint256[](0), new uint256[](0), new uint256[](0));
       }
        uint256 count = 0;
     
        while(header > 0) {
                SlicedToken memory st = balances[from][header];
                if(block.timestamp < st.tokenEnd) {
                    count++;
                }
                header = st.next;
        }
        uint256 allCount = ownedSlicedTokensCount[from];
        uint256[] memory amountArray = new uint256[](count);
        uint256[] memory tokenStartArray = new uint256[](count);
        uint256[] memory tokenEndArray = new uint256[](count);
        
        uint256 i = 0;
        for (uint256 ii = 1; ii < allCount+1; ii++) {
            if(block.timestamp >= balances[from][ii].tokenEnd) {
               continue;
            }
            amountArray[i] = balances[from][ii].amount;
            tokenStartArray[i] = balances[from][ii].tokenStart;
            tokenEndArray[i] = balances[from][ii].tokenEnd;
            i++;
        }
        
        return (amountArray, tokenStartArray, tokenEndArray);
    }

    function timeBalanceOf(address from, uint256 tokenStart, uint256 tokenEnd) public override view returns(uint256) {
       if (tokenStart >= tokenEnd) {
           return 0;
       }
       uint256 next = headerIndex[from];
       if(next == 0) {
           return 0;
       }
       uint256 amount = 0;   
        while(next > 0) {
                SlicedToken memory st = balances[from][next];
                if( tokenStart < st.tokenStart || (st.next == 0 && tokenEnd > st.tokenEnd)) {
                    amount = 0;
                    break;
                }
                if(tokenStart >= st.tokenEnd) {
                    next = st.next;
                    continue;
                }
                if(amount == 0 || amount > st.amount) {
                    amount =  st.amount;
                }
                if(tokenEnd <= st.tokenEnd) {
                   break;
                }
                tokenStart = st.tokenEnd;
                next = st.next;
        }

        return amount;
    }


    function setApprovalForAll(address _to, bool _approved) public override {
        require(_to != msg.sender, "wrong approval destination");
        operatorApprovals[msg.sender][_to] = _approved;
        emit ApprovalForAll(msg.sender, _to, _approved);
    }

    function isApprovedForAll(address _owner, address _operator) public view override returns (bool) {
        return operatorApprovals[_owner][_operator];
    }

    function isApprovedOrOwner(address _spender, address _from) public view returns (bool) {
        return _spender == _from || isApprovedForAll(_from, _spender);
    }

    function transferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) public override {
        _validateAddress(_from);
        _validateAddress(_to);
        _validateAmount(amount);
        _checkRights(isApprovedOrOwner(msg.sender, _from));
        require(_from != _to, "no sending to yourself");

        SlicedToken memory st = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
        _subSliceFromBalance(_from, st);
        _addSliceToBalance(_to, st);
        emit Transfer(_from, _to, amount, tokenStart, tokenEnd);
    }


    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) public override {
        transferFrom(_from, _to, amount, tokenStart, tokenEnd);
        require(checkAndCallSafeTransfer(_from, _to, amount, tokenStart, tokenEnd), "can't make safe transfer");
    }

    function _mint(address _from,  uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateAddress(_from);
        _validateAmount(amount);
        SlicedToken memory st = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
        _addSliceToBalance(_from, st);
        emit Transfer(address(0), _from, amount, tokenStart, tokenEnd);
    }

    function _burn(address _from, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateAddress(_from);
        _validateAmount(amount);
        SlicedToken memory st = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
        _subSliceFromBalance(_from, st);
        emit Transfer(_from, address(0), amount, tokenStart, tokenEnd);
    }

    function _addSliceToBalance(address addr, SlicedToken memory st) internal {
        uint256 count = ownedSlicedTokensCount[addr];
        if(count == 0) {
             balances[addr][1] = st;
             ownedSlicedTokensCount[addr] = 1;
             headerIndex[addr] = 1;
             return;
        }

        uint256 current = headerIndex[addr];
               
        do {
            SlicedToken storage currSt = balances[addr][current];
            if(st.tokenStart >= currSt.tokenEnd && currSt.next != 0 ) {
                current = currSt.next;
                continue;
            }
    
            if (currSt.tokenStart >= st.tokenEnd) {
                uint256 index = _addSlice(addr, st.tokenStart, st.tokenEnd, st.amount, current);
                if(current == headerIndex[addr]) {
                    headerIndex[addr] = index; 
                }
                return;
            }

            if(currSt.tokenStart < st.tokenEnd && currSt.tokenStart > st.tokenStart) {
                uint256 index = _addSlice(addr, st.tokenStart, currSt.tokenStart, st.amount, current);
                if(current == headerIndex[addr]) {
                    headerIndex[addr] = index;  
                }else {
                    uint256 _current = headerIndex[addr];
                    while(_current>0) {
                        if(balances[addr][_current].next == current)  {
                            balances[addr][_current].next = index;
                            break;
                        }
                        _current = balances[addr][_current].next;
                    }
                }

                st.tokenStart = currSt.tokenStart;
                continue;
            }
            if(currSt.tokenStart == st.tokenStart && currSt.tokenEnd == st.tokenEnd) { 
                _mergeAmount(currSt, st.amount);
                return;
            }
            if(currSt.tokenEnd >= st.tokenEnd) {  
                if(currSt.tokenStart < st.tokenStart) {
                    uint256 currStEndTime = currSt.tokenEnd ;
                    uint256 currStNext = currSt.next;
                    currSt.tokenEnd = st.tokenStart;

                    uint256 innerIndex = _addSlice(addr, st.tokenStart, st.tokenEnd, st.amount + currSt.amount, 0);
                    currSt.next = innerIndex;

                    if(currStEndTime > st.tokenEnd) {
                        uint256 rightIndex = _addSlice(addr, st.tokenEnd, currStEndTime, currSt.amount, currStNext);
                        balances[addr][innerIndex].next = rightIndex;
                    }
                    return;
                }
                 uint256 currStTokenEnd =  currSt.tokenEnd;
                 uint256 currStAmount = currSt.amount;
                if(currSt.tokenStart == st.tokenStart) {
                    currSt.tokenEnd = st.tokenEnd;
                    _mergeAmount(currSt, st.amount);
                    uint256 index = _addSlice(addr, st.tokenEnd, currStTokenEnd, currStAmount, currSt.next);
                    currSt.next = index;
                    return;
                }
            }
            if( currSt.tokenEnd > st.tokenStart && currSt.tokenEnd >= st.tokenStart) {
                  uint256 currStTokenEnd = currSt.tokenEnd;
                  if(currSt.tokenStart < st.tokenStart) {
                    currSt.tokenEnd = st.tokenStart; 
                    uint256 index = _addSlice(addr, st.tokenStart, currStTokenEnd, currSt.amount + st.amount, currSt.next);
                    currSt.next = index;
                    st.tokenStart = currStTokenEnd;
                    current = currSt.next;
                    if(current != 0) {
                        continue;
                    }
                  }
                  currSt.tokenStart = st.tokenStart;
                  _mergeAmount(currSt, st.amount);
                  current = currSt.next;
                  if(current != 0) {
                    st.tokenStart = currSt.tokenEnd;
                    continue;
                  }

                st.tokenStart = currSt.tokenEnd;
                balances[addr][ownedSlicedTokensCount[addr] +1] = st;
                currSt.next = ownedSlicedTokensCount[addr] +1;
                ownedSlicedTokensCount[addr] += 1;
                return;
            }
  
            if(currSt.next == 0 && currSt.tokenEnd <= st.tokenStart) {
                uint256 index = _addSlice(addr, st.tokenStart, st.tokenEnd, st.amount, 0);
                currSt.next = index;
                return;
            }

            current = currSt.next;
        }while(current>0);
    }

    function _mergeAmount(SlicedToken storage currSt, uint256 amount) internal {
        currSt.amount += amount;
    }

    function _addSlice(address addr, uint256 tokenStart, uint256 tokenEnd, uint256 amount, uint256 next) internal returns (uint256) {
         balances[addr][ownedSlicedTokensCount[addr] +1] = SlicedToken({amount: amount , tokenStart: tokenStart, tokenEnd: tokenEnd, next: next});
         ownedSlicedTokensCount[addr] += 1;
         return ownedSlicedTokensCount[addr];
    }
    function _subSliceFromBalance(address addr, SlicedToken memory st) internal {
        uint256 count = ownedSlicedTokensCount[addr];

        if(count == 0) {
            revert();
        }

        uint256 current = headerIndex[addr];
        do {
            SlicedToken storage currSt = balances[addr][current]; 

            if(currSt.tokenEnd < block.timestamp) { 
                headerIndex[addr] = currSt.next; 
                current = currSt.next;
                continue;
            }
            if(st.amount > currSt.amount) {
                revert();
            }

            if (currSt.tokenStart >= st.tokenEnd) { 
                 revert();
            }
            if(currSt.next == 0 && currSt.tokenEnd < st.tokenEnd) { 
                 revert();
            }

            if(currSt.tokenStart < st.tokenEnd && currSt.tokenStart > st.tokenStart) { 
                revert();
            }

            if(currSt.tokenStart == st.tokenStart && currSt.tokenEnd == st.tokenEnd) {
                currSt.amount -= st.amount;
                return;
            }

            if(currSt.tokenStart == st.tokenStart ) {
                if(currSt.tokenEnd > st.tokenEnd) {
                    uint256 currStAmount = currSt.amount;
                    currSt.amount -= st.amount;
                    uint256 currStTokenEnd = currSt.tokenEnd;
                    currSt.tokenEnd = st.tokenEnd;
                    uint256 index = _addSlice(addr, st.tokenEnd, currStTokenEnd, currStAmount,  currSt.next);
                    currSt.next = index;
                    break;
                }
                currSt.amount -= st.amount;
                st.tokenStart = currSt.tokenEnd;
                current = currSt.next;
                continue;
            }

            if(currSt.tokenStart < st.tokenStart ) { 
                uint256 index = _addSlice(addr, currSt.tokenStart, st.tokenStart, currSt.amount, current);
                if(current == headerIndex[addr]) { 
                    headerIndex[addr] = index; 
                }else {
                    uint256 _current = headerIndex[addr];
                    while(_current > 0) {
                        
                        if(balances[addr][_current].next == current)  {
                           
                            balances[addr][_current].next = index;
                            break;
                        }
                        _current = balances[addr][_current].next;
                    }
                }

                uint256 currStAmunt = currSt.amount;
                uint256 currStTokenEnd = currSt.tokenEnd;
                currSt.amount -= st.amount;
                currSt.tokenStart = st.tokenStart;

                if(currStTokenEnd >= st.tokenEnd) {
                    if(currStTokenEnd > st.tokenEnd) {
                         uint256 index1 = _addSlice(addr, st.tokenEnd, currStTokenEnd, currStAmunt, currSt.next);
                         currSt.next = index1;
                    }
                    break; 
                }
                st.tokenStart = currStTokenEnd;
            }
            current = currSt.next;
        }while(current > 0);
    }

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }    

    function checkAndCallSafeTransfer(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal returns (bool) {
        if (!_isContract(_to)) {
            return true;
        }
        bytes4 retval = ITimeSlicedTokenReceiver(_to).onTimeSlicedTokenReceived(msg.sender, _from, amount, tokenStart, tokenEnd);
        return (retval == _TIMESLICEDTOKEN_RECEIVED);
    }
}


contract ChaingeTestToken is FRC758, Controllable {
   constructor(string memory name, string memory symbol, uint256 decimals ) FRC758(name, symbol, decimals){}

    
    uint256 private constant TotalLimit = 814670050000000000000000000;
	function mint(address _receiver, uint256 amount) external onlyController {
		require((amount + _totalSupply) <= TotalLimit, "can not mint more tokens");
        _mint(_receiver, amount, block.timestamp, MAX_TIME);
		_totalSupply += amount;
    }
    function burn(address _owner, uint256 amount, uint256 tokenStart, uint256 tokenEnd) public onlyController {
        _burn(_owner, amount, tokenStart, tokenEnd);
    }

    function balanceOf(address account) public view returns (uint256) {
        return timeBalanceOf(account, block.timestamp, MAX_TIME);
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        safeTransferFrom(msg.sender, recipient, amount, block.timestamp, MAX_TIME);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        if(operatorApprovals[owner][spender]) {
            return 1;
        }
        return 0;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        bool _approved = false;
        if(amount > 0) {
            _approved = true;
        }
        setApprovalForAll(spender, _approved);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        safeTransferFrom(sender, recipient, amount, block.timestamp, MAX_TIME);
        return true;
    }
    
    function onTimeSlicedTokenReceived(address _operator, address _from, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd) public pure returns(bytes4) {
        _operator = address(0);
        _from = address(0);
        amount = 0;
        newTokenStart = 0;
        newTokenEnd = 0;
        return bytes4(keccak256("onTimeSlicedTokenReceived(address,address,uint256,uint256,uint256)"));
    }
}

