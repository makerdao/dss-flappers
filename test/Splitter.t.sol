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
import { Splitter } from "src/Splitter.sol";
import { FlapperUniV2SwapOnly } from "src/FlapperUniV2SwapOnly.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";
import "./helpers/UniswapV2Library.sol";

import { FlapperInstance } from "deploy/FlapperInstance.sol";
import { FlapperDeploy } from "deploy/FlapperDeploy.sol";
import { FlapperUniV2Config, SplitterConfig, FlapperInit } from "deploy/FlapperInit.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface VatLike {
    function sin(address) external view returns (uint256);
    function dai(address) external view returns (uint256);
    function can(address, address) external view returns (uint256);
}

interface VowLike {
    function flap() external returns (uint256);
    function Sin() external view returns (uint256);
    function Ash() external view returns (uint256);
    function heal(uint256) external;
    function bump() external view returns (uint256);
    function hump() external view returns (uint256);
}

interface PipLike {
    function read() external view returns (uint256);
    function kiss(address) external;
}

interface EndLike {
    function cage() external;
}

interface SpotterLike {
    function par() external view returns (uint256);
}

interface PairLike {
    function mint(address) external returns (uint256);
    function sync() external;
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external;
}

contract SplitterTest is DssTest {
    using stdStorage for StdStorage;

    Splitter             public splitter;
    StakingRewardsMock   public farm;
    FlapperUniV2SwapOnly public flapper;
    PipLike              public medianizer;
    GemMock              public stakingToken;

    address     DAI_JOIN;
    address     SPOT;
    address     DAI;
    address     MKR;
    address     PAUSE_PROXY;

    VatLike     vat;
    VowLike     vow;
    EndLike     end;

    address constant LOG                 = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address constant UNIV2_FACTORY       = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNIV2_DAI_MKR_PAIR  = 0x517F9dD285e75b599234F7221227339478d0FcC8;

    event Kick(uint256 tot, uint256 lot, uint256 pay);
    event Cage(uint256 rad);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        DAI_JOIN      = ChainlogLike(LOG).getAddress("MCD_JOIN_DAI");
        SPOT          = ChainlogLike(LOG).getAddress("MCD_SPOT");
        DAI           = ChainlogLike(LOG).getAddress("MCD_DAI");
        MKR           = ChainlogLike(LOG).getAddress("MCD_GOV");
        PAUSE_PROXY   = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        medianizer    = PipLike(ChainlogLike(LOG).getAddress("PIP_MKR"));
        vat           = VatLike(ChainlogLike(LOG).getAddress("MCD_VAT"));
        vow           = VowLike(ChainlogLike(LOG).getAddress("MCD_VOW"));
        end           = EndLike(ChainlogLike(LOG).getAddress("MCD_END"));

        vm.startPrank(PAUSE_PROXY);

        medianizer.kiss(address(this));

        stakingToken = new GemMock(1_000_000 ether);
        farm = new StakingRewardsMock(PAUSE_PROXY, address(0), DAI, address(stakingToken));

        vm.stopPrank();

        splitter = Splitter(FlapperDeploy.deploySplitter({
            deployer: address(this),
            owner:    PAUSE_PROXY,
            daiJoin:  DAI_JOIN,
            farm:     address(farm)
        }));

        FlapperInstance memory flapperInstance = FlapperDeploy.deployFlapperUniV2({
            deployer: address(this),
            owner:    PAUSE_PROXY,
            daiJoin:  DAI_JOIN,
            spotter:  SPOT,
            gem:      MKR,
            pair:     UNIV2_DAI_MKR_PAIR,
            receiver: PAUSE_PROXY,
            swapOnly: true
        });
        flapper = FlapperUniV2SwapOnly(flapperInstance.flapper);

        
        vm.startPrank(PAUSE_PROXY);
        // Note - this part emulates the spell initialization
        FlapperUniV2Config memory flapperCfg = FlapperUniV2Config({
            hop:         30 minutes,
            want:        WAD * 97 / 100,
            pip:         address(medianizer),
            hump:        50_000_000 * RAD,
            bump:        5707 * RAD,
            pair:        UNIV2_DAI_MKR_PAIR,
            daiJoin: DAI_JOIN,
            caller:      address(splitter),
            chainlogKey: "MCD_FLAP_BURN"
        });
        SplitterConfig memory splitterCfg = SplitterConfig({
            burn:            70 * WAD / 100,
            rewardsDuration: flapperCfg.hop,
            farm:            address(farm),
            chainlogKey:     "MCD_FLAP_SPLIT"
        });

        DssInstance memory dss = MCD.loadFromChainlog(LOG);
        FlapperInit.initFlapperUniV2(dss, flapperInstance, flapperCfg);
        FlapperInit.initSplitter(dss, address(splitter), splitterCfg);
        FlapperInit.initDirectOracle(address(flapper));
        vm.stopPrank();

        assertEq(dss.chainlog.getAddress("MCD_FLAP_BURN"), address(flapper));
        assertEq(dss.chainlog.getAddress("MCD_FLAP_SPLIT"), address(splitter));
        assertEq(dss.chainlog.getAddress("FLAPPER_MOM"), address(flapperInstance.mom));

        // Add initial liquidity if needed
        (uint256 reserveDai, ) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
        uint256 minimalDaiReserve = 280_000 * WAD;
        if (reserveDai < minimalDaiReserve) {
            changeMedianizerPrice(727 * WAD);
            changeUniV2Price(medianizer.read(), MKR, UNIV2_DAI_MKR_PAIR);
            (reserveDai, ) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);
            if(reserveDai < minimalDaiReserve) {
                topUpLiquidity(minimalDaiReserve - reserveDai, MKR, UNIV2_DAI_MKR_PAIR);
            }
        } else {
            changeMedianizerPrice(uniV2DaiForGem(WAD, MKR));
        }

        // Create additional surplus if needed
        uint256 bumps = 2 * vow.bump(); // two kicks
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

    function refAmountOut(uint256 amountIn, address pip) internal view returns (uint256) {
        return amountIn * WAD / (uint256(PipLike(pip).read()) * RAY / SpotterLike(SPOT).par());
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

    function changeMedianizerPrice(uint256 daiForGem) internal {
        vm.store(address(medianizer), bytes32(uint256(1)), bytes32(block.timestamp << 128 | daiForGem));
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

    function doKick() internal {
        uint256 initialVowVatDai = vat.dai(address(vow));
        uint256 initialDaiJoinVatDai = vat.dai(DAI_JOIN);
        uint256 initialMkr = GemLike(MKR).balanceOf(address(PAUSE_PROXY));
        uint256 initialReserveDai = GemLike(DAI).balanceOf(UNIV2_DAI_MKR_PAIR);
        uint256 initialReserveMkr = GemLike(MKR).balanceOf(UNIV2_DAI_MKR_PAIR);
        uint256 initialFarmDai = GemLike(DAI).balanceOf(address(farm));
        uint256 prevRewardRate = farm.rewardRate();
        uint256 farmLeftover = block.timestamp >= farm.periodFinish() ? 0 : farm.rewardRate() * (farm.periodFinish() - block.timestamp);
        uint256 farmReward = vow.bump() * (WAD - splitter.burn()) / RAD;
        uint256 prevLastUpdateTime = farm.lastUpdateTime();

        vm.expectEmit(false, false, false, true);
        emit Kick(vow.bump(), vow.bump() * splitter.burn() / WAD, farmReward);
        vow.flap();

        assertEq(vat.dai(address(vow)), initialVowVatDai - vow.bump());
        assertEq(vat.dai(DAI_JOIN), initialDaiJoinVatDai + vow.bump());
        assertEq(vat.dai(address(splitter)), 0);

        assertEq(GemLike(DAI).balanceOf(UNIV2_DAI_MKR_PAIR), initialReserveDai + vow.bump() * splitter.burn() / RAD);
        assertLt(GemLike(MKR).balanceOf(UNIV2_DAI_MKR_PAIR), initialReserveMkr);
        assertGt(GemLike(MKR).balanceOf(address(PAUSE_PROXY)), initialMkr);

        assertEq(GemLike(DAI).balanceOf(address(farm)), initialFarmDai + farmReward);
        assertEq(farm.rewardRate(), splitter.burn() == WAD ? prevRewardRate : (farmLeftover + farmReward) / farm.rewardsDuration());
        assertEq(farm.lastUpdateTime(), splitter.burn() == WAD ? prevLastUpdateTime : block.timestamp); 
    }

    function testConstructor() public {
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        Splitter s = new Splitter(DAI_JOIN, address(0xfff));

        assertEq(address(s.daiJoin()),  DAI_JOIN);
        assertEq(address(s.vat()), address(vat));
        assertEq(address(s.farm()), address(0xfff));
        assertEq(s.wards(address(this)), 1);
    }

    function testAuth() public {
        checkAuth(address(splitter), "Splitter");
    }

    function testAuthModifiers() public virtual {
        assert(splitter.wards(address(this)) == 0);

        checkModifier(address(splitter), string(abi.encodePacked("Splitter", "/not-authorized")), [
            Splitter.kick.selector,
            Splitter.cage.selector
        ]);
    }

    function testFileUint() public {
        checkFileUint(address(splitter), "Splitter", ["burn"]);
    }

    function testFileAddress() public {
        checkFileAddress(address(splitter), "Splitter", ["flapper"]);
    }

    function testVatCanAfterFile() public {
        assertEq(vat.can(address(splitter), address(0xf1)), 0);

        vm.prank(PAUSE_PROXY); splitter.file("flapper", address(0xf1));

        assertEq(vat.can(address(splitter), address(0xf1)), 1);
        assertEq(vat.can(address(splitter), address(0xf2)), 0);

        vm.prank(PAUSE_PROXY); splitter.file("flapper", address(0xf2));

        assertEq(vat.can(address(splitter), address(0xf1)), 0);
        assertEq(vat.can(address(splitter), address(0xf2)), 1);
    }

    function testKick() public {
        doKick();
    }

    function testKickBurnOnly() public {
        vm.prank(PAUSE_PROXY); splitter.file("burn", WAD);

        doKick();
    }

    function testKickLowBurn() public {
        (uint256 reserveDai, uint256 reserveMkr) = UniswapV2Library.getReserves(UNIV2_FACTORY, DAI, MKR);

        // the minimum `burn` value can be obtained for `FlapperUniV2SwapOnly` by requiring that `_buy > 0`, where:
        // _buy = _getAmountOut(lot / RAY, reserveDai, reserveGem)
        //      = _getAmountOut(vow.bump() * burn / RAD, reserveDai, reserveGem)
        uint256 minBurn = (RAD * 1000 * reserveDai) / (vow.bump() * 997 * (reserveMkr - 1)) + 1;

        vm.prank(PAUSE_PROXY); splitter.file("burn", minBurn - 1);

        vm.expectRevert("UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
        vow.flap();

        vm.prank(PAUSE_PROXY); splitter.file("burn", minBurn);
        doKick();
    }

    function testKickAfterHop() public {
        doKick();
        vm.warp(block.timestamp + flapper.hop());

        // make sure the slippage of the first kick doesn't block us
        uint256 _marginalWant = marginalWant(MKR, address(medianizer));
        vm.prank(PAUSE_PROXY); flapper.file("want", _marginalWant * 99 / 100);
        doKick();
    }

    function testKickBeforeHop() public {
        doKick();
        vm.warp(block.timestamp + flapper.hop() - 1 seconds);

        // make sure the slippage of the first kick doesn't block us
        uint256 _marginalWant = marginalWant(MKR, address(medianizer));
        vm.prank(PAUSE_PROXY); flapper.file("want", _marginalWant * 99 / 100);
        vm.expectRevert("FlapperUniV2SwapOnly/kicked-too-soon");
        vow.flap();
    }

    function testKickFlapperNotSet() public {
        vm.prank(PAUSE_PROXY); splitter.file("flapper", address(0));
        vm.expectRevert(bytes(""));
        vow.flap();
    }

    function checkChangeRewardDuration(uint256 newDuration) private {
        uint256 topup = 5707 * (WAD - 70 * WAD / 100);
        doKick();
        assertEq(farm.rewardsDuration(), flapper.hop());
        assertEq(farm.rewardsDuration(), 30 minutes);
        assertEq(farm.rewardRate(), topup / 30 minutes);
        uint256 prevRewardRate = farm.rewardRate();
        vm.warp(block.timestamp + 10 minutes);

        vm.prank(PAUSE_PROXY); farm.setRewardsDuration(newDuration); 
        vm.prank(PAUSE_PROXY); flapper.file("hop", newDuration);

        assertEq(farm.rewardsDuration(), newDuration);
        assertEq(farm.rewardRate(), (prevRewardRate * 20 minutes) / newDuration);
        prevRewardRate = farm.rewardRate();
        assertEq(farm.periodFinish(), block.timestamp + newDuration);

        if (newDuration > 10 minutes) vm.warp(block.timestamp + newDuration - 10 minutes);
        doKick();
        uint256 remaining = newDuration < 10 minutes ? newDuration : 10 minutes;
        assertEq(farm.rewardRate(), (prevRewardRate * remaining + topup) / newDuration);
        assertEq(farm.periodFinish(), block.timestamp + newDuration);

        vm.warp(block.timestamp + newDuration);
        doKick();
        assertEq(farm.rewardRate(), topup / newDuration);
        assertEq(farm.periodFinish(), block.timestamp + newDuration);
    }

    function testIncreaseRewardDuration() public {
        checkChangeRewardDuration(1 hours);
    }

    function testDecreaseRewardDuration() public {
        checkChangeRewardDuration(15 minutes);
    }

    function testDecreaseRewardDurationAllowingImmediateKick() public {
        checkChangeRewardDuration(5 minutes);
    }

    function testCageFlapperNotSet() public {
        vm.prank(PAUSE_PROXY); splitter.file("flapper", address(0));

        vm.expectRevert(bytes(""));
        vm.prank(PAUSE_PROXY); splitter.cage(0);
    }

    function testCage() public {
        assertEq(flapper.live(), 1);

        vm.expectEmit(false, false, false, true, address(flapper));
        emit Cage(0);
        vm.prank(PAUSE_PROXY); splitter.cage(0);

        assertEq(flapper.live(), 0);
        
        vm.expectRevert("FlapperUniV2SwapOnly/not-live");
        vow.flap();
    }

    function testCageThroughEnd() public {
        assertEq(flapper.live(), 1);

        vm.expectEmit(false, false, false, true, address(flapper));
        emit Cage(0);
        vm.prank(PAUSE_PROXY); end.cage();

        assertEq(flapper.live(), 0);

        vm.expectRevert("FlapperUniV2SwapOnly/not-live");
        vow.flap();
    }
}
