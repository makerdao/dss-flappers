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
import { OracleWrapper } from "src/OracleWrapper.sol";

interface PipLike {
    function read() external view returns (bytes32);
}

contract MockMedianizer {
    uint256 public price;
    bool    public has = true;

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function setHas(bool _has) external {
        has = _has;
    }

    function read() external view returns (bytes32) {
        require(has);
        return bytes32(price);
    }
}

contract OracleWrapperTest is Test {
    MockMedianizer public medianizer;
    PipLike        public oracleWrapper;

    uint256 constant WAD = 10 ** 18;

    function setUp() public {
        medianizer = new MockMedianizer();
        medianizer.setPrice(727 * WAD);
        medianizer.setHas(true);

        oracleWrapper = PipLike(address(new OracleWrapper(address(medianizer), address(this), 1800)));
    }

    function testRead() public {
        assertEq(oracleWrapper.read(), bytes32(727 * WAD / 1800)); // 0.40388889e+18
    }

    function testReadInvalidPrice() public {
        medianizer.setHas(false);
        vm.expectRevert();
        oracleWrapper.read();
    }

    function testUnauthorizedReader() public {
        vm.prank(address(123));
        vm.expectRevert("OracleWrapper/unauthorized-reader");
        oracleWrapper.read();
    }
}
