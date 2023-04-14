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

interface VatLike {
    function dai(address) external view returns (uint256);
    function cage() external;
}

interface ChiefLike {
    function hat() external view returns (address);
}

contract FlapperMomTest is Test {
    using stdStorage for StdStorage;

    FlapperUniV2 flapper;
    FlapperMom   mom;

    address constant VOW                = 0xA950524441892A31ebddF91d3cEEFa04Bf454466;
    address constant MKR                = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant DAI_JOIN           = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address constant PAUSE_PROXY        = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address constant UNIV2_ROUTER       = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNIV2_DAI_MKR_PAIR = 0x517F9dD285e75b599234F7221227339478d0FcC8;

    VatLike   constant vat   = VatLike(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    ChiefLike constant chief = ChiefLike(0x9eF05f7F6deB616fd37aC3c959a2dDD25A54E4F5);

    uint256 constant RAD = 1e45;

    event SetOwner(address indexed newOwner);
    event SetAuthority(address indexed newAuthority);
    event Cage(uint256 rad);

    function setUp() public {
        flapper = new FlapperUniV2(DAI_JOIN, MKR, address(0), UNIV2_ROUTER, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
        mom = new FlapperMom(address(flapper), address(vat), VOW);

        mom.setAuthority(address(chief));
        flapper.rely(address(mom));

        // Give flapper some vat dai
        stdstore.target(address(vat)).sig("dai(address)").with_key(address(flapper)).depth(0).checked_write(3 * RAD);
        assertEq(vat.dai(address(flapper)), 3 * RAD);
        assertEq(flapper.live(), 1);
    }

    function doCage() internal {
        uint256 initialDaiVow = vat.dai(VOW);

        vm.expectEmit(false, false, false, true);
        emit Cage(3 * RAD);
        mom.cage();

        assertEq(flapper.live(), 0);
        assertEq(vat.dai(address(flapper)), 0);
        assertEq(vat.dai(address(mom)), 0);
        assertEq(vat.dai(VOW), initialDaiVow + 3 * RAD);
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

    function testCageFromOwner() public {
        doCage();
    }

    function testCageFromHat() public {
        vm.startPrank(address(chief.hat()));
        doCage();
        vm.stopPrank();
    }

    function testCageNonAuthed() public {
        vm.startPrank(address(456));
        vm.expectRevert("FlapperMom/not-authorized");
        mom.cage();
    }
}
