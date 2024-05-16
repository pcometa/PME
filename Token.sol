// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PMETokenV2
 * @dev Extends ERC20 token with additional features like whitelisting, blacklisting, and balance blocking.
 */
contract PMETokenV2 is ERC20, Ownable {
    struct UserSettings {
        bool whitelistEnabled; // Flag indicating whether whitelist is enabled for the user
        mapping(address => bool) whitelist; // Mapping of whitelisted addresses for the user
        mapping(address => uint256) whiteListTransferAble;
    }


    mapping(address => UserSettings) private _userSettings; // Mapping of user settings
    mapping(address => uint256) private _blockedBalances; // Mapping of blocked balances for addresses
    mapping(address => bool) private _blacklist; // Mapping of blacklisted addresses

    event WhitelistAdded(address indexed user, address indexed allowedAddress); // Event emitted when an address is added to whitelist
    event WhitelistRemoved(address indexed user, address indexed disallowedAddress); // Event emitted when an address is removed from whitelist
    event BalanceBlocked(address indexed account, uint256 amount); // Event emitted when balance is blocked for an account
    event BalanceUnblocked(address indexed account, uint256 amount); // Event emitted when blocked balance is unblocked for an account
    event Blacklisted(address indexed account); // Event emitted when an account is blacklisted
    event RemovedFromBlacklist(address indexed account); // Event emitted when an account is removed from blacklist
    event Mint(address indexed to, uint256 amount); // Event emitted when tokens are minted

    /**
     * @dev Constructor function to initialize the ERC20 token with a name and symbol.
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender){}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @dev Overrides the transfer function to include additional checks for blacklist and whitelist.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(!_blacklist[msg.sender], "Sender is blacklisted");
        require(!_blacklist[recipient], "Recipient is blacklisted");
        if (_userSettings[msg.sender].whitelistEnabled){
            require(_userSettings[msg.sender].whitelist[recipient], "Recipient is not whitelisted");
            require(_userSettings[msg.sender].whiteListTransferAble[recipient] >= amount, "Insufficient transferable amount");
            _userSettings[msg.sender].whiteListTransferAble[recipient] -= amount;
        }
        require(balanceOf(msg.sender) - _blockedBalances[msg.sender] >= amount, "Transfer amount exceeds unblocked balance");
        return super.transfer(recipient, amount);
    }

    /**
     * @dev Overrides the transferFrom function to include additional checks for blacklist and whitelist.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(!_blacklist[sender], "Sender is blacklisted");
        require(!_blacklist[recipient], "Recipient is blacklisted");
        if (_userSettings[sender].whitelistEnabled){
            require(_userSettings[sender].whitelist[recipient], "Recipient is not whitelisted");
            require(_userSettings[sender].whiteListTransferAble[recipient] >= amount, "Insufficient transferable amount");
            _userSettings[sender].whiteListTransferAble[recipient] -= amount;
        }
        require(balanceOf(sender) - _blockedBalances[sender] >= amount, "Transfer amount exceeds unblocked balance");
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @dev Adds an address to the whitelist.
     */
    function addToWhitelist(address user, address allowedAddress, uint256 amount) external onlyOwner {
        require(_userSettings[user].whitelistEnabled, "Whitelist is not enabled");
        require(!(_userSettings[user].whitelist[allowedAddress]), "Address is already whitelisted");
        _userSettings[user].whitelist[allowedAddress] = true;
        _userSettings[user].whiteListTransferAble[allowedAddress] = amount;
        emit WhitelistAdded(user, allowedAddress);
    }

    /**
     * @dev Adds multiple addresses to the whitelist.
     */
    function batchAddToWhitelist(address user, address[] memory allowedAddresses, uint256[] memory amounts) external onlyOwner {
        require(_userSettings[user].whitelistEnabled, "Whitelist is not enabled");
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            require(!(_userSettings[user].whitelist[allowedAddresses[i]]), "Address is already whitelisted");
            _userSettings[user].whitelist[allowedAddresses[i]] = true;
            _userSettings[user].whiteListTransferAble[allowedAddresses[i]] = amounts[i];
            emit WhitelistAdded(user, allowedAddresses[i]);
        }
    }

    /**
     * @dev Removes an address from the whitelist.
     */
    function removeFromWhitelist(address user, address disallowedAddress) external onlyOwner {
        require(_userSettings[user].whitelistEnabled, "Whitelist is not enabled");
        require(_userSettings[user].whitelist[disallowedAddress], "Address is not whitelisted");
        delete _userSettings[user].whitelist[disallowedAddress];
        delete _userSettings[user].whiteListTransferAble[disallowedAddress];
        emit WhitelistRemoved(user, disallowedAddress);
    }

    /**
     * @dev Removes multiple addresses from the whitelist.
     */
    function batchRemoveFromWhitelist(address user, address[] memory disallowedAddresses) external onlyOwner {
        require(_userSettings[user].whitelistEnabled, "Whitelist is not enabled");
        for (uint256 i = 0; i < disallowedAddresses.length; i++) {
            require(_userSettings[user].whitelist[disallowedAddresses[i]], "Address is not whitelisted");
            delete _userSettings[user].whitelist[disallowedAddresses[i]];
            delete _userSettings[user].whiteListTransferAble[disallowedAddresses[i]];
            emit WhitelistRemoved(user, disallowedAddresses[i]);
        }
    }

    /**
     * @dev Enables whitelist for a user.
     */
    function enableWhitelist(address user) external onlyOwner {
        require(!(_userSettings[user].whitelistEnabled), "Whitelist is already enabled");
        _userSettings[user].whitelistEnabled = true;
    }

    /**
     * @dev Disables whitelist for a user.
     */
    function disableWhitelist(address user) external onlyOwner {
        require(_userSettings[user].whitelistEnabled, "Whitelist is already disabled");
        _userSettings[user].whitelistEnabled = false;
    }

    /**
     * @dev Blocks balance for an account.
     */
    function blockBalance(address account, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(_blockedBalances[account] + amount <= balanceOf(account), "Insufficient balance");
        _blockedBalances[account] += amount;
        emit BalanceBlocked(account, amount);
    }

    /**
     * @dev Unblocks balance for an account.
     */
    function unblockBalance(address account, uint256 amount) external onlyOwner {
        require(_blockedBalances[account] >= amount, "Insufficient blocked balance");
        require(amount > 0, "Amount must be greater than zero");
        require(_blockedBalances[account] - amount >= 0, "Blocked balance cannot be negative");
        _blockedBalances[account] -= amount;
        emit BalanceUnblocked(account, amount);
    }

    /**
     * @dev Blacklists an account.
     */
    function blacklist(address account) external onlyOwner {
        _blacklist[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Removes an account from the blacklist.
     */
    function removeFromBlacklist(address account) external onlyOwner {
        _blacklist[account] = false;
        emit RemovedFromBlacklist(account);
    }

    /**
     * @dev Checks if an account is blacklisted.
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklist[account];
    }

    /**
     * @dev Gets the blocked balance for an account.
     */
    function getBlockedBalance(address account) external view returns (uint256) {
        return _blockedBalances[account];
    }

    /**
     * @dev Mints tokens and sends them to the specified account.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(!_blacklist[to], "To is blacklisted");
        require(amount > 0, "Amount must be greater than zero");
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function getWhitelistedAmount(address user, address whitelistedUser) external view returns (uint256) {
        return _userSettings[user].whiteListTransferAble[whitelistedUser];
    }

    function burn(uint256 amount) external returns(bool){
        if(balanceOf(msg.sender) < amount) revert ("You dont own enough tokens");
        _burn(msg.sender, amount);
        return true;
    }
}
