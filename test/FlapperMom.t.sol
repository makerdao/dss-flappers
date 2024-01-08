// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import { DssInstance, MCD } from "dss-test/MCD.sol";
import { FlapperInstance } from "deploy/FlapperInstance.sol";
import { FlapperDeploy } from "deploy/FlapperDeploy.sol";
import { FlapperUniV2Config, FlapperInit } from "deploy/FlapperInit.sol";

import { FlapperMom } from "src/FlapperMom.sol";
import { FlapperUniV2 } from "src/FlapperUniV2.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface ChiefLike {
    function hat() external view returns (address);
}

contract FlapperMomTest is Test {
    using stdStorage for StdStorage;

    FlapperUniV2 flapper;
    FlapperMom   mom;

    address DAI_JOIN;
    address SPOT;
    address MKR;
    address PAUSE_PROXY;
    ChiefLike chief;

    address constant  LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address constant UNIV2_DAI_MKR_PAIR = 0x517F9dD285e75b599234F7221227339478d0FcC8;

    event SetOwner(address indexed _owner);
    event SetAuthority(address indexed _authority);
    event Stop();

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        DAI_JOIN          = ChainlogLike(LOG).getAddress("MCD_JOIN_DAI");
        SPOT              = ChainlogLike(LOG).getAddress("MCD_SPOT");
        MKR               = ChainlogLike(LOG).getAddress("MCD_GOV");
        PAUSE_PROXY       = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        chief             = ChiefLike(ChainlogLike(LOG).getAddress("MCD_ADM"));

        FlapperInstance memory flapperInstance = FlapperDeploy.deployFlapperUniV2({
            deployer: address(this),
            owner:    PAUSE_PROXY,
            daiJoin:  DAI_JOIN,
            spotter:  SPOT,
            gem:      MKR,
            pair:     UNIV2_DAI_MKR_PAIR,
            receiver: PAUSE_PROXY,
            swapOnly: false
        });
        flapper = FlapperUniV2(flapperInstance.flapper);
        mom = FlapperMom(flapperInstance.mom);

        // use random values
        FlapperUniV2Config memory cfg = FlapperUniV2Config({
            hop:     5 minutes,
            want:    1e18,
            pip:     address(0),
            hump:    1,
            bump:    0,
            daiJoin: DAI_JOIN
        });
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        vm.startPrank(PAUSE_PROXY);
        FlapperInit.initFlapperUniV2(dss, flapperInstance, cfg);
        vm.stopPrank();

        assertLt(flapper.hop(), type(uint256).max);
    }

    function doStop(address sender) internal {
        vm.expectEmit(false, false, false, false);
        emit Stop();
        vm.prank(sender); mom.stop();
        assertEq(flapper.hop(), type(uint256).max);
    }

    function testSetOwner() public {
        vm.expectEmit(true, false, false, false);
        emit SetOwner(address(123));
        vm.prank(PAUSE_PROXY); mom.setOwner(address(123));
        assertEq(mom.owner(), address(123));
    }

    function testSetOwnerNotAuthed() public {
        vm.expectRevert("FlapperMom/only-owner");
        vm.prank(address(456)); mom.setOwner(address(123));
    }

    function testSetAuthority() public {
        vm.expectEmit(true, false, false, false);
        emit SetAuthority(address(123));
        vm.prank(PAUSE_PROXY); mom.setAuthority(address(123));
        assertEq(mom.authority(), address(123));
    }

    function testSetAuthorityNotAuthed() public {
        vm.expectRevert("FlapperMom/only-owner");
        vm.prank(address(456)); mom.setAuthority(address(123));
    }

    function testStopFromOwner() public {
        doStop(PAUSE_PROXY);
        vm.expectRevert("FlapperUniV2/kicked-too-soon");
        vm.prank(PAUSE_PROXY); flapper.kick(0, 0);
    }

    function testStopFromHat() public {
        doStop(address(chief.hat()));
        vm.expectRevert("FlapperUniV2/kicked-too-soon");
        vm.prank(PAUSE_PROXY); flapper.kick(0, 0);
    }

    function testStopAfterZzzSet() public {
        stdstore.target(address(flapper)).sig("zzz()").checked_write(314);
        doStop(address(chief.hat()));
        vm.expectRevert(bytes(abi.encodeWithSignature("Panic(uint256)", 0x11))); // arithmetic error
        vm.prank(PAUSE_PROXY); flapper.kick(0, 0);
    }

    function testStopNonAuthed() public {
        vm.expectRevert("FlapperMom/not-authorized");
        vm.prank(address(456)); mom.stop();
    }
}
