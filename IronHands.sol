// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title  Iron Hands — a personal trading circuit breaker
/// @author makabeez
/// @notice A self-custodial vault you can lock yourself out of.
///
///         The whole product is one asymmetry: you can ALWAYS push your unlock
///         time further out, and you can NEVER pull it closer. There is no
///         owner, no admin, no pause, no upgrade and no rescue path — not even
///         the deployer can release your funds early. Once you lock, present-you
///         cannot betray future-you.
///
///         Use it to stop revenge-trading: park your stack, set a cooldown, and
///         you physically cannot pull it out to fund a tilt trade until the
///         timer clears.
contract IronHands {
    struct Vault {
        uint256 balance; // MON held for this user
        uint64 lockedUntil; // unix ts; withdrawals blocked while now < lockedUntil
    }

    mapping(address => Vault) private _vaults;

    // ---- minimal reentrancy guard (no external deps by design) ----
    uint256 private _entered = 1;

    modifier nonReentrant() {
        require(_entered == 1, "reentrant");
        _entered = 2;
        _;
        _entered = 1;
    }

    // ---- events ----
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Locked(address indexed user, uint64 lockedUntil);
    event Withdrawn(address indexed user, uint256 amount, uint256 newBalance);

    // ---- errors ----
    error NothingToDeposit();
    error ZeroDuration();
    error WouldShortenLock(uint64 current); // the point: you cannot weaken your own commitment
    error StillLocked(uint64 lockedUntil);
    error AmountZero();
    error InsufficientBalance();
    error TransferFailed();
    error UseDeposit();

    /// @notice Deposit MON into your own vault.
    function deposit() external payable {
        if (msg.value == 0) revert NothingToDeposit();
        Vault storage v = _vaults[msg.sender];
        v.balance += msg.value;
        emit Deposited(msg.sender, msg.value, v.balance);
    }

    /// @notice Lock your vault for `duration` seconds starting now.
    /// @dev    Only ever extends. Reverts if the resulting unlock time is not
    ///         strictly later than the current one.
    function lock(uint64 duration) external {
        if (duration == 0) revert ZeroDuration();
        Vault storage v = _vaults[msg.sender];
        uint64 newUntil = uint64(block.timestamp) + duration;
        if (newUntil <= v.lockedUntil) revert WouldShortenLock(v.lockedUntil);
        v.lockedUntil = newUntil;
        emit Locked(msg.sender, newUntil);
    }

    /// @notice Extend your lock to an absolute timestamp (must be strictly later).
    function lockUntil(uint64 timestamp) external {
        Vault storage v = _vaults[msg.sender];
        if (timestamp <= v.lockedUntil || timestamp <= block.timestamp) {
            revert WouldShortenLock(v.lockedUntil);
        }
        v.lockedUntil = timestamp;
        emit Locked(msg.sender, timestamp);
    }

    /// @notice Withdraw once the lock has elapsed. Reverts while locked.
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        Vault storage v = _vaults[msg.sender];
        if (block.timestamp < v.lockedUntil) revert StillLocked(v.lockedUntil);
        if (amount > v.balance) revert InsufficientBalance();

        v.balance -= amount; // effects before interaction
        emit Withdrawn(msg.sender, amount, v.balance);

        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    // ---- views ----
    function vaultOf(address user) external view returns (uint256 balance, uint64 lockedUntil) {
        Vault storage v = _vaults[user];
        return (v.balance, v.lockedUntil);
    }

    function isLocked(address user) public view returns (bool) {
        return block.timestamp < _vaults[user].lockedUntil;
    }

    function timeRemaining(address user) external view returns (uint256) {
        uint64 u = _vaults[user].lockedUntil;
        return block.timestamp >= u ? 0 : u - block.timestamp;
    }

    /// @dev Force everyone through deposit() so vaults are always attributed.
    receive() external payable {
        revert UseDeposit();
    }
}
