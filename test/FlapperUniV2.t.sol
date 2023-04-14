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
import { FlapperUniV2 } from "src/FlapperUniV2.sol";
import "test/helpers/UniswapV2Library.sol";

interface VatLike {
    function sin(address) external view returns (uint256);
    function dai(address) external view returns (uint256);
    function live() external view returns (uint256);
    function move(address, address, uint256) external;
    function cage() external;
}

interface VowLike {
    function file(bytes32, address) external;
    function file(bytes32, uint256) external;
    function rely(address) external;
    function flap() external returns (uint256);
    function Sin() external view returns (uint256);
    function Ash() external view returns (uint256);
    function heal(uint256) external;
    function bump() external view returns (uint256);
    function hump() external view returns (uint256);
}

interface RouterLike {
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external returns (uint256 amountOut);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
}

contract MockMedianizer {
    uint256 public price;

    constructor(uint256 price_) {
        price = price_;
    }

    function read() external view returns (bytes32) {
        return bytes32(price);
    }
}

contract FlapperUniV2Test is Test {
    using stdStorage for StdStorage;

    FlapperUniV2   public flapper;
    MockMedianizer public medianizer;

    address constant DAI_JOIN           = 0x9759A6Ac90977b93B58547b4A71c78317f391A28;
    address constant DAI                = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant MKR                = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant PAUSE_PROXY        = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    address constant UNIV2_ROUTER       = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNIV2_DAI_MKR_PAIR = 0x517F9dD285e75b599234F7221227339478d0FcC8;
    address constant UNIV2_FACTORY      = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant USDC               = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    VatLike constant vat = VatLike(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    VowLike constant vow = VowLike(0xA950524441892A31ebddF91d3cEEFa04Bf454466);

    uint256 constant WAD   = 1e18;
    uint256 constant RAY   = 1e27   ;
    uint256 constant RAD   = 1e45;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event Kick(uint256 wlot, uint256 bought, uint256 wad, uint256 liquidity);
    event Cage(uint256 rad);
    event Uncage();

    function setUp() public {

        medianizer = new MockMedianizer(727 * 1e18);

        flapper = new FlapperUniV2(DAI_JOIN, MKR, address(medianizer), UNIV2_ROUTER, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
        flapper.file("hop", 30 minutes);
        flapper.file("want", WAD * 98 / 100);
        flapper.rely(address(vow));

        vm.startPrank(PAUSE_PROXY);
        vow.file("flapper", address(flapper));
        vow.file("hump", 50_000_000 * RAD);
        vow.file("bump",       5707 * RAD);
        vm.stopPrank();

        GemLike(DAI).approve(UNIV2_ROUTER, type(uint256).max);
        GemLike(MKR).approve(UNIV2_ROUTER, type(uint256).max);

        // Create additional surplus if needed
        uint256 bumps = 2 * vow.bump() + vow.bump() * 110 / 100; // two kicks + 2nd vat.move for the first
        if (vat.dai(address(vow)) < vat.sin(address(vow)) + bumps + vow.hump()) {
            stdstore.target(address(vat)).sig("dai(address)").with_key(address(vow)).depth(0).checked_write(
                vat.sin(address(vow)) + bumps + vow.hump()
            );
        }

        // Heal if needed
        if (vat.sin(address(vow)) > vow.Sin() + vow.Ash()) {
            vow.heal(vat.sin(address(vow)) - vow.Sin() - vow.Ash());
        }

        // Add initial liquidity if needed
        (uint256 reserveDai, ) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        uint256 minimalDaiReserve = 280_000 * WAD;
        if (reserveDai < minimalDaiReserve) {

            // If there's no sufficient initial liquidity the price might be way off, need to first arb it
            uint256 small = 1e16;
            uint256 refSmall = refAmountOut(small);
            changeUniV2Price(small, refSmall * 999 / 1000, refSmall * 1001 / 1000);

            // Inject initial liquidity
            topUpLiquidity(minimalDaiReserve - reserveDai);
        }
    }

    function refAmountOut(uint256 amountIn) internal view returns (uint256) {
        return amountIn * WAD / uint256(medianizer.read());
    }

    function uniV2AmountOut(uint256 amountIn) internal returns (uint256 amountOut) {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        amountOut = RouterLike(UNIV2_ROUTER).getAmountOut(amountIn, reserveDai, reserveMkr);
    }

    function changeUniV2Price(uint256 amountIn, uint256 minOutAmount, uint256 maxOutAMount) internal {
        uint256 current = uniV2AmountOut(amountIn);

        address[] memory path = new address[](2);
        path[0] = MKR;
        path[1] = DAI;
        uint256 mkrStep = WAD / 10000;
        while (current < minOutAmount) {
            deal(MKR, address(this), mkrStep);
            RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(mkrStep, 0, path, address(this), block.timestamp);
            current = uniV2AmountOut(amountIn);
        }

        path[0] = DAI;
        path[1] = MKR;
        uint256 daiStep = 1 * WAD / 10;
        while (current > maxOutAMount) {
            deal(DAI, address(this), daiStep);
            RouterLike(UNIV2_ROUTER).swapExactTokensForTokens(daiStep, 0, path, address(this), block.timestamp);
            current = uniV2AmountOut(amountIn);
        }

        assert(current >= minOutAmount && current <= maxOutAMount);
    }

    function topUpLiquidity(uint256 daiAmt) internal {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        uint256 mkrAmt = UniswapV2Library.quote(daiAmt, reserveDai, reserveMkr);

        deal(DAI, address(this), daiAmt);
        deal(MKR, address(this), mkrAmt);

        RouterLike(UNIV2_ROUTER).addLiquidity(DAI, MKR, daiAmt, mkrAmt, daiAmt, mkrAmt, address(this), block.timestamp);
        assertGt(GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(address(this)), 0);
    }

    function marginalWant() internal returns (uint256) {
        uint256 wbump = vow.bump() / RAY;
        uint256 actual = uniV2AmountOut(wbump);
        uint256 ref    = refAmountOut(wbump);
        return actual * WAD / ref;
    }

    function doKick() internal{
        uint256 initialLp = GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(address(PAUSE_PROXY));
        uint256 initialDaiVow = vat.dai(address(vow));
        uint256 initialReserveDai = GemLike(DAI).balanceOf(UNIV2_DAI_MKR_PAIR);
        uint256 initialReserveMkr = GemLike(MKR).balanceOf(UNIV2_DAI_MKR_PAIR);

        vm.expectEmit(false, false, false, false); // only check event signature (topic 0)
        emit Kick(0, 0, 0, 0);
        vow.flap();

        assertGt(GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(address(PAUSE_PROXY)), initialLp);
        assertGt(GemLike(DAI).balanceOf(UNIV2_DAI_MKR_PAIR), initialReserveDai);
        assertEq(GemLike(MKR).balanceOf(UNIV2_DAI_MKR_PAIR), initialReserveMkr);
        assertGt(initialDaiVow - vat.dai(address(vow)), 2 * vow.bump() * 9 / 10);
        assertLt(initialDaiVow - vat.dai(address(vow)), 2 * vow.bump() * 11 / 10);
        assertEq(GemLike(DAI).balanceOf(address(flapper)), 0);
        assertEq(GemLike(MKR).balanceOf(address(flapper)), 0);
    }

    function testIllegalGemDecimals() public {
        vm.expectRevert("FlapperUniV2/gem-decimals-not-18");
        flapper = new FlapperUniV2(DAI_JOIN, USDC, address(medianizer), UNIV2_ROUTER, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
    }

    function testRely() public {
        assertEq(flapper.wards(address(123)), 0);
        vm.expectEmit(true, false, false, false);
        emit Rely(address(123));
        flapper.rely(address(123));
        assertEq(flapper.wards(address(123)), 1);
    }

    function testRelyNonAuthed() public {
        flapper.deny(address(this));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.rely(address(123));
    }

    function testDeny() public {
        assertEq(flapper.wards(address(this)), 1);
        vm.expectEmit(true, false, false, false);
        emit Deny(address(this));
        flapper.deny(address(this));
        assertEq(flapper.wards(address(this)), 0);
    }

    function testDenyNonAuthed() public {
        flapper.deny(address(this));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.deny(address(123));
    }

    function testFileHop() public {
        vm.expectEmit(true, false, false, true);
        emit File(bytes32("hop"), 30);
        flapper.file("hop", 30);
        assertEq(flapper.hop(), 30);
    }

    function testFileHopNotAuthed() public {
        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.file("hop", 314);
    }

    function testFileWant() public {
        vm.expectEmit(true, false, false, true);
        emit File(bytes32("want"), 42);
        flapper.file("want", 42);
        assertEq(flapper.want(), 42);
    }

    function testFileWantNotAuthed() public {
        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.file("want", 314);
    }

    function testFileUnrecognized() public {
        vm.expectRevert("FlapperUniV2/file-unrecognized-param");
        flapper.file("nonsense", 23);
    }

    function testKick() public {
        doKick();
    }

    function testKickWantAllows() public {
        flapper.file("want", marginalWant() * 99 / 100);
        doKick();
    }

    function testKickWantBlocks() public {
        flapper.file("want", marginalWant() * 101 / 100);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        vow.flap();
    }

    function testKickAfterHop() public {
        doKick();
        vm.warp(block.timestamp + flapper.hop());

        // make sure the slippage of the first kick doesn't block us
        flapper.file("want", marginalWant() * 99 / 100);
        doKick();
    }

    function testKickBeforeHop() public {
        doKick();
        vm.warp(block.timestamp + flapper.hop() - 1 seconds);

        // make sure the slippage of the first kick doesn't block us
        flapper.file("want", marginalWant() * 99 / 100);
        vm.expectRevert("FlapperUniV2/kicked-too-soon");
        vow.flap();
    }

    function testKickNotLive() public {
        flapper.cage(0);
        assertEq(flapper.live(), 0);
        vm.expectRevert("FlapperUniV2/not-live");
        vow.flap();
    }

    function testCage() public {
        uint256 rad = vow.bump();

        vm.prank(address(vow));
        vat.move(address(vow), address(flapper), rad);

        assertEq(flapper.live(), 1);
        assertEq(vat.dai(address(flapper)), rad);

        vm.expectEmit(false, false, false, true);
        emit Cage(rad);
        flapper.cage(rad);

        assertEq(flapper.live(), 0);
        assertEq(vat.dai(address(flapper)), 0);
        assertEq(vat.dai(address(this)), rad);
    }

    function testCageNotAuthed() public {
        uint256 rad = vow.bump();

        vm.prank(address(vow));
        vat.move(address(vow), address(flapper), rad);

        assertEq(flapper.live(), 1);
        assertEq(vat.dai(address(flapper)), rad);

        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.cage(rad);
    }

    function testUncage() public {
        flapper.cage(0);
        assertEq(flapper.live(), 0);

        vm.expectEmit(false, false, false, false);
        emit Uncage();
        flapper.uncage();

        assertEq(flapper.live(), 1);
    }

    function testUncageVatNotLive() public {
        flapper.cage(0);
        assertEq(flapper.live(), 0);

        vm.prank(PAUSE_PROXY);
        vat.cage();
        assertEq(vat.live(), 0);

        vm.expectRevert("FlapperUniV2/vat-not-live");
        flapper.uncage();
    }

    function testUncageNotAuthed() public {
        flapper.cage(0);
        assertEq(flapper.live(), 0);

        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.uncage();
    }
}
