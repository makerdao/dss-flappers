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
import { FlapperInstance } from "./FlapperInstance.sol";

interface FlapperUniV2Like {
    function vat() external view returns (address);
    function daiJoin() external view returns (address);
    function spotter() external view returns (address);
    function pip() external view returns (address);
    function pair() external view returns (address);
    function gem() external view returns (address);
    function rely(address) external;
    function file(bytes32, uint256) external;
    function file(bytes32, address) external;
}

interface FlapperMomLike {
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

interface FlapperCaller {
    function file(bytes32, address) external;
}

struct FlapperUniV2Config {
    uint256 hop;
    uint256 want;
    address pip;
    uint256 hump;
    uint256 bump;
    address caller;
    bytes32 chainlogKey;
}

struct SplitterConfig {
    uint256 burn;
    uint256 rewardsDuration;
}

library FlapperInit {
    uint256 constant WAD = 10 ** 18;

    function initFlapperUniV2(
        DssInstance        memory dss,
        FlapperInstance    memory flapperInstance,
        FlapperUniV2Config memory cfg
    ) internal {
        FlapperUniV2Like flapper = FlapperUniV2Like(flapperInstance.flapper);
        FlapperMomLike   mom     = FlapperMomLike(flapperInstance.mom);

        // Sanity checks
        require(flapper.vat()     == address(dss.vat),     "Flapper vat mismatch");
        require(flapper.daiJoin() == address(dss.daiJoin), "Flapper daiJoin mismatch");
        require(flapper.spotter() == address(dss.spotter), "Flapper spotter mismatch");

        PairLike pair = PairLike(flapper.pair());
        (address pairDai, address pairGem) = pair.token0() == address(dss.dai) ? (pair.token0(), pair.token1())
                                                                               : (pair.token1(), pair.token0());
        require(pairDai == address(dss.dai), "Dai mismatch");
        require(pairGem == flapper.gem(),    "Gem mismatch");

        require(cfg.hop >= 5 minutes, "hop too low");
        require(cfg.want >= WAD * 90 / 100, "want too low");
        require(cfg.hump > 0, "hump too low");

        flapper.file("hop",  cfg.hop);
        flapper.file("want", cfg.want);
        flapper.file("pip",  cfg.pip);
        flapper.rely(address(mom));
        flapper.rely(address(cfg.caller));

        FlapperCaller(cfg.caller).file("flapper", address(flapper));

        dss.vow.file("hump",    cfg.hump);
        dss.vow.file("bump",    cfg.bump);

        mom.setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        dss.chainlog.setAddress(cfg.chainlogKey, address(flapper)); // specific flapper chainlog key (e.g. MCD_FLAP_BURN)
        dss.chainlog.setAddress("MCD_FLAP", address(flapper)); // Note that this is overwritten in initSplitter
        dss.chainlog.setAddress("FLAPPER_MOM", address(mom));
    }

    function initDirectOracle(address flapper) internal {
        PipLike(FlapperUniV2Like(flapper).pip()).kiss(flapper);
    }

    function initOracleWrapper(DssInstance memory dss, address wrapper, bytes32 clKey) internal {
        PipLike(OracleWrapperLike(wrapper).pip()).kiss(wrapper);
        dss.chainlog.setAddress(clKey, wrapper);
    }

    function initSplitter(        
        DssInstance memory dss,
        address splitter,
        SplitterConfig memory cfg
    ) internal {
        // Sanity checks
        SplitterLike splitter_ = SplitterLike(splitter);
        require(splitter_.vat()     == address(dss.vat),     "Splitter vat mismatch");
        require(splitter_.daiJoin() == address(dss.daiJoin), "Splitter daiJoin mismatch");

        require(cfg.burn <= WAD, "Splitter burn too high");

        splitter_.file("burn", cfg.burn);
        FarmLike farm = FarmLike(splitter_.farm());
        farm.setRewardsDistribution(splitter);
        farm.setRewardsDuration(cfg.rewardsDuration);

        // Wire splitter with vow
        splitter_.rely(address(dss.vow));
        dss.vow.file("flapper", splitter);

        dss.chainlog.setAddress("MCD_FLAP", splitter);
    }
}
