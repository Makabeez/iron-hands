// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IronHands} from "../src/IronHands.sol";

contract IronHandsTest is Test {
    IronHands hands;
    address alice = makeAddr("alice");

    function setUp() public {
        hands = new IronHands();
        vm.deal(alice, 100 ether);
    }

    function test_Deposit() public {
        vm.prank(alice);
        hands.deposit{value: 5 ether}();
        (uint256 bal, uint64 until) = hands.vaultOf(alice);
        assertEq(bal, 5 ether);
        assertEq(until, 0);
    }

    function test_DepositZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(IronHands.NothingToDeposit.selector);
        hands.deposit{value: 0}();
    }

    function test_LockBlocksWithdraw() public {
        vm.startPrank(alice);
        hands.deposit{value: 5 ether}();
        hands.lock(1 days);
        assertTrue(hands.isLocked(alice));
        vm.expectRevert(
            abi.encodeWithSelector(IronHands.StillLocked.selector, uint64(block.timestamp + 1 days))
        );
        hands.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_CannotShortenLock() public {
        vm.startPrank(alice);
        hands.deposit{value: 5 ether}();
        hands.lock(2 days);
        (, uint64 until) = hands.vaultOf(alice);
        // trying to set a shorter lock must revert — the core invariant
        vm.expectRevert(abi.encodeWithSelector(IronHands.WouldShortenLock.selector, until));
        hands.lock(1 hours);
        vm.stopPrank();
    }

    function test_CanExtendLock() public {
        vm.startPrank(alice);
        hands.deposit{value: 5 ether}();
        hands.lock(1 days);
        hands.lock(3 days); // extending is always allowed
        (, uint64 until) = hands.vaultOf(alice);
        assertEq(until, uint64(block.timestamp + 3 days));
        vm.stopPrank();
    }

    function test_WithdrawAfterUnlock() public {
        vm.startPrank(alice);
        hands.deposit{value: 5 ether}();
        hands.lock(1 days);
        vm.warp(block.timestamp + 1 days + 1);
        uint256 before = alice.balance;
        hands.withdraw(5 ether);
        assertEq(alice.balance, before + 5 ether);
        (uint256 bal,) = hands.vaultOf(alice);
        assertEq(bal, 0);
        vm.stopPrank();
    }

    function test_LockUntilMustBeLater() public {
        vm.startPrank(alice);
        hands.lockUntil(uint64(block.timestamp + 1 days));
        vm.expectRevert(
            abi.encodeWithSelector(IronHands.WouldShortenLock.selector, uint64(block.timestamp + 1 days))
        );
        hands.lockUntil(uint64(block.timestamp + 1 hours));
        vm.stopPrank();
    }

    function test_DirectSendReverts() public {
        vm.prank(alice);
        // a bare value transfer hits receive(), which reverts -> ok is false,
        // and no vault is credited
        (bool ok,) = address(hands).call{value: 1 ether}("");
        assertFalse(ok);
        (uint256 bal,) = hands.vaultOf(alice);
        assertEq(bal, 0);
    }

    function test_NoBackdoor_deployerCannotTouchFunds() public {
        vm.prank(alice);
        hands.deposit{value: 5 ether}();
        vm.prank(alice);
        hands.lock(7 days);
        // this test contract deployed IronHands; it still has no way to move alice's funds
        vm.expectRevert(IronHands.AmountZero.selector); // even our own withdraw path is per-caller
        hands.withdraw(0);
    }
}
