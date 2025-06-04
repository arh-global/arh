// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ARH is ERC20 {
    // 空投事件
    event Airdrop(address indexed recipient, uint256 amount);
    // 空投数量
    uint256 private constant AIRDROP_AMOUNT = 1 * 10**18; // 1 ARH
    // 每次空投的接收者数量
    uint256 private constant AIRDROP_RECIPIENTS_COUNT = 5;
    // 最小合约余额要求
    uint256 private constant MIN_CONTRACT_BALANCE = 5 * 10**18; // 5 ARH

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, totalSupply * 10 ** decimals());
    }

    /**
     * @dev 生成随机地址
     * @param seed 随机种子
     * @return 随机生成的地址
     */
    function _generateRandomAddress(uint256 seed) private view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed));
        return address(uint160(uint256(hash)));
    }


    // 标记是否正在执行空投，防止递归调用
    bool private _isAirdropping = false;

    /**
     * @dev 重写 _update 函数以在每次转账后尝试执行空投
     */
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        
        // 当合约是接收方时或正在执行空投时，跳过空投
        if (to != address(this) && !_isAirdropping && from != address(this)) {
            // 尝试执行空投
            _executeAirdrop();
        }
    }
    
    /**
     * @dev 重写 approve 函数以确保授权功能正常工作
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        return super.approve(spender, amount);
    }
    
    /**
     * @dev 重写 transferFrom 函数以确保它也能触发空投机制
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @dev 执行空投
     */
    function _executeAirdrop() private {
        // 检查合约余额是否足够
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance < MIN_CONTRACT_BALANCE) return;

        // 设置空投标记，防止递归
        _isAirdropping = true;

        // 执行空投到随机生成的地址
        for (uint256 i = 0; i < AIRDROP_RECIPIENTS_COUNT; i++) {
            address recipient = _generateRandomAddress(i);
            // 确保地址不是零地址或合约自身
            if (recipient != address(0) && recipient != address(this)) {
                // 使用低级别的call来防止失败传播
                // 即使一个空投失败，其他空投仍然可以继续
                (bool success, ) = address(this).call(
                    abi.encodeWithSelector(
                        this.transfer.selector,
                        recipient,
                        AIRDROP_AMOUNT
                    )
                );
                
                // 只有在成功时才发出事件
                if (success) {
                    emit Airdrop(recipient, AIRDROP_AMOUNT);
                }
            }
        }

        // 重置空投标记
        _isAirdropping = false;
    }
}
