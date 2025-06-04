// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.2;


// ownable upgradable
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router.sol";
import "./IERC20.sol";

interface IERC721 {
    function safeMint(address to, uint256 tokenId, string memory uri) external;
}

contract Core2 is OwnableUpgradeable {
    using Strings for uint256; // Using OpenZeppelin's Strings library for uint256 conversion
    // constructor

    struct User {
        bool isValid; // in order, grow from the single root
        address referrer;
        uint16 directCount;
        address childrenHead;
        address nextBrother;
        uint128 allCount;
        uint256 time;
        uint16 orderCount;
        bool hasBought;
    }

    uint256[6] public prices;
    IERC20 public ARF;
    IERC20 public ARS;
    IERC20 public ARG;



    mapping(address => User) public Members;

    address public black_hole;

    uint8 public ratio;

    IUniswapV2Router public router;
    IERC20 public USDT;

    bool public switchToNewDeposit;

    event Bought(address indexed _user, uint8 _index, uint256 _price, uint256 _arg_amount, uint256 _arf_amount);
    event Bind(address indexed _user, address indexed _up);
    event Bind2(address indexed _user, address indexed _up, uint8 _type);
    event Received(address indexed _sender, uint256 _value, address indexed _u);

    uint16 public partnerRatio;
    address public partnerReceiver;
    uint256 public partnerPrice;

    uint256 public partnerCount;
    uint256 public partnerTotal;
    mapping(address => bool) public isPartner;

    function ifPartner(address _user) public view returns (bool) {
        return isPartner[_user];
    }
    function remianingPartner() public view returns (uint256) {
        return partnerTotal - partnerCount;
    }
    function updateParterConfig(address _partnerReceiver, uint16 _partnerRatio, uint256 _partnerPrice, uint256 _testPrice, uint16 _total) public onlyOwner {
        require(_partnerReceiver != address(0), "Invalid partner receiver address");
        require(_partnerRatio <= 100, "Invalid partner ratio");
        partnerReceiver = _partnerReceiver;
        partnerRatio = _partnerRatio;
        partnerPrice = _partnerPrice;
        partnerTotal = _total;
    }
    event PurchasePartnership(address indexed user, uint256 amount);

    function purchasePartership() public{
        // require valid 
        require(Members[msg.sender].isValid, "User is not valid");
        // require not partner already
        require(!isPartner[msg.sender], "User is already a partner");
        // transfer usdt to contract
        require(USDT.transferFrom(msg.sender, address(this), partnerPrice), "USDT transfer failed");
        // tranfer 20% to up
        address upline = Members[msg.sender].referrer; 
        uint256 uplineAmount = 0;
        if (upline != address(0)) {
            uplineAmount = partnerPrice * partnerRatio / 100;
            require(USDT.transfer(upline, uplineAmount), "Transfer to upline failed");
        }
        // transfer remain to partner receiver
        uint256 partnerAmount = partnerPrice - uplineAmount;
        require(USDT.transfer(partnerReceiver, partnerAmount), "Transfer to partner receiver failed");
        partnerCount += 1;
        isPartner[msg.sender] = true;
        emit PurchasePartnership(msg.sender, partnerPrice);
    }

    function initialize() public initializer {
        __Ownable_init();
        prices = [100e18, 500e18, 1000e18, 3000e18, 5000e18, 10000e18];

        Members[msg.sender].isValid = true;
        Members[msg.sender].hasBought = true;

        ARF = IERC20(0xf2DEe9CBa278E3Fb4229f22723cB1DFd174fcFC3);
        ARG = IERC20(0x4D91A28186906F43dc696309764930Db105BD724);
        ARS = IERC20(0x2F3cb58707D5185c968D2f448AfE256486De6C36);

        black_hole = 0x000000000000000000000000000000000000dEaD;
        switchToNewDeposit = true;
    }

    function changeToken(address _ARF, address _ARS, address _ARG, address _USDT) public onlyOwner {
        ARF = IERC20(_ARF);
        ARS = IERC20(_ARS);
        ARG = IERC20(_ARG);
        USDT = IERC20(_USDT);
    }

    function changeRatio(uint8 _ratio) public onlyOwner {
        ratio = _ratio;
    }

    function deposit(uint8 _idx, uint256 _order_id) public payable {
        if(_idx == 1) {
            ARG.transferFrom(msg.sender, black_hole, 10*10**18);
            emit Bought(msg.sender, 3, _order_id, 0, 0);
        }else if(_idx == 2) {
            ARG.transferFrom(msg.sender, black_hole, 100*10**18);
            emit Bought(msg.sender, 4, _order_id, 0, 0);
        }
    }

    function buy(uint256 pkg_idx, uint8 token_idx, uint256 arg_price) public payable {
        require(pkg_idx < 6, "Invalid package index");
        require(token_idx < 6, "Invalid token index");
        uint256 arg_amount = 0;
        uint256 arf_amount = 0;
        if(token_idx == 0) {
            ARS.transferFrom(msg.sender, black_hole, prices[pkg_idx]);
            emit Bought(msg.sender, token_idx, prices[pkg_idx], arg_amount, arf_amount);
        }else if(token_idx == 1) {
            require(arg_price > 0, "ARG price is 0");
            arg_amount = (prices[pkg_idx] * 10**8) / arg_price;
            ARG.transferFrom(msg.sender, black_hole, arg_amount);
            emit Bought(msg.sender, token_idx, prices[pkg_idx], arg_amount, arf_amount);
        }else if(token_idx == 2) {
            ARS.transferFrom(msg.sender, black_hole, prices[pkg_idx]*ratio/100);
            uint256 usdt_amount_for_arg = ((100-ratio)*prices[pkg_idx])/100;
            arg_amount = usdt_amount_for_arg * 10**8 / arg_price;
            ARG.transferFrom(msg.sender, black_hole, arg_amount);
            emit Bought(msg.sender, token_idx, prices[pkg_idx], arg_amount, arf_amount);
        }else if(token_idx == 3 && !switchToNewDeposit) {
            ARG.transferFrom(msg.sender, black_hole, 10*10**18);
            emit Bought(msg.sender, token_idx, 0, arg_amount, arf_amount);
        }else if(token_idx == 4 && !switchToNewDeposit) {
            ARG.transferFrom(msg.sender, black_hole, 100*10**18);
            emit Bought(msg.sender, token_idx, 0, arg_amount, arf_amount);
        }else if(token_idx == 5){
            ARS.transferFrom(msg.sender, black_hole, prices[pkg_idx]);
            emit Bought(msg.sender, token_idx, prices[pkg_idx], arg_amount, arf_amount);
        }
        Members[msg.sender].hasBought = true;
    }

    function changeSwitchToNewDeposit(bool _switchToNewDeposit) public onlyOwner {
        switchToNewDeposit = _switchToNewDeposit;
    }


    function buy_view(uint256 pkg_idx, uint8 token_idx, uint256 arg_price) public view returns (uint256, uint256, uint256) {
        uint256 arg_amount = 0;
        uint256 arf_amount = 0;
        uint256 ars_amount = 0;
        if(token_idx == 0) {
            ars_amount = prices[pkg_idx]*ratio/100;
            uint256 usdt_amount_for_arf = ((100-ratio)*prices[pkg_idx])/100;
            uint256 one_usdt = 10**18;
            arf_amount = tokenToUSDT(address(ARF), one_usdt) * usdt_amount_for_arf / one_usdt;
        }else if(token_idx == 1) {
            ars_amount = prices[pkg_idx]*ratio/100;
            uint256 usdt_amount_for_arf = ((100-ratio)*prices[pkg_idx])/100;
            arf_amount = tokenToUSDT(address(ARF), usdt_amount_for_arf);
        }
        return (ars_amount, arg_amount, arf_amount);
    }



    function referee(address _user) public view returns (address[] memory) {
        address[] memory result = new address[](Members[_user].directCount);
        address child = Members[_user].childrenHead;
        for (uint256 i = 0; i < Members[_user].directCount; i++) {
            if (child == address(0)) {
                break;
            }
            result[i] = child;
            child = Members[child].nextBrother;
        }
        return result;
    }

    function new_bind(address _up, uint8 _type) public payable {
        require(Members[_up].isValid, "Up is not valid");
        require(!Members[msg.sender].isValid, "Sender is already valid");

        Members[msg.sender].isValid = true;
        Members[msg.sender].referrer = _up;

        address currentChildrenHead = Members[_up].childrenHead;
        Members[msg.sender].nextBrother = currentChildrenHead;
        Members[_up].childrenHead = msg.sender;
        Members[_up].directCount += 1;
        address _user = _up;
        while (_user != address(0)) {
            Members[_user].allCount += 1;
            _user = Members[_user].referrer;
        }
        Members[msg.sender].time = block.timestamp;
        emit Bind2(msg.sender, _up, _type);
    }


    function bind(address _up) public payable {
        require(Members[_up].isValid, "Up is not valid");
        require(!Members[msg.sender].isValid, "Sender is already valid");

        Members[msg.sender].isValid = true;
        Members[msg.sender].referrer = _up;

        address currentChildrenHead = Members[_up].childrenHead;
        Members[msg.sender].nextBrother = currentChildrenHead;
        Members[_up].childrenHead = msg.sender;
        Members[_up].directCount += 1;
        address _user = _up;
        while (_user != address(0)) {
            Members[_user].allCount += 1;
            _user = Members[_user].referrer;
        }
        Members[msg.sender].time = block.timestamp;
        emit Bind(msg.sender, _up);
    }

    function claim(address _user, uint256 _amount) public onlyOwner {
        payable(_user).transfer(_amount);
    }

    // claim ERC20 from contract
    function claimERC20(address _token, address _user, uint256 _amount) public onlyOwner {
        IERC20(_token).transfer(_user, _amount);
    }

    // allow send eth to contract
    receive() external payable {
        emit Received(msg.sender, msg.value, address(this));
    }

    function setRouter(address _router) public onlyOwner {
        router = IUniswapV2Router(_router);
    }



    /**
     * @notice Calculates how many tokens are needed to get _amount of USDT
     * @dev Uses two-hop path: Token -> BNB -> USDT
     * @param _amount The target amount of USDT to receive
     * @return The amount of tokens needed
     */
    function tokenToUSDT(address _token, uint256 _amount) public view returns (uint256) {
        if (_amount == 0) return 0;
        require(address(router) != address(0), "Router not set");

        // Check if the BNB/USDT pair exists
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        address bnbUsdtPair = factory.getPair(address(USDT), address(router.WETH()));
        if (bnbUsdtPair == address(0)) return 0;

        // Check if the Token/BNB pair exists
        address tokenBnbPair = factory.getPair(_token, address(router.WETH()));
        if (tokenBnbPair == address(0)) return 0;

        // Step 1: Calculate how much BNB is needed for the target USDT amount
        address[] memory path1 = new address[](2);
        path1[0] = address(router.WETH());  // BNB
        path1[1] = address(USDT);

        uint256[] memory bnbAmount;
        try router.getAmountsIn(_amount, path1) returns (uint256[] memory amounts) {
            bnbAmount = amounts;
        } catch {
            return 0;  // Return 0 if calculation fails
        }

        if (bnbAmount[0] == 0) return 0;

        // Step 2: Calculate how many tokens are needed to get that BNB amount
        address[] memory path2 = new address[](2);
        path2[0] = _token;  // Token
        path2[1] = address(router.WETH());  // BNB

        try router.getAmountsIn(bnbAmount[0], path2) returns (uint256[] memory amounts) {
            return amounts[0];  // Amount of tokens needed
        } catch {
            return 0;  // Return 0 if calculation fails
        }
    }
}
