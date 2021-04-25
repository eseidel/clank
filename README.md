# clank

An attempt a simulating the rules of one of my wife's favorite games: Clank!

https://www.direwolfdigital.com/clank/


## Getting Started

```
dart run bin/simulate.dart
```

## Missing Features
* Market (including backpacks to carry more)
* Missing "deep" half of map.

## Issues
* Most games end w/o escape since random planning just walks around.
* Some secrets are incorrectly handled:
https://boardgamegeek.com/thread/1740275/article/25266676#25266676
* Secret Skill boost is supposed to be immediate (not held onto)
* Secret Gold gain should be immediate.
* Secret draw should be immediate.

## Missing Features/Cards

### Effect Ordering / Additive Effects
* Swagger 2x
* Search 2x

## Designer Notes

* FAQ (2019) Says "slight of hand" as last card doesn't generate drawing.
https://d19y2ttatozxjp.cloudfront.net/assets/clank/Clank_FAQ.pdf

* You don't "make clank" if you can't push cubes:
https://boardgamegeek.com/thread/1668384/article/24171648#24171648

* Magic Spring happens the turn it was found and is manditory:
https://boardgamegeek.com/thread/1656181/article/23992755#23992755

## Edge Case Questions
* Does Treasure Hunter dungeon row replacement cause arrival effects?
* What does treasure hunter do if the dungeon row is empty? (nothing I think?)
* How does Trashing interact with reshuffling?  When does the "choose card" happen?
* Does Gem Collector give refunds (for gems purchased that turn)?

