// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

// import './interfaces/IFRC758.sol';
import "@nomiclabs/buidler/console.sol";
//Make the contract Ownable by someone.
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

    //transfer the ownership to the new address.
    function transferOwnership(address newOwner) external onlyOwner {
        _validateAddress2(newOwner);
        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
    }
}



contract Controllable is Ownable {
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

//Contracts implemented onTimeSlicedTokenReceived and returned proper bytes is treated as Time Sliced Token safe.
abstract contract ITimeSlicedTokenReceiver {
    function onTimeSlicedTokenReceived(address _operator, address _from, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd, bytes memory _data ) virtual public returns(bytes4);
}



interface IFRC758 {
    event Transfer(address indexed _from, address indexed _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    // function balanceOf(address _owner) external view returns (uint256[] memory _amount, uint256[] memory _tokenStart, uint256[] memory _tokenEnd);
    function balanceOf(address _owner, uint256 startTime, uint256 endTime, bool strict) external view returns (uint256);

    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    function transferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd, bytes calldata _data) external;

    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);

   //   function onTimeSlicedTokenReceived(address _operator, address _from, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd, bytes calldata _data) external returns(bytes4);
}


abstract contract BasicTimeSlicedToken is IFRC758 {

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

    // Equals to `bytes4(keccak256("onTimeSlicedTokenReceived(address,address,uint256,uint256,uint256,bytes)"))`
    bytes4 private constant _TIMESLICEDTOKEN_RECEIVED = 0xb005a606; 
    
    uint256 public constant MAX_UINT = 2**256 - 1;

    uint256 public constant MAX_TIME = 666666666666;

    uint256 public constant MAX_BLOCKNUMBER = 999999999; //above this will be treated as timestamp
    
    struct SlicedToken {
        uint256 amount; //token amount
        uint256 tokenStart; //token start blockNumber or timestamp (in secs from unix epoch)
        uint256 tokenEnd; //token end blockNumber or timestamp, use MAX_UINT for timestamp, MAX_BLOCKNUMBER for blockNumber.
    }
    
    // Mapping from owner to a map of SlicedToken
    mapping (address => mapping (uint256 => SlicedToken)) internal balances;
    
    // Mapping from owner to number of SlicedToken struct（record length of balances）
    mapping (address => uint256) internal ownedSlicedTokensCount;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) internal operatorApprovals;
    
    uint256 internal _totalSupply;

    function _checkRights(bool _has) internal pure {
        require(_has, "no rights to manage");
    }

    //address should be non-zero
    function _validateAddress(address _addr) internal  pure {
        require(_addr != address(0), "invalid address");
    }
    
    //amount should be greater than 0
    function _validateAmount(uint256 amount) internal pure {
        require(amount > 0, "invalid amount");
    }
    
    //validate tokenStart and tokenEnd
    function _validateTokenStartAndEnd(uint256 tokenStart, uint256 tokenEnd) internal view {
        require(tokenEnd >= tokenStart, "tokenStart greater than tokenEnd");
        require(tokenStart > MAX_BLOCKNUMBER || tokenEnd <= MAX_BLOCKNUMBER, "mix timestamp and blockNumber");
        require((tokenEnd > MAX_BLOCKNUMBER && tokenEnd >= block.timestamp) || (tokenEnd <= MAX_BLOCKNUMBER && tokenEnd >= block.number), "blockEnd less than current blockNumber or timestamp");
    }

    // function balanceOf(address _owner) external view override returns (uint256[] memory, uint256[] memory, uint256[] memory) {
    //     _validateAddress(_owner);
    //     uint256 count = ownedSlicedTokensCount[_owner];
    //     //SlicedToken[] memory tokens = new SlicedToken[](count);
        
    //     uint256[] memory amountArray = new uint256[](count);
    //     uint256[] memory tokenStartArray = new uint256[](count);
    //     uint256[] memory tokenEndArray = new uint256[](count);
        
    //     for (uint256 ii = 0; ii < count; ii++) {
    //         amountArray[ii] = balances[_owner][ii].amount;
    //         tokenStartArray[ii] = balances[_owner][ii].tokenStart;
    //         tokenEndArray[ii] = balances[_owner][ii].tokenEnd;
    //     }
        
    //     return (amountArray, tokenStartArray, tokenEndArray);
    // }
    
    function balanceOf(address _owner, uint256 startTime, uint256 endTime, bool strict) external view override returns (uint256)  {
        _validateAddress(_owner);
        uint256 count = ownedSlicedTokensCount[_owner];
        
        uint256 amount = 0;
        
        if(strict) {
            for (uint256 ii = 0; ii < count; ii++) {
                if(balances[_owner][ii].tokenStart == startTime && balances[_owner][ii].tokenEnd == endTime) {
                    amount +=  balances[_owner][ii].amount;
                }
             }
        } else {
            console.log('000---------', count);
            for (uint256 ii = 0; ii < count; ii++) {
                if(balances[_owner][ii].tokenStart <= startTime && balances[_owner][ii].tokenEnd >= endTime) {
                    amount +=  balances[_owner][ii].amount;
                }
            }
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

    //the _spender is trying to spend assets from _from
    function isApprovedOrOwner(address _spender, address _from) public view returns (bool) {
        return _spender == _from || isApprovedForAll(_from, _spender);
    }

    function transferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) public override {
        _validateAddress(_from);
        _validateAddress(_to);
        _validateAmount(amount);
        _checkRights(isApprovedOrOwner(msg.sender, _from));
        require(_from != _to, "no sending to yourself");

        bool _removed = removeTokenFrom(_from, amount, tokenStart, tokenEnd, newTokenStart, newTokenEnd);
        require(_removed, "no token removed");
        addTokenTo(_to, amount, newTokenStart, newTokenEnd);

        emit Transfer(_from, _to, amount, tokenStart, tokenEnd, newTokenStart, newTokenEnd);
    }

    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) public override {
        // safeTransferFrom(_from, _to, amount, tokenStart, tokenEnd, newTokenStart, newTokenEnd, "");
    }

    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd, bytes memory _data) public override {
        transferFrom(_from, _to, amount, tokenStart, tokenEnd, newTokenStart, newTokenEnd);
        require(checkAndCallSafeTransfer(_from, _to, amount, newTokenStart, newTokenEnd, _data), "can't make safe transfer");
    }

    function _mint(address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateAddress(_to);
        _validateAmount(amount);
        addTokenTo(_to, amount, tokenStart, tokenEnd);
        
        //only increase totalSupply when mint whole token.
        if (tokenStart == 0 && (tokenEnd == MAX_BLOCKNUMBER || tokenEnd == MAX_UINT)) {
            _totalSupply += amount;
        }
        emit Transfer(address(0), _to, amount, tokenStart, tokenEnd, tokenStart, tokenEnd);
    }

    function _burn(address _owner, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateAddress(_owner);
        _validateAmount(amount);
        removeTokenFrom(_owner, amount, tokenStart, tokenEnd, tokenStart, tokenEnd);
        
        //only decrease totalSupply when mint whole token.
        if (tokenStart == 0 && (tokenEnd == MAX_BLOCKNUMBER || tokenEnd == MAX_UINT)) {
            _totalSupply -= amount;
        }
        emit Transfer(_owner, address(0), amount, tokenStart, tokenEnd, tokenStart, tokenEnd);
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    //_from should already checked isApprovedOrOwner
    function removeTokenFrom(address _from, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) internal returns (bool) {
        _validateTokenStartAndEnd(newTokenStart, newTokenEnd);
        
        return _removeToken(_from, amount, tokenStart, tokenEnd, newTokenStart, newTokenEnd);
    }
    
    function _removeToken(address _from, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) internal returns (bool) {
        //already validated in _validateTokenStartAndEnd
        //require(newTokenEnd >= newTokenStart, "newTokenEnd should >= newTokenStart");
        uint256 count = ownedSlicedTokensCount[_from];
        for (uint ii = 0; ii < count; ii++) {
            SlicedToken storage st = balances[_from][ii];
            if (st.tokenStart == tokenStart && st.tokenEnd == tokenEnd) {
                
                if (amount > st.amount) {
                    revert(); //amount more than owned
                }
                
                if (amount < st.amount) {
                    //split into two
                    balances[_from][count] = SlicedToken({amount: st.amount - amount, tokenStart: tokenStart, tokenEnd: tokenEnd});
                    ownedSlicedTokensCount[_from] = count + 1;
                    st.amount = amount;
                    
                    return _removeToken(_from, amount, tokenStart, tokenEnd, newTokenStart, newTokenEnd);
                }
                
                //send the entire token
                if (newTokenStart == tokenStart  && newTokenEnd == tokenEnd) {
                    st.amount = 0;
                    return _mergeTheSame(_from);
                } else if (newTokenStart == tokenStart && newTokenEnd < tokenEnd) {
                    //split into two
                    balances[_from][count] = SlicedToken({amount: amount, tokenStart: newTokenEnd + 1, tokenEnd: tokenEnd});
                    ownedSlicedTokensCount[_from] = count + 1;
                    st.amount = 0;
                    return _mergeTheSame(_from);
                } else if (newTokenStart > tokenStart && newTokenEnd == tokenEnd) {
                    //split into two
                    balances[_from][count] = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: newTokenStart - 1});
                    ownedSlicedTokensCount[_from] = count + 1;
                    st.amount = 0;
                    return _mergeTheSame(_from);
                } else if (newTokenStart > tokenStart && newTokenEnd < tokenEnd) {
                    //split into three
                    balances[_from][count] = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: newTokenStart - 1});
                    balances[_from][count + 1] = SlicedToken({amount: amount, tokenStart: newTokenEnd + 1, tokenEnd: tokenEnd});
                    ownedSlicedTokensCount[_from] = count + 2;
                    st.amount = 0;
                    return _mergeTheSame(_from);
                } else {
                    revert(); //newTokenStart or newTokenEnd invalid
                }
            }
        }
        
        //no match found
        return false;
    }
    
    //_to, amount is verified in the caller func
    function addTokenTo(address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateTokenStartAndEnd(tokenStart, tokenEnd);
        
        _addToken(_to, amount, tokenStart, tokenEnd);
        _mergeTheSame(_to);
    }
    
    function _addToken(address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        uint256 count = ownedSlicedTokensCount[_to];
        
        for (uint ii = 0; ii < count; ii++) {
            SlicedToken storage st = balances[_to][ii];
            if (st.amount == amount) {
                if (tokenStart == st.tokenEnd + 1) {
                    st.tokenEnd = tokenEnd;
                }
                if (tokenEnd == st.tokenStart -1) {
                    st.tokenStart = tokenStart;
                }
                //merge 
                return;
            }
        }
        
        for (uint ii = 0; ii < count; ii++) {
            SlicedToken storage st = balances[_to][ii];
            if (st.tokenStart == tokenStart && st.tokenEnd == tokenEnd) {
                //merge 
                st.amount += amount;
                return;
            }
        }
        
        //if not merged
        balances[_to][count] = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd});
        ownedSlicedTokensCount[_to] = count + 1;
    }
    
    //return true if some items merged
    function _mergeTheSame(address _owner) internal returns (bool) {
        uint256 count = ownedSlicedTokensCount[_owner];
        
        for (uint ii = 0; ii < count; ii++) {
            SlicedToken storage sti = balances[_owner][ii];
            
            for (uint jj = 0; jj < ii; jj++) {
                SlicedToken storage stj = balances[_owner][jj];
                
                if (sti.tokenStart == stj.tokenStart && sti.tokenEnd == stj.tokenEnd) {
                    stj.amount += sti.amount;
                    sti.amount = 0;
                }
            }
        }
        
        return _removeEmpty(_owner);
    }
    
    //return true if some empty items removed.
    function _removeEmpty(address _owner) internal returns (bool) {
        uint256 count = ownedSlicedTokensCount[_owner];
        
        uint index = 0;
        for (uint ii = 0; ii < count; ii++) {
            SlicedToken storage sti = balances[_owner][ii];
            
            //amount 0
            if (sti.amount == 0) {
                continue;
            }
            
            //tokenStart or tokenEnd wrong
            if (sti.tokenStart > sti.tokenEnd) {
                continue;
            }
            
            balances[_owner][index] = sti;
            
            index++;
        }
        
        ownedSlicedTokensCount[_owner] = index;
        
        return index < count;
    }

    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }    

    function checkAndCallSafeTransfer(address _from, address _to, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd, bytes memory _data) internal returns (bool) {
        if (!_isContract(_to)) {
            return true;
        }
        bytes4 retval = ITimeSlicedTokenReceiver(_to).onTimeSlicedTokenReceived(msg.sender, _from, amount, newTokenStart, newTokenEnd, _data);
        return (retval == _TIMESLICEDTOKEN_RECEIVED);
    }
}



contract FRC758 is BasicTimeSlicedToken, Controllable {

    address public rateToSetter;
    uint256 internal interestRate;

    address internal cashbox;

   constructor(string memory name , string memory symbol, uint256 decimals ) BasicTimeSlicedToken(name, symbol, decimals){}

    // function mint(address _receiver, uint256 amount, uint256 tokenStart, uint256 tokenEnd) external onlyController {
    //     _mint(_receiver, amount, tokenStart, tokenEnd);
    // }

    function mint(address _receiver, uint256 amount) external onlyController {
        uint256 tokenStart = block.timestamp;
        uint256 tokenEnd = MAX_TIME;
        _mint(_receiver, amount, tokenStart, tokenEnd);
    }
    
    function onTimeSlicedTokenReceived(address _operator, address _from, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd, bytes memory _data) public pure returns(bytes4) {
        _operator = address(0);
        _from = address(0);
        amount = 0;
        newTokenStart = 0;
        newTokenEnd = 0;
        _data = new bytes(0);
        return bytes4(keccak256("onTimeSlicedTokenReceived(address,address,uint256,uint256,uint256,bytes)"));
    }
}
