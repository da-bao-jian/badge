// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import "../BadgeManager.sol";

// now only test the abstract contract
contract BadgeTest is DSTest, BadgeManager{
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;
    string[] internal uris;
    string[] internal projNames;
    BadgeManager internal _manager;

    address public CLIENT_1;
    address public CLIENT_2;
    address public CLIENT_3;
    address public CLIENT_4;
    address public CLIENT_5;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        _manager = new BadgeManager();

        CLIENT_1 = users[0];
        CLIENT_2 = users[1];
        CLIENT_3 = users[2];
        CLIENT_4 = users[3];
        CLIENT_5 = users[4];

        uris[0] = "client1.com";
        uris[1] = "client2.com";
        uris[2] = "client3.com";
        uris[3] = "client4.com";
        uris[4] = "client5.com";

        projNames[0] = "Project 1";
        projNames[1] = "Project 2";
        projNames[2] = "Project 3";
        projNames[3] = "Project 4";
        projNames[4] = "Project 5";

    }

    function testManagerSetup() public view {
        assert(_manager.owner() == address(this));
    }

    // FUNCTION TESTcEATEcLIENT() PUBLIC {

    //     // FOR (UINT I = 0; I < 5; I++) {
    //     // _MANAGER.CREATEcLIENT(USERS[0], URIS[0], PROJnAMES[0]);
    //     // }

    //     // STRING MEMORY URI;
    //     // STRING MEMORY PROJnAME;
    //     // FOR (UINT I = 0; I < 5; I++) {
    //     //     (URI, PROJnAME) = _MANAGER.CLIENTmETA(USERS[I]);
    //     //     ASSERT(KECCAK256(ABI.ENCODEpACKED(URI)) == KECCAK256(ABI.ENCODEpACKED(URIS[I])));
    //     //     ASSERT(KECCAK256(ABI.ENCODEpACKED(PROJnAME)) == KECCAK256(ABI.ENCODEpACKED(PROJnAMES[I])));
    //     // }

    // }

    function testExample() public {
        address payable alice = users[0];
        // labels alice's address in call traces as "Alice [<address>]"
        vm.label(alice, "Alice");
        console.log("alice's address", alice);
        address payable bob = users[1];
        vm.label(bob, "Bob");

        vm.prank(alice);
        (bool sent, ) = bob.call{value: 10 ether}("");
        assertTrue(sent);
        assertGt(bob.balance, alice.balance);
    }
}
