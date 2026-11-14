# Changelog

Each section is a version of the mod, the `version` in `mod.json`. The release workflow copies the
section of a tagged version into the release notes.

## 1.0.1

- The tile and the cart hide while a mod's scene plays over the shop (Pluepet Rare Contract's
  purchase); they come back as they were.
- A purchase another mod refuses (`rq.shop.on_can_buy`) stops the cart with that mod's reason.
- Needs loader 2.50.0.

## 1.0.0

First version.
- BULK BUY in Frostbuy's rack window: tick items from every rack, set how many of each in a cart,
  buy the cart with one question.
- Up to 99 of an item the shop puts back on sale on every visit; weapons and armor go up a level with
  each copy, at the game's prices.
- MAX stops at what the money pays for; BUY is off while the cart costs more than the money.
