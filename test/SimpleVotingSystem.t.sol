// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {SimpleVotingSystem} from "../src/SimpleVotingSystem.sol";
import {VoteNFT} from "../src/VoteNFT.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem voting;
    VoteNFT voteNft;

    address admin;
    address founder;
    address withdrawer;

    address voter1;
    address voter2;

    address payable candidateWallet1;
    address payable candidateWallet2;

    function setUp() public {
        // Création des adresses pour les rôles
        admin = makeAddr("admin");
        founder = makeAddr("founder");
        withdrawer = makeAddr("withdrawer");

        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");

        candidateWallet1 = payable(makeAddr("candidateWallet1"));
        candidateWallet2 = payable(makeAddr("candidateWallet2"));

        // On donne des ETH aux comptes qui vont envoyer des tx
        vm.deal(admin, 10 ether);
        vm.deal(founder, 10 ether);
        vm.deal(withdrawer, 10 ether);
        vm.deal(voter1, 10 ether);
        vm.deal(voter2, 10 ether);

        // Déploiement des contrats depuis l'admin
        vm.startPrank(admin);

        voteNft = new VoteNFT(admin); // VoteNFT déployé par admin
        voting = new SimpleVotingSystem(address(voteNft)); // VotingSystem déployé avec le VoteNFT

        // Grant du MINTER_ROLE à Voting pour pouvoir mint les NFT
        voteNft.grantRole(voteNft.MINTER_ROLE(), address(voting));

        // Ajout des rôles supplémentaires dans Voting
        voting.addFounder(founder);
        voting.addWithdrawer(withdrawer);

        vm.stopPrank();
    }

    function _setStatus(uint8 status) internal {
        vm.prank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus(status));
    }

    function testAddCandidate() public {
        vm.prank(admin);
        voting.addCandidate("Michel", candidateWallet1);
        assertEq(voting.getCandidatesCount(), 1);
    }


    function testAddVote() public {
        // Phase d'ajout des candidats
        _setStatus(uint8(SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES));

        vm.prank(admin);
        voting.addCandidate("Michel", candidateWallet1);

        vm.prank(admin);
        voting.addCandidate("Jean", candidateWallet2);

        // Phase de vote
        _setStatus(uint8(SimpleVotingSystem.WorkflowStatus.VOTE));
        vm.warp(block.timestamp + 1 hours + 1);

        // Voters votent
        vm.prank(voter1);
        voting.vote(1);

        vm.prank(voter2);
        voting.vote(2);

        // Vérification des votes via le getter public candidates()
        ( , , uint voteCount1, , ) = voting.candidates(1);
        ( , , uint voteCount2, , ) = voting.candidates(2);

        assertEq(voteCount1, 1);
        assertEq(voteCount2, 1);
    }


}
