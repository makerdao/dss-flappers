// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

interface VatLike {
    function move(address, address, uint256) external;
    function hope(address) external;
    function nope(address) external;
}

interface FlapLike {
    function exec(uint256) external returns (uint256);
    function cage() external;
}

contract SplitterMock {
    constructor(
        address _vat
    ) {
        vat = VatLike(_vat);
    }

    FlapLike public           flapper;
    VatLike  public immutable vat;

    function file(bytes32 what, address data) external {
        if (what == "flapper") {
            vat.nope(address(flapper));
            flapper = FlapLike(data);
            vat.hope(data);
        }
        else revert("SplitterMock/file-unrecognized-param");
    }

    function kick(uint256 tot, uint256) external returns (uint256) {
        vat.move(msg.sender, address(this), tot);
        flapper.exec(tot);
        return 0;
    }

    function cage(uint256) external {
        FlapLike(flapper).cage();
    }
}
