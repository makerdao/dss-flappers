# Dss Flappers

Implementations of MakerDao surplus auctions, triggered on `vow.flap`. The current featured Flapper is `FlapperUniV2`.

### FlapperUniV2

Exposes a `kick` operation to be triggered periodically. Its logic withdraws `DAI` from the `vow` and buys `gem` tokens on Uniswap v2. The acquired tokens, along with a proportional amount of additional `DAI` withdrawn from the `vow`, are deposited back into the liquidity pool. Finally, the minted LP tokens are sent to a predefined `receiver` address.

Configurable Parameters:
* `hop` - Minimum seconds interval between kicks.
* `pip` - A reference price oracle, used for bounding the exchange rate of the swap.
* `want` - Relative multiplier of the reference price to insist on in the swap. For example, a value of 0.98 * `WAD` allows for a 2% worse price than the reference.

#### Notes:

* As a `kick` operation also withdraws `DAI` for depositing in the pool (and not only for swapping), it can in practice reduce the Surplus Buffer to below `vow.bump`.

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

### General Note:

* Availability and accounting of the withdrawn `DAI` is the responsibility of the `vow`. At the time of a `kick`, the `vow` is expected to hold at least the swapped amount (`vow.bump`) over the configured flapping threshold (`vow.hump`).
