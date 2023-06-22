// FlapperUniV2.spec

using Vat as vat;
using DaiJoin as daiJoin;
using Dai as dai;
using DSToken as mkr;
using SpotterMock as spotter;
using PipMock as pip;
using UniswapV2Pair as pair;

methods {
    function wards(address) external returns (uint256) envfree;
    function live() external returns (uint256) envfree;
    function pip() external returns (address) envfree;
    function hop() external returns (uint256) envfree;
    function zzz() external returns (uint256) envfree;
    function want() external returns (uint256) envfree;
    function pip() external returns (address) envfree;
    function vat() external returns (address) envfree;
    function daiJoin() external returns (address) envfree;
    function spotter() external returns (address) envfree;
    function dai() external returns (address) envfree;
    function gem() external returns (address) envfree;
    function receiver() external returns (address) envfree;
    function pair() external returns (address) envfree;
    function daiFirst() external returns (bool) envfree;
    function vat.can(address, address) external returns (uint256) envfree;
    function vat.dai(address) external returns (uint256) envfree;
    function dai.balanceOf(address) external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function pip.read() external returns (uint256) envfree;
    function spotter.par() external returns (uint256) envfree;
    function pair.balanceOf(address) external returns (uint256) envfree;
    function pair.getReserves() external returns (uint112, uint112, uint32) envfree;
    function pair.totalSupply() external returns (uint256) envfree;
    function pair.unlocked() external returns (uint256) envfree;
}

definition RAY() returns mathint = 10^27;
definition maxuint112() returns mathint = 2^112 - 1;

// Verify correct storage changes for non reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);
    mathint liveBefore = live();
    address pipBefore = pip();
    mathint hopBefore = hop();
    mathint zzzBefore = zzz();
    mathint wantBefore = want();

    rely(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);
    mathint liveAfter = live();
    address pipAfter = pip();
    mathint hopAfter = hop();
    mathint zzzAfter = zzz();
    mathint wantAfter = want();

    assert wardsUsrAfter == 1, "rely did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "rely did not keep unchanged the rest of wards[x]";
    assert liveAfter == liveBefore, "rely did not keep unchanged live";
    assert pipAfter == pipBefore, "rely did not keep unchanged pip";
    assert hopAfter == hopBefore, "rely did not keep unchanged hop";
    assert zzzAfter == zzzBefore, "rely did not keep unchanged zzz";
    assert wantAfter == wantBefore, "rely did not keep unchanged want";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;
    address anyUsr; address anyUsr2;

    mathint wardsOtherBefore = wards(other);
    mathint liveBefore = live();
    address pipBefore = pip();
    mathint hopBefore = hop();
    mathint zzzBefore = zzz();
    mathint wantBefore = want();

    deny(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);
    mathint liveAfter = live();
    address pipAfter = pip();
    mathint hopAfter = hop();
    mathint zzzAfter = zzz();
    mathint wantAfter = want();

    assert wardsUsrAfter == 0, "deny did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "deny did not keep unchanged the rest of wards[x]";
    assert liveAfter == liveBefore, "deny did not keep unchanged live";
    assert pipAfter == pipBefore, "deny did not keep unchanged pip";
    assert hopAfter == hopBefore, "deny did not keep unchanged hop";
    assert zzzAfter == zzzBefore, "deny did not keep unchanged zzz";
    assert wantAfter == wantBefore, "deny did not keep unchanged want";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}

definition getTotalDai(mathint wlot, mathint reserveDai) returns mathint = wlot * (997 * wlot + 1997 * reserveDai) / (1000 * reserveDai);
definition getAmountOut(mathint amtIn, mathint reserveIn, mathint reserveOut) returns mathint = amtIn * 997 * reserveOut / (reserveIn * 1000 + amtIn * 997);
definition isAprox(mathint value1, mathint value2, mathint tolerance) returns bool = value1 >= value2 ? value1 - value2 <= tolerance : value2 - value1 <= tolerance;

// Verify correct storage changes for non reverting kick
rule kick(uint256 lot) {
    env e;

    require e.msg.sender != daiJoin;

    require lot > 0;

    mathint vatDaiSenderBefore = vat.dai(e.msg.sender);
    mathint pairReservesDaiBefore; mathint pairReservesMkrBefore; mathint a;
    pairReservesDaiBefore, pairReservesMkrBefore, a = pair.getReserves();
    mathint daiBalanceOfPairBefore = dai.balanceOf(pair);
    mathint mkrBalanceOfPairBefore = mkr.balanceOf(pair);
    address receiver = receiver();
    mathint pairBalanceOfReceiverBefore = pair.balanceOf(receiver);
    mathint pairTotalSupplyBefore = pair.totalSupply();

    require pairTotalSupplyBefore >= pairBalanceOfReceiverBefore;
    require pairReservesDaiBefore > 0;
    require pairReservesMkrBefore > 0;
    require daiBalanceOfPairBefore >= pairReservesDaiBefore;
    require mkrBalanceOfPairBefore >= pairReservesMkrBefore;

    mathint wlot = lot / RAY();
    mathint totalDai = getTotalDai(wlot, daiBalanceOfPairBefore);
    mathint bought = getAmountOut(wlot, daiBalanceOfPairBefore, mkrBalanceOfPairBefore);

    uint256 random;
    kick(e, lot, random);

    mathint vatDaiSenderAfter = vat.dai(e.msg.sender);
    mathint pairReservesDaiAfter; mathint pairReservesMkrAfter;
    pairReservesDaiAfter, pairReservesMkrAfter, a = pair.getReserves();
    mathint daiBalanceOfPairAfter = dai.balanceOf(pair);
    mathint mkrBalanceOfPairAfter = mkr.balanceOf(pair);
    mathint pairBalanceOfReceiverAfter = pair.balanceOf(receiver);
    mathint pairTotalSupplyAfter = pair.totalSupply();

    assert vatDaiSenderAfter == vatDaiSenderBefore - totalDai * RAY(), "kick did not decrease vat.dai(sender) by totalDai * RAY()";
    assert pairReservesDaiAfter == daiBalanceOfPairBefore + totalDai, "kick did not increase the reserves by totalDai + existing difference with the balance";
    assert pairReservesMkrAfter == mkrBalanceOfPairBefore, "kick did not keep the reserves as the balance";
    assert pairReservesDaiAfter == daiBalanceOfPairAfter, "kick did not leave dai reserves synced";
    assert pairReservesMkrAfter == mkrBalanceOfPairAfter, "kick did not leave mkr reserves synced";
    assert pairBalanceOfReceiverAfter > pairBalanceOfReceiverBefore, "kick did not increase the pair balance of receiver";
    mathint liquidityGained = pairBalanceOfReceiverAfter - pairBalanceOfReceiverBefore;
    assert isAprox(bought, liquidityGained * pairReservesMkrAfter / pairTotalSupplyAfter, 1000), "kick did not left the amount of mkr that can be withdrawn aprox the same than the bought one";
    assert isAprox(totalDai - wlot, liquidityGained * pairReservesDaiAfter / pairTotalSupplyAfter, 1000), "kick did not left the amount of dai that can be withdrawn aprox the same than the deposited one";
}

// Verify revert rules on kick
rule kick_revert(uint256 lot) {
    env e;

    require pair.unlocked() == 1;

    mathint wardsSender = wards(e.msg.sender);
    mathint live = live();
    mathint zzz = zzz();
    mathint hop = hop();
    mathint want = want();

    mathint vatDaiSender = vat.dai(e.msg.sender);
    mathint vatDaiFlapper = vat.dai(currentContract);
    mathint vatDaiDaiJoin = vat.dai(daiJoin);
    mathint vatCanSenderFlapper = vat.can(e.msg.sender, currentContract);
    mathint vatCanFlapperDaiJoin = vat.can(currentContract, daiJoin);
    mathint pairReservesDai; mathint pairReservesMkr; mathint a;
    pairReservesDai, pairReservesMkr, a = pair.getReserves();
    mathint daiBalanceOfPair = dai.balanceOf(pair);
    mathint mkrBalanceOfPair = mkr.balanceOf(pair);
    address receiver = receiver();
    mathint pairBalanceOfReceiver = pair.balanceOf(receiver);
    mathint pairTotalSupply = pair.totalSupply();

    require pairTotalSupply >= pairBalanceOfReceiver;
    require pairReservesDai > 0;
    require pairReservesMkr > 0;
    require daiBalanceOfPair >= pairReservesDai;
    require mkrBalanceOfPair >= pairReservesMkr;

    mathint wlot = lot / RAY();
    mathint totalDai = getTotalDai(wlot, daiBalanceOfPair);
    mathint bought = getAmountOut(wlot, daiBalanceOfPair, mkrBalanceOfPair);

    mathint price = pip.read();
    mathint par = spotter.par();
    require par > 0;
    require (price * RAY() / par) > 0;

    uint256 random;
    kick@withrevert(e, lot, random);

    bool revert1  = e.msg.value > 0;
    bool revert2  = wardsSender != 1;
    bool revert3  = live != 1;
    bool revert4  = zzz + hop > max_uint256;
    bool revert5  = to_mathint(e.block.timestamp) < zzz + hop;
    bool revert6  = wlot * (997 * wlot + 1997 * daiBalanceOfPair) > max_uint256;
    bool revert7  = totalDai >= lot * 220 / 100;
    bool revert8  = wlot * 997 * mkrBalanceOfPair > max_uint256;
    bool revert9  = daiBalanceOfPair * 100 + (wlot * 997) > max_uint256;
    bool revert10 = bought < wlot * want / (price * RAY() / par);
    bool revert11 = vatCanSenderFlapper != 1;
    bool revert12 = vatDaiSender < totalDai * RAY();
    bool revert13 = vatDaiFlapper + totalDai * RAY() > max_uint256;
    bool revert14 = vatCanFlapperDaiJoin != 1;
    bool revert15 = vatDaiDaiJoin + totalDai * RAY() > max_uint256;
    bool revert16 = bought == 0;
    bool revert17 = bought > mkrBalanceOfPair;
    bool revert18 = daiBalanceOfPair > maxuint112() || mkrBalanceOfPair + bought > maxuint112();
    bool revert19 = daiBalanceOfPair + totalDai > max_uint256;
    bool revert20 = mkrBalanceOfPair + bought > max_uint256;

    assert revert1  => lastReverted, "revert1 failed";
    assert revert2  => lastReverted, "revert2 failed";
    assert revert3  => lastReverted, "revert3 failed";
    assert revert4  => lastReverted, "revert4 failed";
    assert revert5  => lastReverted, "revert5 failed";
    assert revert6  => lastReverted, "revert6 failed";
    assert revert7  => lastReverted, "revert7 failed";
    assert revert8  => lastReverted, "revert8 failed";
    assert revert9  => lastReverted, "revert9 failed";
    assert revert10 => lastReverted, "revert10 failed";
    assert revert11 => lastReverted, "revert11 failed";
    assert revert12 => lastReverted, "revert12 failed";
    assert revert13 => lastReverted, "revert13 failed";
    assert revert14 => lastReverted, "revert14 failed";
    assert revert15 => lastReverted, "revert15 failed";
    assert revert16 => lastReverted, "revert16 failed";
    assert revert17 => lastReverted, "revert17 failed";
    assert revert18 => lastReverted, "revert18 failed";
    assert revert19 => lastReverted, "revert19 failed";
    assert revert20 => lastReverted, "revert20 failed";
    assert lastReverted => revert1  || revert2  || revert3  ||
                           revert4  || revert5  || revert6  ||
                           revert7  || revert8  || revert9  ||
                           revert10 || revert11 || revert12 ||
                           revert13 || revert14 || revert15 ||
                           revert16 || revert17 || revert18 ||
                           revert19 || revert20, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting cage
rule cage() {
    env e;

    address anyUsr;

    mathint wardsBefore = wards(anyUsr);
    address pipBefore = pip();
    mathint hopBefore = hop();
    mathint zzzBefore = zzz();
    mathint wantBefore = want();

    uint256 random;
    cage(e, random);

    mathint wardsAfter = wards(anyUsr);
    mathint liveAfter = live();
    address pipAfter = pip();
    mathint hopAfter = hop();
    mathint zzzAfter = zzz();
    mathint wantAfter = want();

    assert wardsAfter == wardsBefore, "cage did not keep unchanged every wards[x]";
    assert liveAfter == 0, "cage did not set live to 0";
    assert pipAfter == pipBefore, "cage did not keep unchanged pip";
    assert hopAfter == hopBefore, "cage did not keep unchanged hop";
    assert zzzAfter == zzzBefore, "cage did not keep unchanged zzz";
    assert wantAfter == wantBefore, "cage did not keep unchanged want";
}

// Verify revert rules on cage
rule cage_revert() {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    uint256 random;
    cage@withrevert(e, random);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "Revert rules are not covering all the cases";
}
