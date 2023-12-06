// FlapperUniV2SwapOnly.spec

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
    function want() external returns (uint256) envfree => ALWAYS(980000000000000000); // 0.98 * 10^18;
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
    function daiJoin.live() external returns (uint256) envfree;
    function dai.balanceOf(address) external returns (uint256) envfree;
    function dai.totalSupply() external returns (uint256) envfree;
    function dai.wards(address) external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    function mkr.stopped() external returns (bool) envfree;
    function pip.read() external returns (uint256) envfree;
    function spotter.par() external returns (uint256) envfree => ALWAYS(1000000000000000000000000000); // 10^27
    function pair.balanceOf(address) external returns (uint256) envfree;
    function pair.getReserves() external returns (uint112, uint112, uint32) envfree;
    function pair.totalSupply() external returns (uint256) envfree;
    function pair.unlocked() external returns (uint256) envfree;
    function _.uniswapV2Call(address , uint , uint , bytes) external => NONDET;
    function UniswapV2Pair.sync() external => NONDET;
}

definition WAD() returns mathint = 10^18;
definition RAY() returns mathint = 10^27;
definition maxuint112() returns mathint = 2^112 - 1;

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;
    bytes32 anyBytes32;

    mathint wardsBefore = wards(anyAddr);
    mathint liveBefore = live();
    address pipBefore = pip();
    mathint hopBefore = hop();
    mathint zzzBefore = zzz();
    mathint wantBefore = want();

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    mathint liveAfter = live();
    address pipAfter = pip();
    mathint hopAfter = hop();
    mathint zzzAfter = zzz();
    mathint wantAfter = want();

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "wards[x] changed in an unexpected function";
    assert liveAfter != liveBefore => f.selector == sig:cage(uint256).selector, "live changed in an unexpected function";
    assert pipAfter != pipBefore => f.selector == sig:file(bytes32,address).selector, "pip changed in an unexpected function";
    assert hopAfter != hopBefore => f.selector == sig:file(bytes32,uint256).selector, "hop changed in an unexpected function";
    assert zzzAfter != zzzBefore => f.selector == sig:kick(uint256,uint256).selector, "zzz changed in an unexpected function";
    assert wantAfter != wantBefore => f.selector == sig:file(bytes32,uint256).selector, "want changed in an unexpected function";
}

// Verify correct storage changes for non reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    rely(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 1, "rely did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "rely did not keep unchanged the rest of wards[x]";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    deny(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 0, "deny did not set the wards";
    assert wardsOtherAfter == wardsOtherBefore, "deny did not keep unchanged the rest of wards[x]";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting file
rule file_uint256(bytes32 what, uint256 data) {
    env e;

    uint256 hopBefore = hop();
    uint256 wantBefore = want();

    file(e, what, data);

    uint256 hopAfter = hop();
    uint256 wantAfter = want();

    assert what == to_bytes32(0x686f700000000000000000000000000000000000000000000000000000000000) => hopAfter == data, "file did not set hop";
    assert what != to_bytes32(0x686f700000000000000000000000000000000000000000000000000000000000) => hopAfter == hopBefore, "file did keep unchanged hop";
    assert what == to_bytes32(0x77616e7400000000000000000000000000000000000000000000000000000000) => wantAfter == data, "file did not set want";
    assert what != to_bytes32(0x77616e7400000000000000000000000000000000000000000000000000000000) => wantAfter == wantBefore, "file did keep unchanged want";
}

// Verify revert rules on file
rule file_uint256_revert(bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != to_bytes32(0x686f700000000000000000000000000000000000000000000000000000000000) && what != to_bytes32(0x77616e7400000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting file
rule file_address(bytes32 what, address data) {
    env e;

    file(e, what, data);

    address pipAfter = pip();

    assert pipAfter == data, "file did not set pip";
}

// Verify revert rules on file
rule file_address_revert(bytes32 what, address data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != to_bytes32(0x7069700000000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

definition getAmountOut(mathint amtIn, mathint reserveIn, mathint reserveOut) returns mathint = amtIn * 997 * reserveOut / (reserveIn * 1000 + amtIn * 997);

// Verify correct storage changes for non reverting kick
rule kick(uint256 lot, uint256 a) {
    env e;

    require e.msg.sender != daiJoin;
    require daiFirst();

    address receiver = receiver();

    mathint pairReservesDaiBefore; mathint pairReservesMkrBefore; mathint b;
    pairReservesDaiBefore, pairReservesMkrBefore, b = pair.getReserves();
    mathint vatDaiSenderBefore = vat.dai(e.msg.sender);
    mathint daiBalanceOfPairBefore = dai.balanceOf(pair);
    mathint mkrBalanceOfReceiverBefore = mkr.balanceOf(receiver);
    mathint mkrBalanceOfPairBefore = mkr.balanceOf(pair);

    mathint wlot = lot / RAY();
    require pairReservesDaiBefore * 1000 + wlot * 997 > 0; // Avoid division by zero
    mathint bought = getAmountOut(wlot, pairReservesDaiBefore, pairReservesMkrBefore);

    kick(e, lot, a);

    mathint vatDaiSenderAfter = vat.dai(e.msg.sender);
    mathint daiBalanceOfPairAfter = dai.balanceOf(pair);
    mathint mkrBalanceOfReceiverAfter = mkr.balanceOf(receiver);
    mathint mkrBalanceOfPairAfter = mkr.balanceOf(pair);

    assert vatDaiSenderAfter == vatDaiSenderBefore - wlot * RAY(), "kick did not decrease vat.dai(sender) by wlot * RAY()";
    assert daiBalanceOfPairAfter == daiBalanceOfPairBefore + wlot, "kick did not increase dai.balanceOf(pair) by wlot";
    assert receiver != pair => mkrBalanceOfPairAfter == mkrBalanceOfPairBefore - bought, "kick did not decrease mkr.balanceOf(pair) by bought";
    assert receiver != pair => mkrBalanceOfReceiverAfter == mkrBalanceOfReceiverBefore + bought, "kick did not increase mkr.balanceOf(receiver) by bought";
    assert receiver == pair => mkrBalanceOfReceiverAfter == mkrBalanceOfReceiverBefore, "kick did not keep unchanged mkr.balanceOf(receiver)";
}

// Verify revert rules on kick
rule kick_revert(uint256 lot, uint256 a) {
    env e;

    require e.msg.sender != currentContract;
    require e.msg.sender != daiJoin;

    require daiFirst();
    require daiJoin.live() == 1;
    require pair.unlocked() == 1;

    address receiver = receiver();

    mathint wardsSender = wards(e.msg.sender);
    mathint live = live();
    mathint zzz = zzz();
    mathint hop = hop();
    mathint want = want();

    require dai.wards(daiJoin) == 1;

    mathint vatDaiSender = vat.dai(e.msg.sender);
    mathint vatDaiFlapper = vat.dai(currentContract);
    mathint vatDaiDaiJoin = vat.dai(daiJoin);
    mathint vatCanSenderFlapper = vat.can(e.msg.sender, currentContract);
    mathint vatCanFlapperDaiJoin = vat.can(currentContract, daiJoin);
    mathint pairReservesDai; mathint pairReservesMkr; mathint b;
    pairReservesDai, pairReservesMkr, b = pair.getReserves();
    mathint daiBalanceOfPair = dai.balanceOf(pair);
    mathint daiTotalSupply = dai.totalSupply();
    require daiBalanceOfPair <= daiTotalSupply;
    mathint mkrBalanceOfPair = mkr.balanceOf(pair);
    require mkr.balanceOf(receiver) + mkr.balanceOf(pair) <= to_mathint(mkr.totalSupply());
    bool mkrStopped = mkr.stopped();
    require pairReservesDai > 0;
    require pairReservesMkr > 0;
    require daiBalanceOfPair >= pairReservesDai;
    require mkrBalanceOfPair >= pairReservesMkr;

    mathint wlot = lot / RAY();
    require pairReservesDai * 1000 + wlot * 997 > 0; // Avoid division by zero
    mathint bought = getAmountOut(wlot, pairReservesDai, pairReservesMkr);

    mathint price = pip.read();
    mathint par = spotter.par();
    require par > 0;
    require (price * RAY() / par) > 0;

    kick@withrevert(e, lot, a);

    bool revert1  = e.msg.value > 0;
    bool revert2  = wardsSender != 1;
    bool revert3  = live != 1;
    bool revert4  = zzz + hop > max_uint256;
    bool revert5  = to_mathint(e.block.timestamp) < zzz + hop;
    bool revert6  = wlot * (997 * wlot + 1997 * daiBalanceOfPair) > max_uint256;
    bool revert7  = wlot * 997 * mkrBalanceOfPair > max_uint256;
    bool revert8  = daiBalanceOfPair * 100 + (wlot * 997) > max_uint256;
    bool revert9 = wlot * want > max_uint256;
    bool revert10 = price * RAY() > max_uint256;
    bool revert11 = bought < wlot * want / (price * RAY() / par);
    bool revert12 = vatCanSenderFlapper != 1;
    bool revert13 = vatDaiSender < wlot * RAY();
    bool revert14 = vatDaiFlapper + wlot * RAY() > max_uint256;
    bool revert15 = vatCanFlapperDaiJoin != 1;
    bool revert16 = vatDaiDaiJoin + wlot * RAY() > max_uint256;
    bool revert17 = bought == 0;
    bool revert18 = receiver == dai || receiver == mkr;
    bool revert19 = mkrStopped;
    bool revert20 = daiTotalSupply + wlot > max_uint256;
    bool revert21 = daiBalanceOfPair + wlot > maxuint112() || mkrBalanceOfPair - (receiver != pair ? bought : 0) > maxuint112();

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert revert3 => lastReverted, "revert3 failed";
    assert revert4 => lastReverted, "revert4 failed";
    assert revert5 => lastReverted, "revert5 failed";
    assert revert6 => lastReverted, "revert6 failed";
    assert revert7 => lastReverted, "revert7 failed";
    assert revert8 => lastReverted, "revert8 failed";
    assert revert9 => lastReverted, "revert9 failed";
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
    assert revert21 => lastReverted, "revert21 failed";

    assert lastReverted => revert1  || revert2  || revert3  ||
                            revert4  || revert5  || revert6  ||
                            revert7  || revert8  || revert9  ||
                            revert10 || revert11 || revert12 ||
                            revert13 || revert14 || revert15 ||
                            revert16 || revert17 || revert18 ||
                            revert19 || revert20 || revert21, "Revert rules failed";
}

// Verify correct storage changes for non reverting cage
rule cage() {
    env e;

    uint256 random;
    cage(e, random);

    mathint liveAfter = live();

    assert liveAfter == 0, "cage did not set live to 0";
}

// Verify revert rules on cage
rule cage_revert() {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    uint256 random;
    cage@withrevert(e, random);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}
