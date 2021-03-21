// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// Standard ERC20 token implementation. See the docs for more info:
// https://eips.ethereum.org/EIPS/eip-20
// https://docs.openzeppelin.com/contracts/3.x/api/token/erc20
contract ERC20 {
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    uint256 internal _totalSupply; // TODO: maybe separate this into initialSupply, mintedSupply, burnedSupply...?
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowed;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function name() public view returns (string memory) { return _name; }
    function symbol() public view returns (string memory) { return _symbol; }
    function decimals() public view returns (uint8) { return _decimals; }

    // totalSupply is updated on its own whether tokens are minted/burned
    function totalSupply() public view returns (uint256) { return _totalSupply; }

    function balanceOf(address _owner) public view returns (uint256) { return _balances[_owner]; }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0), "ERC20: transfer to zero address");
        require(_balances[msg.sender] >= _value, "ERC20: insufficient funds");

        _balances[msg.sender] -= _value;
        _balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // TODO: prevent attack vectors (see https://eips.ethereum.org/EIPS/eip-20#approve)
    function approve(address _spender, uint _value) public returns (bool) {
        require(_spender != address(0), "ERC20: approval from zero address");

        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return _allowed[_owner][_spender];
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        require(_from != address(0), "ERC20: transfer from zero address");
        require(_to != address(0), "ERC20: transfer to zero address");
        require(_balances[_from] >= _value, "ERC20: insufficient funds");
        require(_allowed[_from][msg.sender] >= _value, "ERC20: insufficient allowed funds");

        _balances[_from] -= _value;
        _allowed[_from][msg.sender] -= _value;
        _balances[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }
}

// Contract for the token
contract POWToken is ERC20 {

    uint256 internal _lastSolutionTime;
    uint256 internal _currentDifficulty;
    bytes32 internal _currentWork;
    event Minted(address indexed _to, uint256 _value);
    event Burned(address indexed _from, uint256 _value);
    event SwitchedMinter(address indexed _old, address indexed _new);

    constructor() {
        _name = "Test contract";
        _symbol = "TEST";
        _decimals = 18; // Default is 18, highly recommended
        _totalSupply = 1 * (10 ** _decimals); // 100 million * (10^18 decimals)
        _balances[msg.sender] = _totalSupply;
        _currentDifficulty = uint256(0x00000ffff0000000000000000000000000000000000000000000000000000000);
        _currentWork = blockhash(block.number - 1);
        _lastSolutionTime = block.timestamp;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // Minting

    function mint(address _to, uint256 _amount) private returns (bool) {
        require(_to != address(0), "Minting to zero account is forbidden");
        require(_amount > 0, "Minting requires a non-zero amount");
        
        _totalSupply += _amount;
        _balances[_to] += _amount;
        emit Minted(_to, _amount);
        
        return true;
    }
    
    function GetDifficulty() public view returns (uint256) {
        return _currentDifficulty;
    }
    
    function GetWork() public view returns (bytes32) {
        return _currentWork;
    }
    
    function SetDifficulty() public returns (bool) {
        uint256 diffTime = block.timestamp - _lastSolutionTime;
        
        if (diffTime > 60) {
            _currentDifficulty = (_currentDifficulty / 10) * 8;
        } else {
            _currentDifficulty = (_currentDifficulty / 10) * 12;
        }
        return true;    
    }

    function submitWork(uint128 nNonce) public returns (bool) {
        // Worker hash should include the block hash which he setted the work, his own address (each miner work is unique) and their nNonce.
        // Avoid multiple submitions of the same work
        require (_currentWork != blockhash(block.number - 1), "Validating work at the same block is forbidden");
        bytes memory solution = abi.encodePacked(GetWork(), msg.sender, nNonce);

        bytes32 powHash = keccak256(abi.encodePacked(solution));
        uint256 result = uint256(powHash);
        assert(result < GetDifficulty()); // Check if work meets
        SetDifficulty();
        _lastSolutionTime = block.timestamp;
        _currentWork = blockhash(block.number - 1);
        mint(msg.sender, 1 * (10 ** _decimals));
        return true; 
    }
}

