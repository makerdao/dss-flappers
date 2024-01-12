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

interface VatLike {
    function move(address, address, uint256) external;
    function hope(address) external;
    function nope(address) external;
}

interface DaiJoinLike {
    function vat() external view returns (address);
    function exit(address, uint256) external;
}

interface FlapLike {
    function kick(uint256, uint256) external returns (uint256);
    function cage(uint256) external;
}

interface FarmLike {
    function notifyRewardAmount(uint256 reward) external;
}

contract Splitter {
    mapping (address => uint256) public wards;
    FlapLike    public           flapper;
    uint256     public           burn; // [WAD]       Burn percentage. 1 WAD = funneling 100% to the burn engine
    uint256     public           hop;  // [Seconds]   Time between kicks
    uint256     public           zzz;  // [Timestamp] Last kick

    VatLike     public immutable vat;
    DaiJoinLike public immutable daiJoin;
    FarmLike    public immutable farm;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event Kick(uint256 tot, uint256 lot, uint256 pay);

    constructor(
        address _daiJoin,
        address _farm
    ) {
        daiJoin = DaiJoinLike(_daiJoin);
        vat     = VatLike(daiJoin.vat());
        farm    = FarmLike(_farm);
        
        vat.hope(_daiJoin);
        
        // Initial value for safety
        hop  = 1 hours;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    modifier auth {
        require(wards[msg.sender] == 1, "Splitter/not-authorized");
        _;
    }

    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }

    function file(bytes32 what, uint256 data) external auth {
        if      (what == "burn") burn = data;
        else if (what == "hop")  hop  = data;
        else revert("Splitter/file-unrecognized-param");
        emit File(what, data);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "flapper") {
            vat.nope(address(flapper));
            flapper = FlapLike(data);
            vat.hope(data);
        }
        else revert("Splitter/file-unrecognized-param");
        emit File(what, data);
    }

    function kick(uint256 tot, uint256) external auth returns (uint256) {
        require(block.timestamp >= zzz + hop, "Splitter/kicked-too-soon");
        zzz = block.timestamp;

        vat.move(msg.sender, address(this), tot);

        uint256 lot = tot * burn / WAD;
        if (lot > 0) {
            flapper.kick(lot, 0);
        }

        uint256 pay = (tot - lot) / RAY;
        if (pay > 0) {
            DaiJoinLike(daiJoin).exit(address(farm), pay);
            farm.notifyRewardAmount(pay);
        }

        emit Kick(tot, lot, pay);
        return 0;
    }

    function cage(uint256) external auth {
        FlapLike(flapper).cage(0);
    }
}
