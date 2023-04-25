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
    function live() external view returns (uint256);
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
    function approve(address, uint256) external;
}

interface PipLike {
    function read() external view returns (bytes32);
}

interface RouterLike {
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
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
}

contract FlapperUniV2 {
    mapping (address => uint256) public wards;

    uint256 public live;  // Active Flag
    uint256 public hop;   // [Seconds]    Time between kicks
    uint256 public zzz;   // [Timestamp]  Last kick
    uint256 public want;  // [WAD]        Relative multiplier of the reference price to insist on in the swap.
                          //              For example: 0.98 * WAD allows 2% worse price than the reference.

    VatLike     public immutable vat;
    DaiJoinLike public immutable daiJoin;
    SpotterLike public immutable spotter;
    PipLike     public immutable pip;
    address     public immutable dai;
    address     public immutable gem;
    address     public immutable receiver;

    RouterLike  public immutable router;
    PairLike    public immutable pair;
    bool        public immutable daiFirst;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event Kick(uint256 lot, uint256 bought, uint256 wad, uint256 liquidity);
    event Cage(uint256 rad);

    constructor(
        address _daiJoin,
        address _spotter,
        address _gem,
        address _pip,
        address _router,
        address _pair,
        address _receiver
    ) {
        daiJoin = DaiJoinLike(_daiJoin);
        vat     = VatLike(daiJoin.vat());
        spotter = SpotterLike(_spotter);
        pip     = PipLike(_pip);

        dai = daiJoin.dai();
        gem = _gem;
        require(GemLike(gem).decimals() == 18, "FlapperUniV2/gem-decimals-not-18");

        router   = RouterLike(_router);
        pair     = PairLike(_pair);
        daiFirst = pair.token0() == dai;
        receiver = _receiver;

        vat.hope(address(daiJoin));
        GemLike(dai).approve(address(router), type(uint256).max);
        GemLike(gem).approve(address(router), type(uint256).max);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        // Initial values for safety
        hop  = 1 hours;
        want = WAD;

        live = 1;
    }

    modifier auth {
        require(wards[msg.sender] == 1, "FlapperUniV2/not-authorized");
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
        else revert("FlapperUniV2/file-unrecognized-param");
        emit File(what, data);
    }

    function kick(uint256 lot, uint256) external auth returns (uint256) {
        require(live == 1, "FlapperUniV2/not-live");

        require(block.timestamp >= zzz + hop, "FlapperUniV2/kicked-too-soon");
        zzz = block.timestamp;

        uint256 _wlot = lot / RAY;
        require(_wlot * RAY == lot, "FlapperUniV2/lot-not-multiple-of-ray");

        vat.move(msg.sender, address(this), lot);
        daiJoin.exit(address(this), _wlot);

        address[] memory _path = new address[](2);
        _path[0] = dai;
        _path[1] = gem;

        uint256 _ref = _wlot * WAD / (uint256(pip.read()) * RAY / spotter.par());
        uint256[] memory _amounts = router.swapExactTokensForTokens({
            amountIn:     _wlot,
            amountOutMin: _ref * want / WAD,
            path:         _path,
            to:           address(this),
            deadline:     block.timestamp
        });
        uint256 _bought = _amounts[1];

        (uint256 _reserveA, uint256 _reserveB, ) = pair.getReserves();
        uint256 _wad = daiFirst ? _bought * _reserveA / _reserveB
                                : _bought * _reserveB / _reserveA;
        require(_wad < _wlot * 110 / 100, "FlapperUniV2/slippage-insanity");

        vat.move(msg.sender, address(this), _wad * RAY);
        daiJoin.exit(address(this), _wad);

        (,, uint256 _liquidity) = router.addLiquidity({
            tokenA:         gem,
            tokenB:         dai,
            amountADesired: _bought,
            amountBDesired: _wad,
            amountAMin:     _bought,
            amountBMin:     _wad,
            to:             receiver,
            deadline:       block.timestamp
        });

        emit Kick(lot, _bought, _wad, _liquidity);
        return 0;
    }

    function cage(uint256) external auth {
        live = 0;
        emit Cage(0);
    }
}
