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
    function vat.dai(address) external returns (uint256) envfree;
    function dai.balanceOf(address) external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function pair.balanceOf(address) external returns (uint256) envfree;
    function pair.getReserves() external returns (uint112, uint112, uint32) envfree;
    function pair.totalSupply() external returns (uint256) envfree;
}

definition RAY() returns mathint = 10^27;

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

definition totalDai(mathint wlot, mathint reserveDai) returns mathint = wlot * (997 * wlot + 1997 * reserveDai) / (1000 * reserveDai);
definition amountOut(mathint amtIn, mathint reserveIn, mathint reserveOut) returns mathint = amtIn * 997 * reserveOut / (reserveIn * 1000 + amtIn * 997);
definition isAprox(mathint value1, mathint value2, mathint tolerance) returns bool = value1 >= value2 ? value1 - value2 <= tolerance : value2 - value1 <= tolerance;

// Verify correct storage changes for non reverting kick
rule kick(uint256 lot) {
    env e;

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

    mathint bought = amountOut(lot / RAY(), pairReservesDaiBefore, pairReservesMkrBefore);
    mathint totalDaiMoved = totalDai(lot / RAY(), pairReservesDaiBefore);

    uint256 random;
    kick(e, lot, random);

    mathint vatDaiSenderAfter = vat.dai(e.msg.sender);
    mathint pairReservesDaiAfter; mathint pairReservesMkrAfter;
    pairReservesDaiAfter, pairReservesMkrAfter, a = pair.getReserves();
    mathint daiBalanceOfPairAfter = dai.balanceOf(pair);
    mathint mkrBalanceOfPairAfter = mkr.balanceOf(pair);
    mathint pairBalanceOfReceiverAfter = pair.balanceOf(receiver);
    mathint pairTotalSupplyAfter = pair.totalSupply();

    assert vatDaiSenderAfter == vatDaiSenderBefore - totalDaiMoved * RAY(), "kick did not decrease vat.dai(sender) by totalDaiMoved * RAY()";
    assert pairReservesDaiAfter == daiBalanceOfPairBefore + totalDaiMoved, "kick did not increase the reserves by totalDaiMoved + existing difference with the balance";
    assert pairReservesMkrAfter == mkrBalanceOfPairBefore, "kick did not keep the reserves as the balance";
    assert pairReservesDaiAfter == daiBalanceOfPairAfter, "kick did not leave dai reserves synced";
    assert pairReservesMkrAfter == mkrBalanceOfPairAfter, "kick did not leave mkr reserves synced";
    assert pairBalanceOfReceiverAfter > pairBalanceOfReceiverBefore, "kick did not increase the pair balance of receiver";
    mathint liquidityGained = pairBalanceOfReceiverAfter - pairBalanceOfReceiverBefore;
    assert isAprox(bought, liquidityGained * pairReservesMkrAfter / pairTotalSupplyAfter, 1000), "kick did not left the amount of mkr that can be withdrawn aprox the same than the bought one";
    assert isAprox(totalDaiMoved - lot / RAY(), liquidityGained * pairReservesDaiAfter / pairTotalSupplyAfter, 1000), "kick did not left the amount of dai that can be withdrawn aprox the same than the deposited one";
}
