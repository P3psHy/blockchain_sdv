// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleVotingSystem  is AccessControl {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        adresse payable wallet;
        uint256 received;
    }

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;


    uint256 public voteStartTime;


    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }
    WorkflowStatus public status;

    // Constructor
    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender);
    }

    // Functions
    function addCandidate(string memory _name) public onlyRole(ADMIN_ROLE) onlyDuringRegisterCandidates {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0);
        candidateIds.push(candidateId);
    }

    function vote(uint _candidateId) public onlyDuringVote {
        require(!voters[msg.sender], "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;
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
        if (_status == workflowStatus.VOTE) {
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
    }

    // Events
    event CandidateFunded(address indexed founder, uint indexed candidateId, uint256 amount);


}