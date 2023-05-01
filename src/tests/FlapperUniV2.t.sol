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
import "src/tests/helpers/UniswapV2Library.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

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

interface EndLike {
    function cage() external;
}

interface SpotterLike {
    function par() external view returns (uint256);
}

interface RouterLike {
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external returns (uint256 amountOut);

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

interface PairLike {
    function sync() external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
}

contract MockMedianizer {
    uint256 public price;

    function setPrice(uint256 price_) external {
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

    address     constant  LOG           = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address     immutable DAI_JOIN      = ChainlogLike(LOG).getAddress("MCD_JOIN_DAI");
    address     immutable SPOT          = ChainlogLike(LOG).getAddress("MCD_SPOT");
    address     immutable DAI           = ChainlogLike(LOG).getAddress("MCD_DAI");
    address     immutable MKR           = ChainlogLike(LOG).getAddress("MCD_GOV");
    address     immutable PAUSE_PROXY   = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
    VatLike     immutable vat           = VatLike(ChainlogLike(LOG).getAddress("MCD_VAT"));
    VowLike     immutable vow           = VowLike(ChainlogLike(LOG).getAddress("MCD_VOW"));
    EndLike     immutable end           = EndLike(ChainlogLike(LOG).getAddress("MCD_END"));
    SpotterLike immutable spotter       = SpotterLike(ChainlogLike(LOG).getAddress("MCD_SPOT"));

    address constant UNIV2_ROUTER       = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNIV2_DAI_MKR_PAIR = 0x517F9dD285e75b599234F7221227339478d0FcC8;
    address constant UNIV2_FACTORY      = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant USDC               = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event Kick(uint256 lot, uint256 bought, uint256 wad, uint256 liquidity);
    event Cage(uint256 rad);

    function setUp() public {
        medianizer = new MockMedianizer();

        flapper = new FlapperUniV2(DAI_JOIN, SPOT, MKR, UNIV2_ROUTER, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
        flapper.file("hop", 30 minutes);
        flapper.file("want", WAD * 97 / 100);
        flapper.file("pip", address(medianizer));
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
            medianizer.setPrice(727 * WAD);
            changeUniV2Price(727 * WAD);
           (reserveDai, ) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
           if(reserveDai < minimalDaiReserve) {
               topUpLiquidity(minimalDaiReserve - reserveDai);
           }
        } else {
            // If there is initial liquidity, then the oracle price should be set to the current price
            medianizer.setPrice(uniV2DaiForMkr(WAD));
        }
    }

    function refAmountOut(uint256 amountIn) internal view returns (uint256) {
        return amountIn * WAD / (uint256(medianizer.read()) * RAY / spotter.par());
    }

    function uniV2MkrForDai(uint256 amountIn) internal returns (uint256 amountOut) {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        amountOut = RouterLike(UNIV2_ROUTER).getAmountOut(amountIn, reserveDai, reserveMkr);
    }

    function uniV2DaiForMkr(uint256 amountIn) internal returns (uint256 amountOut) {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        return RouterLike(UNIV2_ROUTER).getAmountOut(amountIn, reserveMkr, reserveDai);
    }

    function changeUniV2Price(uint256 daiForMkr) internal {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        uint256 currentDaiForMkr = reserveDai * WAD / reserveMkr;

        // neededReserveDai * WAD / neededReserveMkr = daiForMkr;
        if (currentDaiForMkr > daiForMkr) {
            deal(MKR, UNIV2_DAI_MKR_PAIR, reserveDai * WAD / daiForMkr);
        } else {
            deal(DAI, UNIV2_DAI_MKR_PAIR, reserveMkr * daiForMkr / WAD);
        }
        PairLike(UNIV2_DAI_MKR_PAIR).sync();
    }

    function topUpLiquidity(uint256 daiAmt) internal {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        uint256 mkrAmt = UniswapV2Library.quote(daiAmt, reserveDai, reserveMkr);

        deal(DAI, address(this), GemLike(DAI).balanceOf(address(this)) + daiAmt);
        deal(MKR, address(this), GemLike(MKR).balanceOf(address(this)) + mkrAmt);

        RouterLike(UNIV2_ROUTER).addLiquidity(DAI, MKR, daiAmt, mkrAmt, daiAmt, mkrAmt, address(this), block.timestamp);
        assertGt(GemLike(UNIV2_DAI_MKR_PAIR).balanceOf(address(this)), 0);
    }

    function marginalWant() internal returns (uint256) {
        uint256 wbump = vow.bump() / RAY;
        uint256 actual = uniV2MkrForDai(wbump);
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

    function testDefaultValues() public {
        FlapperUniV2 f = new FlapperUniV2(DAI_JOIN, SPOT, MKR, UNIV2_ROUTER, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
        assertEq(f.hop(),  1 hours);
        assertEq(f.want(), WAD);
        assertEq(f.live(), 1);
        assertEq(f.zzz(),  0);
        assertEq(f.wards(address(this)), 1);
    }

    function testIllegalGemDecimals() public {
        vm.expectRevert("FlapperUniV2/gem-decimals-not-18");
        flapper = new FlapperUniV2(DAI_JOIN, SPOT, USDC, UNIV2_ROUTER, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
    }

    function testRely() public {
        assertEq(flapper.wards(address(123)), 0);
        vm.expectEmit(true, false, false, false);
        emit Rely(address(123));
        flapper.rely(address(123));
        assertEq(flapper.wards(address(123)), 1);
    }

    function testRelyNotAuthed() public {
        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.rely(address(456));
    }

    function testDeny() public {
        assertEq(flapper.wards(address(this)), 1);
        vm.expectEmit(true, false, false, false);
        emit Deny(address(this));
        flapper.deny(address(this));
        assertEq(flapper.wards(address(this)), 0);
    }

    function testDenyNotAuthed() public {
        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.deny(address(456));
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

    function testFileUintUnrecognized() public {
        vm.expectRevert("FlapperUniV2/file-unrecognized-param");
        flapper.file("nonsense", 23);
    }

    function testFilePip() public {
        vm.expectEmit(true, false, false, true);
        emit File(bytes32("pip"), address(456));
        flapper.file("pip", address(456));
        assertEq(address(flapper.pip()), address(456));
    }

    function testFilePipNotAuthed() public {
        vm.startPrank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.file("pip", address(456));
    }

    function testFileAddressUnrecognized() public {
        vm.expectRevert("FlapperUniV2/file-unrecognized-param");
        flapper.file("nonsense", address(0));
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

    function testKickAfterStoppedWithHop() public {
        uint256 initialHop = flapper.hop();

        doKick();
        vm.warp(block.timestamp + flapper.hop());

        // make sure the slippage of the first kick doesn't block us
        flapper.file("want", marginalWant() * 99 / 100);

        flapper.file("hop", type(uint256).max);
        vm.expectRevert(bytes(abi.encodeWithSignature("Panic(uint256)", 0x11))); // arithmetic error
        vow.flap();

        flapper.file("hop", initialHop);
        vow.flap();
    }

    function testKickNotLive() public {
        flapper.cage(0);
        assertEq(flapper.live(), 0);
        vm.expectRevert("FlapperUniV2/not-live");
        vow.flap();
    }

    function testKickLotBadResolution() public {
        vm.startPrank(PAUSE_PROXY);
        vow.file("bump", vow.bump() + 1);
        vm.stopPrank();
        vm.expectRevert("FlapperUniV2/lot-not-multiple-of-ray");
        vow.flap();
    }

    function testKickDepositInsanity() public {
        // Set small reserves for current price, to make sure slippage will be large
        uint256 dust = 10_000 * WAD;
        deal(DAI, UNIV2_DAI_MKR_PAIR, dust);
        deal(MKR, UNIV2_DAI_MKR_PAIR, uniV2MkrForDai(dust));
        PairLike(UNIV2_DAI_MKR_PAIR).sync();

        // Make sure the trade slippage enforcement does not fail us
        flapper.file("want", 0);

        vm.expectRevert("FlapperUniV2/deposit-insanity");
        vow.flap();
    }

    function testCage() public {
        assertEq(flapper.live(), 1);
        vm.expectEmit(false, false, false, true);
        emit Cage(0);
        flapper.cage(0);
        assertEq(flapper.live(), 0);
    }

    function testCageThroughEnd() public {
        assertEq(flapper.live(), 1);
        vm.prank(PAUSE_PROXY);
        vm.expectEmit(false, false, false, true, address(flapper));
        emit Cage(0);
        end.cage();
        assertEq(flapper.live(), 0);
    }

    function testCageNotAuthed() public {
        assertEq(flapper.live(), 1);
        vm.prank(address(123));
        vm.expectRevert("FlapperUniV2/not-authorized");
        flapper.cage(0);
    }
}
