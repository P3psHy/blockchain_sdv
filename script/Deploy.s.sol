// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {VoteNFT} from "../src/VoteNFT.sol";
import {SimpleVotingSystem} from "../src/SimpleVotingSystem.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        // msg.sender = le wallet qui signe les tx (celui passÃ© via --private-key)
        VoteNFT voteNft = new VoteNFT(msg.sender);
        SimpleVotingSystem voting = new SimpleVotingSystem(address(voteNft));
        voteNft.grantRole(voteNft.MINTER_ROLE(), address(voting));

        vm.stopBroadcast();

        console2.log("VoteNFT deployed at:", address(voteNft));
        console2.log("Voting deployed at:", address(voting));
        console2.log("MINTER_ROLE granted to Voting contract");
    }
}