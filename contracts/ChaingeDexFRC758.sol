pragma solidity >=0.5.16;

import '@uniswap/v2-core/contracts/libraries/SafeMath.sol';
import "@nomiclabs/buidler/console.sol";
import './interfaces/IFRC758.sol';

// IERC777
import './interfaces/IERC1820Registry.sol';
import './interfaces/IERC777Sender.sol';

contract ChaingeDexFRC758 is IFRC758{
    using SafeMath for uint;
    string public constant name = 'ChaingeDex';
    string public constant symbol = 'ChaingeDex';
    uint8 public constant decimals = 18;
    uint  public totalSupply;
    // mapping(address => uint) public balanceOf;
    // mapping(address => mapping(address => uint)) public allowance;
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    IERC1820Registry constant internal _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");

    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    mapping(address => uint) public nonces;

    uint256 public constant MAX_TIME = 18446744073709551615;

    event Approval(address indexed owner, address indexed spender, uint value);
    // event Transfer(address indexed from, address indexed to, uint value);
    event Transfer(address indexed _from, address indexed _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd);
    event ApprovalForAll(address indexed _owner, address indexed _operator, uint256 _approved);

    struct SlicedToken {
        uint256 amount; 
        uint256 tokenStart; 
        uint256 tokenEnd;
        uint256 next;
    }

    mapping (address => mapping (uint256 => SlicedToken)) internal balances;
    
    mapping (address => uint256) internal balance;

    mapping (address => uint256) internal ownedSlicedTokensCount;

    mapping (address => mapping (address => uint256)) internal operatorApprovals;

    mapping (address => uint256 ) headerIndex;
    
    constructor() public {

        uint chainId = 32659;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function _mint(address _from, uint256 amount) internal {

        _validateAmount(amount);

        _callTokensToSend(address(this), address(0), _from, amount, "", "");
        
        balance[_from] = balance[_from].add(amount);

        totalSupply += amount;
        
        emit Transfer(address(0), _from, amount, 0, MAX_TIME);
    }

    function _burn(address _from, uint256 amount) internal {
        _validateAddress(_from);
        _validateAmount(amount);
        balance[_from] = balance[_from].sub(amount);
        totalSupply -= amount;

        emit Transfer(_from, address(0), amount, 0, MAX_TIME);
    }

    function _mintSlice(address _from,  uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateAddress(_from);
        _validateAmount(amount);
        SlicedToken memory st = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
        _addSliceToBalance(_from, st);
        emit Transfer(address(0), _from, amount, 0, MAX_TIME);
    }

    function _burnSlice(address _from, uint256 amount, uint256 tokenStart, uint256 tokenEnd) internal {
        _validateAddress(_from);
        _validateAmount(amount);
        SlicedToken memory st = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
        _subSliceFromBalance(_from, st);
        emit Transfer(_from, address(0), amount, tokenStart, tokenEnd);
    }

    function transfer(address to, uint value) external returns (bool) {
        transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 amount) public returns (bool) { 

        _validateAddress(_from);
        _validateAddress(_to);
        _validateAmount(amount);

         if(msg.sender != _from) {
            require(operatorApprovals[_from][msg.sender] >= amount, 'ChaingeDexFRC758: Authorization required');
            operatorApprovals[_from][msg.sender] = operatorApprovals[_from][msg.sender].sub(amount);
         }

        _callTokensToSend(address(this), _from, _to, amount, "", "");


        if(amount <= balance[_from]) {
            require(balance[_from] >= amount, 'ChaingeDexFRC758: Insufficient balance');
            balance[_from] = balance[_from].sub(amount);
            balance[_to] = balance[_to].add(amount);
			emit Transfer(_from, _to, amount, 0, MAX_TIME);
            return true;
        }

        require(amount >= balance[_from], 'ChaingeDexFRC758: Insufficient balance2');
        uint256 _amount = amount.sub(balance[_from]);
        balance[_from] = 0;

        SlicedToken memory st = SlicedToken({amount: _amount, tokenStart: block.timestamp, tokenEnd: MAX_TIME, next: 0});


        _subSliceFromBalance(_from, st);
        balance[_to] = balance[_to].add(amount);
		
		emit Transfer(_from, _to, amount, 0, MAX_TIME);
        return true;
    }

    function timeSliceTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) public {
        _validateAddress(_from);
        _validateAddress(_to);
        _validateAmount(amount);

        if(msg.sender != _from) {
            operatorApprovals[_from][msg.sender] = operatorApprovals[_from][msg.sender].sub(amount);
        }

        require(_from != _to, "FRC758: can not send to yourself");
        if(tokenStart < block.timestamp) tokenStart = block.timestamp;
        require(tokenStart < tokenEnd, "FRC758: tokenStart>=tokenEnd");

        if(tokenEnd == MAX_TIME) {
            _callTokensToSend(address(this), _from, _to, amount, "", ""); 
        }

        uint256 timeBalance = timeBalanceOf(_from, tokenStart, tokenEnd); 

        if(amount <= timeBalance) {
            SlicedToken memory st = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
            _subSliceFromBalance(_from, st);
            _addSliceToBalance(_to, st);
            emit Transfer(_from, _to, amount, 0, MAX_TIME);
            return;
        }

        uint256 _amount = amount.sub(timeBalance); 

        if(timeBalance != 0) {
            SlicedToken memory st = SlicedToken({amount: timeBalance, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0}); 
            _subSliceFromBalance(_from, st);  
        }

        balance[_from] = balance[_from].sub(_amount); 

        change(_from, _amount, tokenStart, tokenEnd);

        if(tokenStart <= block.timestamp && tokenEnd == MAX_TIME) {
            balance[_to] = balance[_to].add(amount);
            emit Transfer(_from, _to, amount, 0, MAX_TIME);
            return;
        }
        SlicedToken memory toSt = SlicedToken({amount: amount, tokenStart: tokenStart, tokenEnd: tokenEnd, next: 0});
        _addSliceToBalance(_to, toSt); 
        
        emit Transfer(_from, _to, amount, tokenStart, tokenEnd);
    }

    function change(address _from, uint256 _amount, uint256 tokenStart, uint256 tokenEnd) internal {
        if(tokenStart > block.timestamp) {
              SlicedToken memory leftSt = SlicedToken({amount: _amount, tokenStart: block.timestamp, tokenEnd: tokenStart, next: 0});
             _addSliceToBalance(_from, leftSt);
        }
        if(tokenEnd < MAX_TIME) {
            if(tokenEnd < block.timestamp) tokenEnd =  block.timestamp;
            SlicedToken memory rightSt = SlicedToken({amount: _amount, tokenStart: tokenEnd, tokenEnd: MAX_TIME, next: 0});
            _addSliceToBalance(_from, rightSt); 
        }
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'ChaingeDex: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'ChaingeDex: INVALID_SIGNATURE');
        _approve(spender, value);
    }

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
    function _validateTokenStartAndEnd(uint256 tokenStart, uint256 tokenEnd) internal view {
        require(tokenEnd >= tokenStart, "tokenStart greater than tokenEnd");
        require((tokenEnd >= block.timestamp), "blockEnd less than current timestamp");
    }

    function sliceOf(address from) public view returns (uint256[] memory, uint256[] memory, uint256[] memory) {
        _validateAddress(from);
        uint256 header = headerIndex[from];
        if(header == 0 &&  balance[from] == 0) {
            return (new uint256[](0), new uint256[](0), new uint256[](0));
        }
        uint256 count = ownedSlicedTokensCount[from];

        uint256[] memory amountArray = new uint256[](count+1);
        uint256[] memory tokenStartArray = new uint256[](count+1);
        uint256[] memory tokenEndArray = new uint256[](count +1);
        
        amountArray[0] = balance[from];
        tokenStartArray[0] = 0;
        tokenEndArray[0] = MAX_TIME;
        
        for (uint256 ii = 0; ii < count; ii++) {
            amountArray[ii+1] = balances[from][ii +1].amount;
            tokenStartArray[ii+1] = balances[from][ii+1].tokenStart;
            tokenEndArray[ii+1] = balances[from][ii+1].tokenEnd;
        }

        return (amountArray, tokenStartArray, tokenEndArray);
    }

    function timeBalanceOf(address from, uint256 tokenStart, uint256 tokenEnd) public view returns(uint256) {
       if (tokenStart >= tokenEnd) {
           return 0;
       }
       uint next = headerIndex[from];
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
    function balanceOf(address account) public view returns (uint256) {
        return timeBalanceOf(account, block.timestamp, MAX_TIME) + balance[account];
    }

    function _approve(address _spender, uint value) private {
        require(_spender != msg.sender, "FRC758: wrong approval destination");
        operatorApprovals[msg.sender][_spender] = value;
        emit ApprovalForAll(msg.sender, _spender, value);
    }

    function approve(address spender,  uint256 amount) public {
        _approve(spender, amount);
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return operatorApprovals[_owner][_spender];
    }

    function _addSliceToBalance(address addr, SlicedToken memory st) internal {
        uint256 count = ownedSlicedTokensCount[addr];
        if(count == 0) {
             balances[addr][1] = st;
             ownedSlicedTokensCount[addr] = 1;
             headerIndex[addr] = 1;
             return;
        }

        uint current = headerIndex[addr];
               
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
                uint index = _addSlice(addr, st.tokenStart, currSt.tokenStart, st.amount, current);
                if(current == headerIndex[addr]) {
                    headerIndex[addr] = index;  
                }else {
                    uint _current = headerIndex[addr];
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
                    uint currStEndTime = currSt.tokenEnd ;
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
                    uint index = _addSlice(addr, st.tokenEnd, currStTokenEnd, currStAmount, currSt.next);
                    currSt.next = index;
                    return;
                }
            }
            if( currSt.tokenEnd > st.tokenStart && currSt.tokenEnd >= st.tokenStart) {
                  uint256 currStTokenEnd = currSt.tokenEnd;
                  if(currSt.tokenStart < st.tokenStart) {
                    currSt.tokenEnd = st.tokenStart; 
                    uint index = _addSlice(addr, st.tokenStart, currStTokenEnd, currSt.amount + st.amount, currSt.next);
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
                uint index = _addSlice(addr, st.tokenStart, st.tokenEnd, st.amount, 0);
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

        require( count != 0, 'ChaingeDexFRC758: _subSliceFromBalance: count=0');

        uint current = headerIndex[addr];
        do {
            SlicedToken storage currSt = balances[addr][current]; 

            if(currSt.tokenEnd < block.timestamp) { 
                headerIndex[addr] = currSt.next; 
                current = currSt.next;
                continue;
            }
            require(st.amount <= currSt.amount, 'FRC758: insufficient balance');
            require(currSt.tokenStart < st.tokenEnd, 'FRC758: subSlice time check fail point 1');
            require(!(currSt.next == 0 && currSt.tokenEnd < st.tokenEnd), 'FRC758: subSlice time check fail point 2');
            require(!(currSt.tokenStart < st.tokenEnd && currSt.tokenStart > st.tokenStart), 'FRC758: subSlice time check fail point 3');

            if(currSt.tokenStart == st.tokenStart && currSt.tokenEnd == st.tokenEnd) {
                require(currSt.amount  >= st.amount, 'ChaingeDexFRC758: Insufficient currSt balance');
                currSt.amount -= st.amount;
                return;
            }

            if(currSt.tokenStart == st.tokenStart ) {
                if(currSt.tokenEnd > st.tokenEnd) {
                    uint256 currStAmount = currSt.amount;
                    require(currSt.amount  >= st.amount, 'ChaingeDexFRC758: Insufficient currSt balance2');
                    currSt.amount -= st.amount;
                    uint256 currStTokenEnd = currSt.tokenEnd;
                    currSt.tokenEnd = st.tokenEnd;
                    uint256 index = _addSlice(addr, st.tokenEnd, currStTokenEnd, currStAmount,  currSt.next);
                    currSt.next = index;
                    break;
                }
                require(currSt.amount  >= st.amount, 'ChaingeDexFRC758: Insufficient currSt balance3');
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
                require(currSt.amount  >= st.amount, 'ChaingeDexFRC758: Insufficient currSt balance4');
                currSt.amount -= st.amount;
                currSt.tokenStart = st.tokenStart;
                if(currStTokenEnd >= st.tokenEnd) {
                    if(currStTokenEnd > st.tokenEnd) {
                         uint256 index2 = _addSlice(addr, st.tokenEnd, currStTokenEnd, currStAmunt, currSt.next);
                         currSt.next = index2;
                    }
                    break; 
                }
                st.tokenStart = currStTokenEnd;
            }
            current = currSt.next;
        }while(current>0);
    }

    function _clean(address from, uint256 tokenStart, uint256 tokenEnd) internal {
        uint256 minBalance = timeBalanceOf(from, tokenStart, tokenEnd);
		uint256 firstDeletedIndex = 0;
        uint256 lastIndex = 0;
        uint256 _tokenStart = tokenStart;
		uint256 next = headerIndex[from];

		while(next > 0) {
		    SlicedToken memory st = balances[from][next];

            if(tokenEnd < st.tokenStart) {
                lastIndex = next;
                break;
            }

            if(tokenStart >= st.tokenEnd || tokenEnd <= st.tokenStart) {
                lastIndex = next;
                next = st.next;
                continue;
            }

            delete balances[from][next];
            if(firstDeletedIndex == 0) {
                firstDeletedIndex = next; 
            }

            tokenStart = st.tokenEnd;
            lastIndex = next;
            next = st.next;
        }

        if(firstDeletedIndex != 0 && firstDeletedIndex != lastIndex) { // move last to first
             balances[from][firstDeletedIndex] = balances[from][lastIndex];
             delete balances[from][lastIndex];
        }

        if(minBalance > 0) {
            _mintSlice(from, minBalance, _tokenStart, tokenEnd);  
        }  
    }
    
    /**
     * @dev Call from.tokensToSend() if the interface is registered
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    )
        private
    {
        if(from == address(0) && to == address(0)) { // 给全0地址mint不处理
            return;
        }

        address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(operator, _TOKENS_SENDER_INTERFACE_HASH);
        console.log('_callTokensToSend_______', implementer, from, to);
         console.log('_callTokensToSend_______ amount', amount);
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }
}
