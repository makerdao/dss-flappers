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
    function hope(address) external;
    function move(address, address, uint256) external;
}

interface DaiJoinLike {
    function vat() external view returns (address);
    function dai() external view returns (address);
    function exit(address, uint256) external;
}

interface SpotterLike {
    function par() external view returns (uint256);
}

interface GemLike {
    function decimals() external view returns (uint8);
}

interface PipLike {
    function read() external view returns (bytes32);
}

// https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol
interface PairLike {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function swap(uint256, uint256, address, bytes calldata) external;
}

contract FlapperUniV2SwapOnly {
    mapping (address => uint256) public wards;

    uint256 public live;  // Active Flag
    PipLike public pip;   // Reference price oracle
    uint256 public hop;   // [Seconds]    Time between kicks
    uint256 public zzz;   // [Timestamp]  Last kick
    uint256 public want;  // [WAD]        Relative multiplier of the reference price to insist on in the swap.
                          //              For example: 0.98 * WAD allows 2% worse price than the reference.

    VatLike     public immutable vat;
    DaiJoinLike public immutable daiJoin;
    SpotterLike public immutable spotter;
    address     public immutable dai;
    address     public immutable gem;
    address     public immutable receiver;

    PairLike    public immutable pair;
    bool        public immutable daiFirst;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event Kick(uint256 lot, uint256 bought);
    event Cage(uint256 rad);

    constructor(
        address _daiJoin,
        address _spotter,
        address _gem,
        address _pair,
        address _receiver
    ) {
        daiJoin = DaiJoinLike(_daiJoin);
        vat     = VatLike(daiJoin.vat());
        spotter = SpotterLike(_spotter);

        dai = daiJoin.dai();
        gem = _gem;
        require(GemLike(gem).decimals() == 18, "FlapperUniV2SwapOnly/gem-decimals-not-18");

        pair     = PairLike(_pair);
        daiFirst = pair.token0() == dai;
        receiver = _receiver;

        vat.hope(address(daiJoin));

        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        // Initial values for safety
        hop  = 1 hours;
        want = WAD;

        live = 1;
    }

    modifier auth {
        require(wards[msg.sender] == 1, "FlapperUniV2SwapOnly/not-authorized");
        _;
    }

    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }

    // Warning - low `want` values increase the susceptibility to oracle manipulation attacks
    function file(bytes32 what, uint256 data) external auth {
        if      (what == "hop")  hop = data;
        else if (what == "want") want = data;
        else revert("FlapperUniV2SwapOnly/file-unrecognized-param");
        emit File(what, data);
    }

    function file(bytes32 what, address data) external auth {
        if (what == "pip") pip = PipLike(data);
        else revert("FlapperUniV2SwapOnly/file-unrecognized-param");
        emit File(what, data);
    }

    function _getReserves() internal view returns (uint256 reserveDai, uint256 reserveGem) {
        (uint256 _reserveA, uint256 _reserveB,) = pair.getReserves();
        (reserveDai, reserveGem) = daiFirst ? (_reserveA, _reserveB) : (_reserveB, _reserveA);
    }

    // Based on: https://github.com/Uniswap/v2-periphery/blob/0335e8f7e1bd1e8d8329fd300aea2ef2f36dd19f/contracts/libraries/UniswapV2Library.sol#L43
    function _getAmountOut(uint256 amtIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amtOut) {
        uint256 _amtInFee = amtIn * 997;
        amtOut = _amtInFee * reserveOut / (reserveIn * 1000 + _amtInFee);
    }

    function kick(uint256 lot, uint256) external auth returns (uint256) {
        require(live == 1, "FlapperUniV2SwapOnly/not-live");

        require(block.timestamp >= zzz + hop, "FlapperUniV2SwapOnly/kicked-too-soon");
        zzz = block.timestamp;

        // Check Amount to buy
        (uint256 _reserveDai, uint256 _reserveGem) = _getReserves();

        uint256 _wlot = lot / RAY;

        uint256 _buy = _getAmountOut(_wlot, _reserveDai, _reserveGem);
        require(_buy >= _wlot * want / (uint256(pip.read()) * RAY / spotter.par()), "FlapperUniV2SwapOnly/insufficient-buy-amount");
        //

        // Get Dai and swap
        vat.move(msg.sender, address(this), _wlot * RAY);
        daiJoin.exit(address(pair), _wlot);
        (uint256 _amt0Out, uint256 _amt1Out) = daiFirst ? (uint256(0), _buy) : (_buy, uint256(0));
        pair.swap(_amt0Out, _amt1Out, receiver, new bytes(0));
        //

        emit Kick(lot, _buy);
        return 0;
    }

    function cage(uint256) external auth {
        live = 0;
        emit Cage(0);
    }
}
