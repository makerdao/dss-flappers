# Dss Flappers

Implementantions of MakerDao surplus auctions. The current featured Flapper is `FlapperUniV2`.

### FlapperUniV2

Exposes a `kick` operation to be triggered periodically. Its logic draws `DAI` from the `msg.sender` and buys `gem` tokens on Uniswap v2. The acquired tokens, along with a proportional amount of additional `DAI` drawn from the `msg.sender`, are deposited back into the liquidity pool. Finally, the minted LP tokens are sent to a predefined `receiver` address.

Configurable Parameters:
* `hop` - Minimum seconds interval between kicks.
* `pip` - A reference price oracle, used for bounding the exchange rate of the swap.
* `want` - Relative multiplier of the reference price to insist on in the swap. For example, a value of 0.98 * `WAD` allows for a 2% worse price than the reference.

### FlapperMom

This contract allows bypassing the governance delay when disabling the Flapper in an emergency.

### OracleWrapper

Allows for scaling down an oracle price by a certain value. This can be useful when the `gem` is a redenominated version of an existing token, which already has a reliable oracle.

### Notes:

* The swapped amount (`lot`, or `vow.bump` in case the `vow` is the `msg.sender`) is received in 10^45 (`RAD`) resolution, and must be a multiple of 10^27 (`RAY`).

* Availability and accounting of the drawn `DAI` is the responsibility of the `msg.sender`. In case that is the `vow`, at the time of a `kick`, it is expected to only hold the swapped amount (`lot`, or `vow.bump`) over the configured flapping threshold (`vow.hump`). As a `kick` operation also draws `DAI` for depositing in the pool (and not only for swapping), it can in practice reduce the Surplus Buffer to below that threshold.

* Although the Flapper interface is conformant with the Emergency Shutdown procedure and will stop operating when it is triggered, LP tokens already sent to the receiver do not have special redeeming handling.

