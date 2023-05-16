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

import "dss-test/DssTest.sol";
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

interface WardsLike {
    function deny(address) external;
}

interface PairLike {
    function mint(address) external returns (uint256);
    function sync() external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
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

contract FlapperUniV2Test is DssTest {
    using stdStorage for StdStorage;

    FlapperUniV2   public flapper;
    FlapperUniV2   public linkFlapper;
    MockMedianizer public medianizer;
    MockMedianizer public linkMedianizer;

    address     constant  LOG           = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address     immutable DAI_JOIN      = ChainlogLike(LOG).getAddress("MCD_JOIN_DAI");
    address     immutable SPOT          = ChainlogLike(LOG).getAddress("MCD_SPOT");
    address     immutable DAI           = ChainlogLike(LOG).getAddress("MCD_DAI");
    address     immutable MKR           = ChainlogLike(LOG).getAddress("MCD_GOV");
    address     immutable USDC          = ChainlogLike(LOG).getAddress("USDC");
    address     immutable LINK          = ChainlogLike(LOG).getAddress("LINK");
    address     immutable PAUSE_PROXY   = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
    VatLike     immutable vat           = VatLike(ChainlogLike(LOG).getAddress("MCD_VAT"));
    VowLike     immutable vow           = VowLike(ChainlogLike(LOG).getAddress("MCD_VOW"));
    EndLike     immutable end           = EndLike(ChainlogLike(LOG).getAddress("MCD_END"));
    SpotterLike immutable spotter       = SpotterLike(ChainlogLike(LOG).getAddress("MCD_SPOT"));

    address constant UNIV2_FACTORY       = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNIV2_DAI_MKR_PAIR  = 0x517F9dD285e75b599234F7221227339478d0FcC8;
    address constant UNIV2_LINK_DAI_PAIR = 0x6D4fd456eDecA58Cf53A8b586cd50754547DBDB2;

    event Kick(uint256 lot, uint256 total, uint256 bought, uint256 liquidity);
    event Cage(uint256 rad);

    function setUp() public {
        (flapper, medianizer) = setUpFlapper(MKR, UNIV2_DAI_MKR_PAIR, 727 * WAD) ;
        assertEq(flapper.daiFirst(), true);

        (linkFlapper, linkMedianizer) = setUpFlapper(LINK, UNIV2_LINK_DAI_PAIR, 654 * WAD / 100);
        assertEq(linkFlapper.daiFirst(), false);

        vm.startPrank(PAUSE_PROXY);
        vow.file("hump", 50_000_000 * RAD);
        vow.file("bump",       5707 * RAD);
        vow.file("flapper", address(flapper)); // use MKR flapper by default
        vm.stopPrank();

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
    }

    function setUpFlapper(address gem, address pair, uint256 price)
        internal
        returns (FlapperUniV2 _flapper, MockMedianizer _medianizer)
    {
        _flapper = new FlapperUniV2(DAI_JOIN, SPOT, gem, pair, PAUSE_PROXY);
        _medianizer = new MockMedianizer();

        _flapper.file("hop", 30 minutes);
        _flapper.file("want", WAD * 97 / 100);
        _flapper.file("pip", address(_medianizer));
        _flapper.rely(address(vow));

        // Add initial liquidity if needed
        (uint256 reserveDai, ) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, gem);
        uint256 minimalDaiReserve = 280_000 * WAD;
        if (reserveDai < minimalDaiReserve) {
            _medianizer.setPrice(price);
            changeUniV2Price(price, gem, pair);
            (reserveDai, ) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, gem);
            if(reserveDai < minimalDaiReserve) {
                topUpLiquidity(minimalDaiReserve - reserveDai, gem, pair);
            }
        } else {
            // If there is initial liquidity, then the oracle price should be set to the current price
            _medianizer.setPrice(uniV2DaiForGem(WAD, gem));
        }
    }

    function useLinkFlapper() internal {
        vm.prank(PAUSE_PROXY);
        vow.file("flapper", address(linkFlapper));
    }

    function refAmountOut(uint256 amountIn, address pip) internal view returns (uint256) {
        return amountIn * WAD / (uint256(MockMedianizer(pip).read()) * RAY / spotter.par());
    }

    function uniV2GemForDai(uint256 amountIn, address gem) internal view returns (uint256 amountOut) {
        (uint256 reserveDai, uint256 reserveGem) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, gem);
        amountOut = UniswapV2Library.getAmountOut(amountIn, reserveDai, reserveGem);
    }

    function uniV2DaiForGem(uint256 amountIn, address gem) internal view returns (uint256 amountOut) {
        (uint256 reserveDai, uint256 reserveGem) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, gem);
        return UniswapV2Library.getAmountOut(amountIn, reserveGem, reserveDai);
    }

    function changeUniV2Price(uint256 daiForGem, address gem, address pair) internal {
        (uint256 reserveDai, uint256 reserveGem) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, gem);
        uint256 currentDaiForGem = reserveDai * WAD / reserveGem;

        // neededReserveDai * WAD / neededReserveMkr = daiForGem;
        if (currentDaiForGem > daiForGem) {
            deal(gem, pair, reserveDai * WAD / daiForGem);
        } else {
            deal(DAI, pair, reserveGem * daiForGem / WAD);
        }
        PairLike(pair).sync();
    }

    function topUpLiquidity(uint256 daiAmt, address gem, address pair) internal {
        (uint256 reserveDai, uint256 reserveGem) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, gem);
        uint256 gemAmt = UniswapV2Library.quote(daiAmt, reserveDai, reserveGem);

        deal(DAI, address(this), GemLike(DAI).balanceOf(address(this)) + daiAmt);
        deal(gem, address(this), GemLike(gem).balanceOf(address(this)) + gemAmt);

        GemLike(DAI).transfer(pair, daiAmt);
        GemLike(gem).transfer(pair, gemAmt);
        uint256 liquidity = PairLike(pair).mint(address(this));
        assertGt(liquidity, 0);
        assertGe(GemLike(pair).balanceOf(address(this)), liquidity);
    }

    function marginalWant(address gem, address pip) internal view returns (uint256) {
        uint256 wbump = vow.bump() / RAY;
        uint256 actual = uniV2GemForDai(wbump, gem);
        uint256 ref    = refAmountOut(wbump, pip);
        return actual * WAD / ref;
    }

    function doKick(address _flapper, address gem, address pair) internal {
        uint256 initialLp = GemLike(pair).balanceOf(address(PAUSE_PROXY));
        uint256 initialDaiVow = vat.dai(address(vow));
        uint256 initialReserveDai = GemLike(DAI).balanceOf(pair);
        uint256 initialReserveMkr = GemLike(gem).balanceOf(pair);

        vm.expectEmit(false, false, false, false); // only check event signature (topic 0)
        emit Kick(0, 0, 0, 0);
        vow.flap();

        assertGt(GemLike(pair).balanceOf(address(PAUSE_PROXY)), initialLp);
        assertGt(GemLike(DAI).balanceOf(pair), initialReserveDai);
        assertEq(GemLike(gem).balanceOf(pair), initialReserveMkr);
        assertGt(initialDaiVow - vat.dai(address(vow)), 2 * vow.bump() * 9 / 10);
        assertLt(initialDaiVow - vat.dai(address(vow)), 2 * vow.bump() * 11 / 10);
        assertEq(GemLike(DAI).balanceOf(address(_flapper)), 0);
        assertEq(GemLike(gem).balanceOf(address(_flapper)), 0);
    }

    function testDefaultValues() public {
        FlapperUniV2 f = new FlapperUniV2(DAI_JOIN, SPOT, MKR, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
        assertEq(f.hop(),  1 hours);
        assertEq(f.want(), WAD);
        assertEq(f.live(), 1);
        assertEq(f.zzz(),  0);
        assertEq(f.wards(address(this)), 1);
    }

    function testIllegalGemDecimals() public {
        vm.expectRevert("FlapperUniV2/gem-decimals-not-18");
        flapper = new FlapperUniV2(DAI_JOIN, SPOT, USDC, UNIV2_DAI_MKR_PAIR, PAUSE_PROXY);
    }

    function testAuth() public {
        checkAuth(address(flapper), "FlapperUniV2");
    }

    function testAuthModifiers() public virtual {
        WardsLike(address(flapper)).deny(address(this));

        checkModifier(address(flapper), string(abi.encodePacked("FlapperUniV2", "/not-authorized")), [
            FlapperUniV2.cage.selector
        ]);
    }

    function testFileUint() public {
        checkFileUint(address(flapper), "FlapperUniV2", ["hop", "want"]);
    }

    function testFileAddress() public {
        checkFileAddress(address(flapper), "FlapperUniV2", ["pip"]);
    }

    function testKick() public {
        doKick(address(flapper), MKR, UNIV2_DAI_MKR_PAIR);
    }

    function testKickDaiSecond() public {
        useLinkFlapper();
        doKick(address(linkFlapper), LINK, UNIV2_LINK_DAI_PAIR);
    }

    function testKickWantAllows() public {
        flapper.file("want", marginalWant(MKR, address(medianizer)) * 99 / 100);
        doKick(address(flapper), MKR, UNIV2_DAI_MKR_PAIR);
    }

    function testKickWantBlocks() public {
        flapper.file("want", marginalWant(MKR, address(medianizer)) * 101 / 100);
        vm.expectRevert("FlapperUniV2/insufficient-buy-amount");
        vow.flap();
    }

    function testKickDaiSecondWantBlocks() public {
        useLinkFlapper();
        linkFlapper.file("want", marginalWant(LINK, address(linkMedianizer)) * 101 / 100);
        vm.expectRevert("FlapperUniV2/insufficient-buy-amount");
        vow.flap();
    }

    function testKickAfterHop() public {
        doKick(address(flapper), MKR, UNIV2_DAI_MKR_PAIR);
        vm.warp(block.timestamp + flapper.hop());

        // make sure the slippage of the first kick doesn't block us
        flapper.file("want", marginalWant(MKR, address(medianizer)) * 99 / 100);
        doKick(address(flapper), MKR, UNIV2_DAI_MKR_PAIR);
    }

    function testKickBeforeHop() public {
        doKick(address(flapper), MKR, UNIV2_DAI_MKR_PAIR);
        vm.warp(block.timestamp + flapper.hop() - 1 seconds);

        // make sure the slippage of the first kick doesn't block us
        flapper.file("want", marginalWant(MKR, address(medianizer)) * 99 / 100);
        vm.expectRevert("FlapperUniV2/kicked-too-soon");
        vow.flap();
    }

    function testKickAfterStoppedWithHop() public {
        uint256 initialHop = flapper.hop();

        doKick(address(flapper), MKR, UNIV2_DAI_MKR_PAIR);
        vm.warp(block.timestamp + flapper.hop());

        // make sure the slippage of the first kick doesn't block us
        flapper.file("want", marginalWant(MKR, address(medianizer)) * 99 / 100);

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

    function testKickTotalInsanity() public {
        // Set small reserves for current price, to make sure slippage will be large
        uint256 dust = 10_000 * WAD;
        deal(DAI, UNIV2_DAI_MKR_PAIR, dust);
        deal(MKR, UNIV2_DAI_MKR_PAIR, uniV2GemForDai(dust, MKR));
        PairLike(UNIV2_DAI_MKR_PAIR).sync();

        // Make sure the trade slippage enforcement does not fail us
        flapper.file("want", 0);

        vm.expectRevert("FlapperUniV2/total-insanity");
        vow.flap();
    }

    function testKickDaiSecondTotalInsanity() public {
        useLinkFlapper();

        // Set small reserves for current price, to make sure slippage will be large
        uint256 dust = 10_000 * WAD;
        deal(DAI, UNIV2_LINK_DAI_PAIR, dust);
        deal(LINK, UNIV2_LINK_DAI_PAIR, uniV2GemForDai(dust, LINK));
        PairLike(UNIV2_LINK_DAI_PAIR).sync();

        // Make sure the trade slippage enforcement does not fail us
        linkFlapper.file("want", 0);

        vm.expectRevert("FlapperUniV2/total-insanity");
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
}
