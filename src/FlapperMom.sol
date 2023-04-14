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

pragma solidity ^0.8.16;

interface FlapperLike {
    function cage(uint256) external;
}

interface VatLike {
    function live() external view returns (uint256);
    function dai(address) external view returns (uint256);
    function move(address, address, uint256) external;
}

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

// Bypass governance delay to disable the flapper instance
contract FlapperMom {
    address public owner;
    address public authority;

    FlapperLike public immutable flapper;
    VatLike     public immutable vat;
    address     public immutable vow;

    event SetOwner(address indexed newOwner);
    event SetAuthority(address indexed newAuthority);
    event Cage(uint256 rad);

    modifier onlyOwner {
        require(msg.sender == owner, "FlapperMom/only-owner");
        _;
    }

    constructor(address _flapper, address _vat, address _vow) {
        flapper = FlapperLike(_flapper);
        vat     = VatLike(_vat);
        vow     = _vow;
        
        owner = msg.sender;
        emit SetOwner(msg.sender);
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        }
    }

    // Governance actions with delay
    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
        emit SetOwner(owner_);
    }

    function setAuthority(address authority_) external onlyOwner {
        authority = authority_;
        emit SetAuthority(authority_);
    }

    // Governance action without delay
    function cage() external {
        require(isAuthorized(msg.sender, msg.sig), "FlapperMom/not-authorized");

        uint256 _rad = vat.dai(address(flapper));
        flapper.cage(_rad);
        vat.move(address(this), vow, _rad);
        emit Cage(_rad);
    }
}
