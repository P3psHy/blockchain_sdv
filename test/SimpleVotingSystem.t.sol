// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {SimpleVotingSystem} from "../src/SimplevotingSystem.sol";

contract SimpleVotingSystemTest is Test {
  SimpleVotingSystem public votingSystem;
  address public constant OWNER = address(0x1234567890123456789012345678901234567890);
  address public voter1;
  address public voter2;
  address public voter3;

  event CandidateAdded(uint indexed candidateId, string name);
  event VoteCast(address indexed voter, uint indexed candidateId);

  function setUp() public {
    voter1 = makeAddr("voter1");
    voter2 = makeAddr("voter2");
    voter3 = makeAddr("voter3");

    // Créditer tous les comptes avec de l'ETH pour payer le gas des transactions
    vm.deal(OWNER, 100 ether);
    vm.deal(voter1, 10 ether);
    vm.deal(voter2, 10 ether);
    vm.deal(voter3, 10 ether);

    vm.startPrank(OWNER);
    votingSystem = new SimpleVotingSystem(); //msg.sender de la TX est = à l'adress du SC "SimpleVotingSystemTest"
    vm.stopPrank();
  }

  // ============ Tests d'initialisation ============

  function test_InitialState() public view {
    assertEq(votingSystem.owner(), OWNER);
    assertEq(votingSystem.getCandidatesCount(), 0);
  }

  // ============ Tests pour addCandidate ============

  function test_AddCandidate_AsOwner() public {
    string memory candidateName = "Alice";
    vm.startPrank(OWNER);
    votingSystem.addCandidate(candidateName);
    vm.stopPrank();

    assertEq(votingSystem.getCandidatesCount(), 1);
    SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
    assertEq(candidate.id, 1);
    assertEq(candidate.name, candidateName);
    assertEq(candidate.voteCount, 0);
  }

  function test_AddCandidate_MultipleCandidates() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    votingSystem.addCandidate("Charlie");
    vm.stopPrank();

    assertEq(votingSystem.getCandidatesCount(), 3);

    SimpleVotingSystem.Candidate memory candidate1 = votingSystem.getCandidate(1);
    assertEq(candidate1.name, "Alice");
    assertEq(candidate1.id, 1);

    SimpleVotingSystem.Candidate memory candidate2 = votingSystem.getCandidate(2);
    assertEq(candidate2.name, "Bob");
    assertEq(candidate2.id, 2);

    SimpleVotingSystem.Candidate memory candidate3 = votingSystem.getCandidate(3);
    assertEq(candidate3.name, "Charlie");
    assertEq(candidate3.id, 3);
  }

  function test_AddCandidate_OnlyOwner() public {
    vm.startPrank(voter1);
    vm.expectRevert();
    votingSystem.addCandidate("Unauthorized Candidate");
    vm.stopPrank();
  }

  function test_AddCandidate_EmptyName() public {
    vm.startPrank(OWNER);
    vm.expectRevert("Candidate name cannot be empty");
    votingSystem.addCandidate("");
    vm.stopPrank();
  }

  function test_AddCandidate_WithWhitespace() public {
    // Un nom avec seulement des espaces devrait être accepté (selon l'implémentation actuelle)
    // Mais testons avec un nom valide contenant des espaces
    vm.startPrank(OWNER);
    votingSystem.addCandidate("John Doe");
    vm.stopPrank();
    assertEq(votingSystem.getCandidatesCount(), 1);
    SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
    assertEq(candidate.name, "John Doe");
  }

  // ============ Tests pour vote ============

  function test_Vote_ValidCandidate() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    vm.stopPrank();

    vm.startPrank(voter1);
    votingSystem.vote(1);
    vm.stopPrank();

    assertTrue(votingSystem.voters(voter1));
    assertEq(votingSystem.getTotalVotes(1), 1);
    assertEq(votingSystem.getTotalVotes(2), 0);
  }

  function test_Vote_MultipleVoters() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    vm.stopPrank();

    vm.startPrank(voter1);
    votingSystem.vote(1);
    vm.stopPrank();

    vm.startPrank(voter2);
    votingSystem.vote(1);
    vm.stopPrank();

    vm.startPrank(voter3);
    votingSystem.vote(2);
    vm.stopPrank();

    assertEq(votingSystem.getTotalVotes(1), 2);
    assertEq(votingSystem.getTotalVotes(2), 1);
    assertTrue(votingSystem.voters(voter1));
    assertTrue(votingSystem.voters(voter2));
    assertTrue(votingSystem.voters(voter3));
  }

  function test_Vote_DuplicateVote() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.startPrank(voter1);
    votingSystem.vote(1);
    vm.stopPrank();

    vm.startPrank(voter1);
    vm.expectRevert("You have already voted");
    votingSystem.vote(1);
    vm.stopPrank();
  }

  function test_Vote_InvalidCandidateId_Zero() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.startPrank(voter1);
    vm.expectRevert("Invalid candidate ID");
    votingSystem.vote(0);
    vm.stopPrank();
  }

  function test_Vote_InvalidCandidateId_TooHigh() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.startPrank(voter1);
    vm.expectRevert("Invalid candidate ID");
    votingSystem.vote(2);
    vm.stopPrank();
  }

  function test_Vote_InvalidCandidateId_TooHigh_WithMultipleCandidates() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    vm.stopPrank();

    vm.startPrank(voter1);
    vm.expectRevert("Invalid candidate ID");
    votingSystem.vote(3);
    vm.stopPrank();
  }

  function test_Vote_OwnerCanVote() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.startPrank(OWNER);
    votingSystem.vote(1);
    vm.stopPrank();

    assertTrue(votingSystem.voters(OWNER));
    assertEq(votingSystem.getTotalVotes(1), 1);
  }

  // ============ Tests pour getTotalVotes ============

  function test_GetTotalVotes_InitialState() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    assertEq(votingSystem.getTotalVotes(1), 0);
  }

  function test_GetTotalVotes_AfterVotes() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    vm.stopPrank();

    vm.startPrank(voter1);
    votingSystem.vote(1);
    vm.stopPrank();

    vm.startPrank(voter2);
    votingSystem.vote(1);
    vm.stopPrank();

    vm.startPrank(voter3);
    votingSystem.vote(2);
    vm.stopPrank();

    assertEq(votingSystem.getTotalVotes(1), 2);
    assertEq(votingSystem.getTotalVotes(2), 1);
  }

  function test_GetTotalVotes_InvalidCandidateId_Zero() public {
    vm.expectRevert("Invalid candidate ID");
    votingSystem.getTotalVotes(0);
  }

  function test_GetTotalVotes_InvalidCandidateId_TooHigh() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.expectRevert("Invalid candidate ID");
    votingSystem.getTotalVotes(2);
  }

  // ============ Tests pour getCandidatesCount ============

  function test_GetCandidatesCount_Initial() public view {
    assertEq(votingSystem.getCandidatesCount(), 0);
  }

  function test_GetCandidatesCount_AfterAdding() public {
    assertEq(votingSystem.getCandidatesCount(), 0);

    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();
    assertEq(votingSystem.getCandidatesCount(), 1);

    vm.startPrank(OWNER);
    votingSystem.addCandidate("Bob");
    vm.stopPrank();
    assertEq(votingSystem.getCandidatesCount(), 2);

    vm.startPrank(OWNER);
    votingSystem.addCandidate("Charlie");
    vm.stopPrank();
    assertEq(votingSystem.getCandidatesCount(), 3);
  }

  // ============ Tests pour getCandidate ============

  function test_GetCandidate_ValidId() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    vm.stopPrank();

    SimpleVotingSystem.Candidate memory candidate1 = votingSystem.getCandidate(1);
    assertEq(candidate1.id, 1);
    assertEq(candidate1.name, "Alice");
    assertEq(candidate1.voteCount, 0);

    SimpleVotingSystem.Candidate memory candidate2 = votingSystem.getCandidate(2);
    assertEq(candidate2.id, 2);
    assertEq(candidate2.name, "Bob");
    assertEq(candidate2.voteCount, 0);
  }

  function test_GetCandidate_WithVotes() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.startPrank(voter1);
    votingSystem.vote(1);
    vm.stopPrank();

    vm.startPrank(voter2);
    votingSystem.vote(1);
    vm.stopPrank();

    SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
    assertEq(candidate.id, 1);
    assertEq(candidate.name, "Alice");
    assertEq(candidate.voteCount, 2);
  }

  function test_GetCandidate_InvalidId_Zero() public {
    vm.expectRevert("Invalid candidate ID");
    votingSystem.getCandidate(0);
  }

  function test_GetCandidate_InvalidId_TooHigh() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    vm.expectRevert("Invalid candidate ID");
    votingSystem.getCandidate(2);
  }

  // ============ Tests de cas limites ============

  function test_CompleteVotingScenario() public {
    // Ajouter plusieurs candidats
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    votingSystem.addCandidate("Charlie");
    vm.stopPrank();

    // Plusieurs votants votent
    vm.startPrank(voter1);
    votingSystem.vote(1); // Alice
    vm.stopPrank();

    vm.startPrank(voter2);
    votingSystem.vote(1); // Alice
    vm.stopPrank();

    vm.startPrank(voter3);
    votingSystem.vote(2); // Bob
    vm.stopPrank();

    // Vérifier les résultats
    assertEq(votingSystem.getTotalVotes(1), 2); // Alice
    assertEq(votingSystem.getTotalVotes(2), 1); // Bob
    assertEq(votingSystem.getTotalVotes(3), 0); // Charlie

    // Vérifier que tous ont voté
    assertTrue(votingSystem.voters(voter1));
    assertTrue(votingSystem.voters(voter2));
    assertTrue(votingSystem.voters(voter3));

    // Vérifier les détails des candidats
    SimpleVotingSystem.Candidate memory alice = votingSystem.getCandidate(1);
    assertEq(alice.voteCount, 2);

    SimpleVotingSystem.Candidate memory bob = votingSystem.getCandidate(2);
    assertEq(bob.voteCount, 1);

    SimpleVotingSystem.Candidate memory charlie = votingSystem.getCandidate(3);
    assertEq(charlie.voteCount, 0);
  }

  function test_VoteCount_IncrementsCorrectly() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    // Voter plusieurs fois avec différents votants
    for (uint i = 0; i < 10; i++) {
      address voter = makeAddr(string(abi.encodePacked("voter", i)));
      vm.deal(voter, 1 ether);
      vm.startPrank(voter);
      votingSystem.vote(1);
      vm.stopPrank();
    }

    assertEq(votingSystem.getTotalVotes(1), 10);
  }

  // ============ Tests de fuzzing ============

  function testFuzz_AddCandidate(string memory _name) public {
    // Filtrer les noms vides
    vm.assume(bytes(_name).length > 0);

    vm.startPrank(OWNER);
    votingSystem.addCandidate(_name);
    vm.stopPrank();

    assertEq(votingSystem.getCandidatesCount(), 1);
    SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
    assertEq(candidate.name, _name);
    assertEq(candidate.voteCount, 0);
  }

  function testFuzz_Vote_ValidCandidateId(uint8 _candidateId) public {
    // Créer plusieurs candidats
    uint8 numCandidates = 10;
    vm.startPrank(OWNER);
    for (uint8 i = 1; i <= numCandidates; i++) {
      votingSystem.addCandidate(string(abi.encodePacked("Candidate", i)));
    }
    vm.stopPrank();

    // Borner l'ID du candidat à une plage valide
    _candidateId = uint8(bound(_candidateId, 1, numCandidates));

    address voter = makeAddr("fuzzVoter");
    vm.deal(voter, 1 ether);
    vm.startPrank(voter);
    votingSystem.vote(_candidateId);
    vm.stopPrank();

    assertTrue(votingSystem.voters(voter));
    assertEq(votingSystem.getTotalVotes(_candidateId), 1);
  }

  function testFuzz_MultipleVotes(uint8 _numVotes) public {
    // Limiter le nombre de votes pour éviter les problèmes de gas
    _numVotes = uint8(bound(_numVotes, 1, 50));

    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    // Créer plusieurs votants et faire voter chacun une fois
    for (uint8 i = 0; i < _numVotes; i++) {
      address voter = makeAddr(string(abi.encodePacked("voter", i)));
      vm.deal(voter, 1 ether);
      vm.startPrank(voter);
      votingSystem.vote(1);
      vm.stopPrank();
    }

    assertEq(votingSystem.getTotalVotes(1), _numVotes);
  }

  // ============ Tests de mapping public ============

  function test_CandidatesMapping_Public() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    votingSystem.addCandidate("Bob");
    vm.stopPrank();

    (uint id1, string memory name1, uint voteCount1) = votingSystem.candidates(1);
    assertEq(id1, 1);
    assertEq(name1, "Alice");
    assertEq(voteCount1, 0);

    (uint id2, string memory name2, uint voteCount2) = votingSystem.candidates(2);
    assertEq(id2, 2);
    assertEq(name2, "Bob");
    assertEq(voteCount2, 0);
  }

  function test_VotersMapping_Public() public {
    vm.startPrank(OWNER);
    votingSystem.addCandidate("Alice");
    vm.stopPrank();

    assertFalse(votingSystem.voters(voter1));

    vm.startPrank(voter1);
    votingSystem.vote(1);
    vm.stopPrank();

    assertTrue(votingSystem.voters(voter1));
    assertFalse(votingSystem.voters(voter2));
  }

  // ============ Tests de changement de propriétaire ============

  function test_TransferOwnership_NewOwnerCanAddCandidate() public {
    address newOwner = makeAddr("newOwner");
    vm.deal(newOwner, 10 ether);

    vm.startPrank(OWNER);
    votingSystem.transferOwnership(newOwner);
    vm.stopPrank();

    vm.startPrank(newOwner);
    votingSystem.addCandidate("New Candidate");
    vm.stopPrank();

    assertEq(votingSystem.getCandidatesCount(), 1);
    SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
    assertEq(candidate.name, "New Candidate");
  }

  function test_TransferOwnership_OldOwnerCannotAddCandidate() public {
    address newOwner = makeAddr("newOwner");
    vm.deal(newOwner, 10 ether);

    vm.startPrank(OWNER);
    votingSystem.transferOwnership(newOwner);
    vm.stopPrank();

    vm.startPrank(OWNER);
    vm.expectRevert();
    votingSystem.addCandidate("Should Fail");
    vm.stopPrank();
  }
}
