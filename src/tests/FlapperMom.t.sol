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

    address constant  LOG               = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address immutable DAI_JOIN          = ChainlogLike(LOG).getAddress("MCD_JOIN_DAI");
    address immutable SPOT              = ChainlogLike(LOG).getAddress("MCD_SPOT");
    address immutable MKR               = ChainlogLike(LOG).getAddress("MCD_GOV");
    address immutable PAUSE_PROXY       = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
    ChiefLike immutable chief           = ChiefLike(ChainlogLike(LOG).getAddress("MCD_ADM"));

    address constant UNIV2_DAI_MKR_PAIR = 0x517F9dD285e75b599234F7221227339478d0FcC8;

    event SetOwner(address indexed _owner);
    event SetAuthority(address indexed _authority);
    event Stop();

    function setUp() public {
        flapper = new FlapperUniV2(DAI_JOIN, SPOT, MKR, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
        assertLt(flapper.hop(), type(uint256).max);

        mom = new FlapperMom(address(flapper));
        mom.setAuthority(address(chief));
        flapper.rely(address(mom));
    }

    function doStop() internal {
        vm.expectEmit(false, false, false, false);
        emit Stop();
        mom.stop();
        assertEq(flapper.hop(), type(uint256).max);
    }

    function testSetOwner() public {
        vm.expectEmit(true, false, false, false);
        emit SetOwner(address(123));
        mom.setOwner(address(123));
        assertEq(mom.owner(), address(123));
    }

    function testSetOwnerNonAuthed() public {
        vm.startPrank(address(456));
        vm.expectRevert("FlapperMom/only-owner");
        mom.setOwner(address(123));
    }

    function testSetAuthority() public {
        vm.expectEmit(true, false, false, false);
        emit SetAuthority(address(123));
        mom.setAuthority(address(123));
        assertEq(mom.authority(), address(123));
    }

    function testSetAuthorityNonAuthed() public {
        vm.startPrank(address(456));
        vm.expectRevert("FlapperMom/only-owner");
        mom.setAuthority(address(123));
    }

    function testStopFromOwner() public {
        doStop();
        vm.expectRevert("FlapperUniV2/kicked-too-soon");
        flapper.kick(0, 0);
    }

    function testStopFromHat() public {
        vm.startPrank(address(chief.hat()));
        doStop();
        vm.stopPrank();
        vm.expectRevert("FlapperUniV2/kicked-too-soon");
        flapper.kick(0, 0);
    }

    function testStopAfterZzzSet() public {
        stdstore.target(address(flapper)).sig("zzz()").checked_write(314);
        doStop();
        vm.expectRevert(); // arithmetic error
        flapper.kick(0, 0);
    }

    function testStopNonAuthed() public {
        vm.startPrank(address(456));
        vm.expectRevert("FlapperMom/not-authorized");
        mom.stop();
    }
}
