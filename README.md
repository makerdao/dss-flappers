# Dss Flappers

Implementations of MakerDao surplus auctions, triggered on `vow.flap`.

### FlapperUniV2

Exposes a `kick` operation to be triggered periodically. Its logic withdraws `DAI` from the `vow` and buys `gem` tokens on Uniswap v2. The acquired tokens, along with a proportional amount of `DAI` (saved from the initial withdraw) are deposited back into the liquidity pool. Finally, the minted LP tokens are sent to a predefined `receiver` address.

Configurable Parameters:
* `hop` - Minimum seconds interval between kicks.
* `pip` - A reference price oracle, used for bounding the exchange rate of the swap.
* `want` - Relative multiplier of the reference price to insist on in the swap. For example, a value of 0.98 * `WAD` allows for a 2% worse price than the reference.

#### Note:

* Although the Flapper interface is conformant with the Emergency Shutdown procedure and will stop operating when it is triggered, LP tokens already sent to the receiver do not have special redeeming handling. Therefore, in case the Pause Proxy is the receiver and governance does not control it, the LP tokens can be lost or seized by a governance attack.

### FlapperUniV2SwapOnly

Exposes a `kick` operation to be triggered periodically. Its logic withdraws `DAI` from the `vow` and buys `gem` tokens on Uniswap v2. The acquired tokens are sent to a predefined `receiver` address.

Configurable Parameters:
* `hop` - Minimum seconds interval between kicks.
* `pip` - A reference price oracle, used for bounding the exchange rate of the swap.
* `want` - Relative multiplier of the reference price to insist on in the swap. For example, a value of 0.98 * `WAD` allows for a 2% worse price than the reference.

### FlapperMom

This contract allows bypassing the governance delay when disabling the Flapper in an emergency.

### OracleWrapper

Allows for scaling down an oracle price by a certain value. This can be useful when the `gem` is a redenominated version of an existing token, which already has a reliable oracle.

### Splitter

Exposes a `kick` operation to be triggered periodically. Its logic withdraws `DAI` from the `vow` and splits it in two parts. The first part (`burn`) is sent to the underlying `flapper` contract to be processed by the burn engine. The second part (`WAD - burn`) is distributed as reward to a `farm` contract. Note that the `kick` cadence is determined by `max(splitter.hop(), flapper.hop())`.

Configurable Parameters:
* `hop` - Minimum seconds interval between kicks.
* `flapper` - The underlying burner strategy (e.g. the address of `FlapperUniV2SwapOnly`).
* `burn` - The percentage of the `vow.bump` to be moved to the underlying `flapper`. For example, a value of 0.70 \* `WAD` corresponds to funneling 70% of the `DAI` to the burn engine. Note that `FlapperUniV2` and `FlapperUniV2SwapOnly` do not support very small `burn` values (for example `FlapperUniV2SwapOnly` requires `burn` to be at least `(RAD * 1000 * reserveDai) / (vow.bump() * 997 * (reserveMkr - 1)) + 1`).

### General Note:

* Availability and accounting of the withdrawn `DAI` is the responsibility of the `vow`. At the time of a `kick`, the `vow` is expected to hold at least the swapped amount (`vow.bump`) over the configured flapping threshold (`vow.hump`).
