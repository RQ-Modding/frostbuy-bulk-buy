# Testing Frostbuy Bulk Buy

For people and agents who test the mod in the game. Read it before you use anything the mod adds.
Assume nothing about the mod when it is not installed: check `logs\rqmod.log` for
`Loading frostbuy-bulk-buy` and `Frostbuy Bulk Buy loaded`.

## What it adds

All on the screen `shop-buy` (Frostbuy's rack window), as kit controls (section `kit`):

- `button-bulk-buy-tile`: the BULK BUY tile (945, 488). Turns bulk mode on and off.
- In bulk mode:
  - `row-bulk-list-N`: the list's rows, N from 1 in the list's order (the scroll keeps N). A click
    ticks or unticks the row; `selected` is the tick. The value is the item instance on sale.
  - `filter-bulk-*` (special, weapon, armor, item, the classes, the sub-filters) and
    `tab-bulk-sort-*`: the list's filters and sort, as the vault's.
  - `button-bulk-all` (Select all) and `button-bulk-none` (Clear): every row the list shows.
  - The cart, per line (`<no>` is the item number): `stepper-n-<no>` (value: how many),
    `button-n-<no>-dec`, `-inc` and `-max`; `item-bulk-icon-<no>`.
  - `scrollbar-bulk-cart-bar`, `button-bulk-buy` (BUY: off when the cart is empty or costs more than
    the money), `button-bulk-empty` (EMPTY CART).
- BUY opens the game's dialog (screen `select`, `yes` / `no`); a notice after it when not everything
  was bought, with the reason another mod gave (`rq.shop.on_can_buy`) when one refused a copy.
- While a mod's scene plays over the shop (`rq.scene.active()`), the tile and bulk mode's widgets are
  not drawn and not listed; they come back as they were at its end.

While bulk mode is on, the kit takes the mouse: every game control is listed `covered`, and
`rqmod-ctl press` refuses them. Leave bulk mode first (the tile, `key esc`, or a right click). A
player's mouse over the window's × (the game's `close`) still reaches it, and closing the window
empties the cart.

## How to check it

1. Open Frostbuy, then a rack. Press the tile: Frostbuy says "Buyin' in bulk, Boss?", the list has
   tick boxes and the cart is on the left.
2. Tick a weapon whose name ends in ① to ⑧ and press `+` a few times: the cart shows the copies'
   levels going up, and the line's price is their sum.
3. Raise the money (`rq.ain.call("所持金_設定", n)`) and press MAX: it stops at what the money pays
   for, or 99.
4. BUY, Yes: the vault holds the copies (names ① higher each, prices as the cart said), the money
   went down by TOTAL, the cart is empty, and the next copy is on sale.
5. Set the money low: SHORT BY in red, BUY off.
6. Skill Again (306) or a Character Ticket: one at a time (MAX does nothing past 1).

## Forcing it for a test

`rq.mod.get("frostbuy-bulk-buy")` returns `state()` (the mod's table: `on`, `cart` with each line's
`no`, `n`, `max`, `copies`; `busy` while BUY runs) and `totals()` (the cart's sum and pieces). Work
on a copy of the save: BUY spends real money.

## Test Lab

`bulk-buy`: the loader's calls (rq.shop.restocks, restock, next, rq.item.buy's on_buy, the stepper's
MAX, marked rows), then, with this mod installed, the tile, a tick, four copies of a weapon bought in
one BUY (levels, prices, money), short of money, Esc and closing the window.
