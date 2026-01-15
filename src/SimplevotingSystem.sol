// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VoteNFT} from "./VoteNFT.sol";

contract SimpleVotingSystem  is AccessControl {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        address payable wallet;
        uint256 received;
    }

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }

    WorkflowStatus public status;
    uint256 public voteStartTime;
    VoteNFT public voteNFT;

    // Constructor
    constructor(address _voteNFT) {
        voteNFT = VoteNFT(_voteNFT);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender);
        _grantRole(WITHDRAWER_ROLE, msg.sender);
    }

    // Functions
    function addCandidate(string memory _name, address payable _wallet) public onlyRole(ADMIN_ROLE) onlyDuringRegisterCandidates {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        require(_wallet != address(0), "Candidate wallet cannot be zero");
        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0, _wallet, 0);
        candidateIds.push(candidateId);
    }

    function vote(uint _candidateId) public onlyDuringVote {
        require(!voters[msg.sender], "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        require(address(voteNFT) != address(0), "Vote NFT contract not set");
        require(voteNFT.balanceOf(msg.sender) == 0, "Already has vote NFT");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;

        voteNFT.mint(msg.sender);
    }

    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    function getCandidate(uint _candidateId) public view returns (Candidate memory) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId];
    }

    function changeWorkflowStatus(WorkflowStatus _status) public onlyRole(ADMIN_ROLE) {
        if (_status == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }
        status = _status;
    }

    function fundCandidate(uint candidateId) external payable onlyRole(FOUNDER_ROLE) {
        require(candidateId > 0 && candidateId <= candidateIds.length, "Invalid candidate ID, not in range");
        require(msg.value > 0, "No fund sent to the candidate");

        Candidate storage c = candidates[candidateId];
        require(c.wallet != address(0), "Candidate wallet not set");

        (bool ok, ) = c.wallet.call{value: msg.value}("");
        require(ok, "Transfer failed");

        c.received += msg.value;

        emit CandidateFunded(msg.sender, candidateId, msg.value);
    }

    function getWinner() public view onlyVoteCompleted returns (Candidate memory) {
        uint winningVoteCount = 0;
        uint winningCandidateId = 0;

        for (uint i = 0; i < candidateIds.length; i++) {
            uint candidateId = candidateIds[i];
            if (candidates[candidateId].voteCount > winningVoteCount) {
                winningVoteCount = candidates[candidateId].voteCount;
                winningCandidateId = candidateId;
            }
        }

        require(winningCandidateId != 0, "No votes cast");

        return candidates[winningCandidateId];
    }

    function withdrawFunds(address payable to, uint256 amount) external onlyRole(WITHDRAWER_ROLE) onlyVoteCompleted {
        require(to != address(0), "Invalid recipient address");
        require(amount <= address(this).balance, "Insufficient contract balance");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Withdrawal failed");
    }

    function addFounder(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(FOUNDER_ROLE, account);
    }

    function addWithdrawer(address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(WITHDRAWER_ROLE, account);
    }

    function setWorkflowStatus(WorkflowStatus _status) external onlyRole(ADMIN_ROLE) {
        if (_status == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }
        status = _status;
    }

    // Modifiers
    modifier onlyDuringRegisterCandidates() {
        require(status == WorkflowStatus.REGISTER_CANDIDATES, "Not in candidate registration phase");
        _;
    }

    modifier onlyDuringVote() {
        require(status == WorkflowStatus.VOTE, "Not in voting phase");
        _;
    }

    modifier inStatus(WorkflowStatus _status) {
        if (_status == WorkflowStatus.VOTE) {
            require(block.timestamp >= voteStartTime + 1 hours, "Vote not open yet (1h delay)");
        }
        _;
    }
    
    modifier onlyVoteCompleted() {
        require(status == WorkflowStatus.COMPLETED, "Voting not completed yet");
        _;
    }

    // Events
    event CandidateFunded(address indexed founder, uint indexed candidateId, uint256 amount);


}