// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ChainFold Protocol
 * @notice Minimal gas-conscious protocol for submitting and managing "folds" (batched payload roots).
 * @dev Keeps a simple staking mechanism per fold so proposers have skin in the game. Owner can finalize folds.
 */
contract ChainFoldProtocol {
    address public owner;
    uint256 public stakeAmount;
    uint256 public foldCount;

    struct Fold {
        bytes32 root;
        address proposer;
        uint256 timestamp;
        uint256 stake;
        bool finalized;
    }

    mapping(uint256 => Fold) public folds;

    event FoldSubmitted(uint256 indexed id, bytes32 root, address indexed proposer, uint256 stake);
    event FoldFinalized(uint256 indexed id, address indexed finalizedTo, uint256 stakeTransferred);
    event StakeAmountUpdated(uint256 oldAmount, uint256 newAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(uint256 _stakeAmount) {
        owner = msg.sender;
        stakeAmount = _stakeAmount;
        foldCount = 0;
    }

    /// @notice Submit a new fold root with required stake (msg.value >= stakeAmount).
    /// @param root Merkle root or hash representing the batched payload.
    function submitFold(bytes32 root) external payable returns (uint256 id) {
        require(msg.value >= stakeAmount, "Insufficient stake");

        id = foldCount++;
        folds[id] = Fold({
            root: root,
            proposer: msg.sender,
            timestamp: block.timestamp,
            stake: msg.value,
            finalized: false
        });

        emit FoldSubmitted(id, root, msg.sender, msg.value);
    }

    /// @notice View fold details.
    function getFold(uint256 id) external view returns (bytes32 root, address proposer, uint256 timestamp, uint256 stake, bool finalized) {
        Fold storage f = folds[id];
        return (f.root, f.proposer, f.timestamp, f.stake, f.finalized);
    }

    /// @notice Finalize a fold and transfer its stake to a recipient (owner only).
    /// @dev Marks fold finalized, transfers held stake and prevents re-finalization.
    function finalizeFold(uint256 id, address payable to) external onlyOwner {
        Fold storage f = folds[id];
        require(!f.finalized, "Already finalized");
        require(f.stake > 0, "No stake");

        f.finalized = true;
        uint256 amount = f.stake;
        f.stake = 0;

        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Transfer failed");

        emit FoldFinalized(id, to, amount);
    }

    /// @notice Owner can update the required stake per fold.
    function setStakeAmount(uint256 newAmount) external onlyOwner {
        emit StakeAmountUpdated(stakeAmount, newAmount);
        stakeAmount = newAmount;
    }

    /// @notice Owner can withdraw any accidental plain ETH balance held by contract.
    function withdraw(address payable to, uint256 amount) external onlyOwner {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Withdraw failed");
    }

    // Fallback to accept ETH when needed (e.g. refunds or direct transfers).
    receive() external payable {}
}
