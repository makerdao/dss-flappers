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

import { DssInstance, MCD } from "dss-test/MCD.sol";
import { SplitterInstance } from "deploy/SplitterInstance.sol";
import { FlapperDeploy } from "deploy/FlapperDeploy.sol";
import { SplitterConfig, FlapperUniV2Config, FlapperInit } from "deploy/FlapperInit.sol";
import { SplitterMom } from "src/SplitterMom.sol";
import { Splitter } from "src/Splitter.sol";
import { StakingRewardsMock } from "test/mocks/StakingRewardsMock.sol";
import { GemMock } from "test/mocks/GemMock.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface ChiefLike {
    function hat() external view returns (address);
}

contract SplitterMomTest is DssTest {
    using stdStorage for StdStorage;

    Splitter    splitter;
    SplitterMom mom;

    address DAI_JOIN;
    address SPOT;
    address VOW;
    address DAI;
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
        DAI               = ChainlogLike(LOG).getAddress("MCD_DAI");
        VOW               = ChainlogLike(LOG).getAddress("MCD_VOW");
        MKR               = ChainlogLike(LOG).getAddress("MCD_GOV");
        PAUSE_PROXY       = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        chief             = ChiefLike(ChainlogLike(LOG).getAddress("MCD_ADM"));

        address farm = address(new StakingRewardsMock(PAUSE_PROXY, address(0), DAI, address(new GemMock(1_000_000 ether))));
        SplitterInstance memory splitterInstance = FlapperDeploy.deploySplitter({
            deployer: address(this),
            owner:    PAUSE_PROXY,
            daiJoin:  DAI_JOIN,
            farm:     farm
        });
        splitter = Splitter(splitterInstance.splitter);
        mom = SplitterMom(splitterInstance.mom);

        address flapper = FlapperDeploy.deployFlapperUniV2({
            deployer: address(this),
            owner:    PAUSE_PROXY,
            daiJoin:  DAI_JOIN,
            spotter:  SPOT,
            gem:      MKR,
            pair:     UNIV2_DAI_MKR_PAIR,
            receiver: PAUSE_PROXY,
            swapOnly: false
        });

        // use random values
        SplitterConfig memory splitterCfg = SplitterConfig({
            hump:                1,
            bump:                0,
            hop:                 5 minutes,
            burn:                WAD,
            daiJoin:             DAI_JOIN,
            farm:                farm,
            splitterChainlogKey: "MCD_FLAP_SPLIT",
            prevMomChainlogKey:  "FLAPPER_MOM",
            momChainlogKey:      "SPLITTER_MOM"
        });
        FlapperUniV2Config memory flapperCfg = FlapperUniV2Config({
            want:            1e18,
            pip:             address(0),
            pair:            UNIV2_DAI_MKR_PAIR,
            daiJoin:         DAI_JOIN,
            splitter:        address(splitter),
            prevChainlogKey: "MCD_FLAP",
            chainlogKey:     "MCD_FLAP_LP"
        });
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        vm.startPrank(PAUSE_PROXY);
        FlapperInit.initSplitter(dss, splitterInstance, splitterCfg);
        FlapperInit.initFlapperUniV2(dss, flapper, flapperCfg);
        vm.stopPrank();

        vm.expectRevert("dss-chain-log/invalid-key");
        dss.chainlog.getAddress("FLAPPER_MOM");
        assertEq(dss.chainlog.getAddress("SPLITTER_MOM"), splitterInstance.mom);

        assertLt(splitter.hop(), type(uint256).max);
    }

    function doStop(address sender) internal {
        vm.expectEmit(false, false, false, false);
        emit Stop();
        vm.prank(sender); mom.stop();
        assertEq(Splitter(address(mom.splitter())).hop(), type(uint256).max);
    }

    function testSetOwner() public {
        vm.expectEmit(true, false, false, false);
        emit SetOwner(address(123));
        vm.prank(PAUSE_PROXY); mom.setOwner(address(123));
        assertEq(mom.owner(), address(123));
    }

    function testSetOwnerNotAuthed() public {
        vm.expectRevert("SplitterMom/only-owner");
        vm.prank(address(456)); mom.setOwner(address(123));
    }

    function testSetAuthority() public {
        vm.expectEmit(true, false, false, false);
        emit SetAuthority(address(123));
        vm.prank(PAUSE_PROXY); mom.setAuthority(address(123));
        assertEq(mom.authority(), address(123));
    }

    function testSetAuthorityNotAuthed() public {
        vm.expectRevert("SplitterMom/only-owner");
        vm.prank(address(456)); mom.setAuthority(address(123));
    }

    function testStopFromOwner() public {
        doStop(PAUSE_PROXY);
        vm.expectRevert("Splitter/kicked-too-soon");
        vm.prank(PAUSE_PROXY); splitter.kick(0, 0);
    }

    function testStopFromHat() public {
        doStop(address(chief.hat()));
        vm.expectRevert("Splitter/kicked-too-soon");
        vm.prank(PAUSE_PROXY); splitter.kick(0, 0);
    }

    function testStopAfterZzzSet() public {
        stdstore.target(address(splitter)).sig("zzz()").checked_write(314);
        doStop(address(chief.hat()));
        vm.expectRevert(bytes(abi.encodeWithSignature("Panic(uint256)", 0x11))); // arithmetic error
        vm.prank(PAUSE_PROXY); splitter.kick(0, 0);
    }

    function testStopNonAuthed() public {
        vm.expectRevert("SplitterMom/not-authorized");
        vm.prank(address(456)); mom.stop();
    }
}
