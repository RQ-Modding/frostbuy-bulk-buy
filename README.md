# Frostbuy Bulk Buy

Buy many items at Frostbuy at once: tick them, say how many, and pay once.

## Showcase

### Bulk Buy Button

<img width="610" height="297" alt="image" src="https://github.com/user-attachments/assets/2c9bd7a0-1455-4890-b36c-92adc90298fc" />

### Bulk Buy Screen

<img width="1267" height="961" alt="image" src="https://github.com/user-attachments/assets/3c740cbe-acc6-40fb-bd35-956006db0d2f" />

### Items in the Cart

<img width="1263" height="921" alt="image" src="https://github.com/user-attachments/assets/2a74d733-d866-4d4b-b58a-ed6d81c5dd63" />

## What it changes

- **BULK BUY**, a tile in the right column of Frostbuy's rack window, turns bulk mode on and off.
- **In bulk mode** the list gets tick boxes. Click a row to tick it, again to untick it. The filters
  on the right show the other racks, so one cart can hold items from all of them. **Select all** and
  **Clear** tick and untick every row the list shows.
- **The cart** takes Frostbuy's place on the left. Each line has the item, its price, and how many:
  `-`, `+`, a number you can type, and **MAX** (as many as your money pays for, up to 99). Setting a
  line to 0 takes it out of the cart.
- **More than one copy** of an item the shop puts back on sale on every visit: most weapons and armor,
  the special items that keep coming back, the Capture Rope, Forbidden Talent in the third world.
  Items the shop sells only once, or only while you own none (Skill Again, the Character Ticket and
  the like), are one at a time, as in the game.
- **Weapons and armor go up a level with each copy**, exactly as leaving and entering the shop makes
  them: ① ② ③ … up to ⑨, at the game's prices. The cart shows each copy's level.
- **BUY** asks once, in the game's dialog ("Purchase 32 items for 1,580,940 Gold?"), and puts
  everything in the vault. BUY is off, and the sums are red, while the cart costs more than you have.
- Esc, a right click or the tile leaves bulk mode; the cart stays until you close the rack window.
  The window's × still closes it.

Items of other mods are one at a time, unless that mod puts another on sale as soon as one is
bought (Aten Gnu QoL's Box of Books does): then the cart lets you take more after the first.

## Keys and settings

Esc or a right click leaves bulk mode. No settings.

## Saves

Nothing is kept. What you buy is the game's own purchase: the same items, money and Gold spent.

## Install

Needs [RQ MOD](https://github.com/RQ-Modding/RQ-Mod) with loader **2.50.0** or newer. Extract the
release zip into the game's `mods` folder, so that you have `mods/frostbuy-bulk-buy/mod.json`.

## How it works

- The list and the cart are `rq.uikit` widgets over the game's window: `item_picker` with `marks`
  (the ticks), the small `stepper` with MAX, `item_icon`, `scrollbar`, `rack` for the tile.
- The shop's rules and prices come from `rq.shop.restocks` and `rq.shop.next` (the copies the next
  visits would put on sale, read from the game's own item creation); each purchase is
  `rq.item.buy`, then `rq.shop.restock` puts the next copy on sale as the next visit would.
- Frostbuy's balloon: `T_ShopMessage@set` through `rq.ain.method`.

## License

MIT, see [LICENSE](LICENSE).
