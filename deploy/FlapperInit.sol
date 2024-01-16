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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity >=0.8.0;

import { DssInstance } from "dss-test/MCD.sol";
import { SplitterInstance } from "./SplitterInstance.sol";

interface FlapperUniV2Like {
    function vat() external view returns (address);
    function daiJoin() external view returns (address);
    function spotter() external view returns (address);
    function pip() external view returns (address);
    function pair() external view returns (address);
    function gem() external view returns (address);
    function receiver() external view returns (address);
    function rely(address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, address) external;
}

interface SplitterMomLike {
    function setAuthority(address) external;
}

interface OracleWrapperLike {
    function pip() external view returns (address);
}

interface PipLike {
    function kiss(address) external;
}

interface PairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface DaiJoinLike {
    function dai() external view returns (address);
}

interface SplitterLike {
    function vat() external view returns (address);
    function daiJoin() external view returns (address);
    function farm() external view returns (address);
    function rely(address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, address) external;
}

interface FarmLike {
    function setRewardsDistribution(address) external;
    function setRewardsDuration(uint256) external;
}

struct FlapperUniV2Config {
    uint256 want;
    address pip;
    address pair;
    address daiJoin;
    address splitter;
    bytes32 prevChainlogKey;
    bytes32 chainlogKey;
}

struct SplitterConfig {
    uint256 hump;
    uint256 bump;
    uint256 hop;
    uint256 burn;
    address farm;
    address daiJoin;
    bytes32 splitterChainlogKey;
    bytes32 prevMomChainlogKey;
    bytes32 momChainlogKey;
}

library FlapperInit {
    uint256 constant WAD = 10 ** 18;

    function initFlapperUniV2(
        DssInstance        memory dss,
        address                   flapper_,
        FlapperUniV2Config memory cfg
    ) internal {
        FlapperUniV2Like flapper = FlapperUniV2Like(flapper_);

        // Sanity checks
        require(flapper.vat()      == address(dss.vat),                           "Flapper vat mismatch");
        require(flapper.daiJoin()  == cfg.daiJoin,                                "Flapper daiJoin mismatch");
        require(flapper.spotter()  == address(dss.spotter),                       "Flapper spotter mismatch");
        require(flapper.pair()     == cfg.pair,                                   "Flapper pair mismatch");
        require(flapper.receiver() == dss.chainlog.getAddress("MCD_PAUSE_PROXY"), "Flapper receiver mismatch");

        PairLike pair = PairLike(flapper.pair());
        address  dai  = DaiJoinLike(cfg.daiJoin).dai();
        (address pairDai, address pairGem) = pair.token0() == dai ? (pair.token0(), pair.token1())
                                                                  : (pair.token1(), pair.token0());
        require(pairDai == dai,           "Dai mismatch");
        require(pairGem == flapper.gem(), "Gem mismatch");

        require(cfg.want >= WAD * 90 / 100, "want too low");

        flapper.file("want", cfg.want);
        flapper.file("pip",  cfg.pip);
        flapper.rely(cfg.splitter);

        SplitterLike(cfg.splitter).file("flapper", flapper_);

        if (cfg.prevChainlogKey != bytes32(0)) dss.chainlog.removeAddress(cfg.prevChainlogKey);
        dss.chainlog.setAddress(cfg.chainlogKey, flapper_);
    }

    function initDirectOracle(address flapper) internal {
        PipLike(FlapperUniV2Like(flapper).pip()).kiss(flapper);
    }

    function initOracleWrapper(DssInstance memory dss, address wrapper, bytes32 clKey) internal {
        PipLike(OracleWrapperLike(wrapper).pip()).kiss(wrapper);
        dss.chainlog.setAddress(clKey, wrapper);
    }

    function initSplitter(        
        DssInstance      memory dss,
        SplitterInstance memory splitterInstance,
        SplitterConfig   memory cfg
    ) internal {
        SplitterLike    splitter = SplitterLike(splitterInstance.splitter);
        SplitterMomLike mom      = SplitterMomLike(splitterInstance.mom);

        // Sanity checks
        require(splitter.vat()     == address(dss.vat), "Splitter vat mismatch");
        require(splitter.daiJoin() == cfg.daiJoin,      "Splitter daiJoin mismatch");
        require(splitter.farm()    == cfg.farm,         "Splitter farm mismatch");

        require(cfg.hump > 0,         "hump too low");
        require(cfg.hop >= 5 minutes, "hop too low");
        require(cfg.burn <= WAD,      "burn too high");

        splitter.file("hop",  cfg.hop);
        splitter.file("burn", cfg.burn);
        splitter.rely(address(mom));
        splitter.rely(address(dss.vow));

        FarmLike farm = FarmLike(cfg.farm);
        farm.setRewardsDistribution(splitterInstance.splitter);
        farm.setRewardsDuration(cfg.hop);

        dss.vow.file("flapper", splitterInstance.splitter);
        dss.vow.file("hump", cfg.hump);
        dss.vow.file("bump", cfg.bump);

        mom.setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        dss.chainlog.setAddress(cfg.splitterChainlogKey, splitterInstance.splitter);
        if (cfg.prevMomChainlogKey != bytes32(0)) dss.chainlog.removeAddress(cfg.prevMomChainlogKey);
        dss.chainlog.setAddress(cfg.momChainlogKey, address(mom));
    }
}
