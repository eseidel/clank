# clank

An attempt a simulating the rules of one of my wife's favorite games: Clank!

https://www.direwolfdigital.com/clank/


## Getting Started

```
dart run bin/simulate.dart
```

## Missing Features
* Crystal Cave exhaustion
* Market
* Various card effects (trashing, teleport, etc.)
* Missing "deep" half of map.

## Issues
* Most games end w/o escape since random planning just walks around.

## Missing Features/Cards

### Traverse Effects
Flying Carpet
Dead Run

### Or Effects
Wand of Wind (Also teleport)
Underworld Dealing
Mister Whiskers
Apothecary
Dragon Shrine (and trash)
Shrine

### Choose Card / Discard effects
Sleight of Hand
Treasure Hunter
Master Burglar (Not really any choice, just a limited Magic Spring?)

### Conditional effects
Gem Collector // Do you get a refund for previously purchased gems?

### Effect Ordering / Additive Effects
Swagger
Search

## Designer Notes
FAQ (2019):

Says "slight of hand" as last card doesn't generate drawing.
https://d19y2ttatozxjp.cloudfront.net/assets/clank/Clank_FAQ.pdf

You don't "make clank" if you can't push cubes:
https://boardgamegeek.com/thread/1668384/article/24171648#24171648

Entering a crystal marks you as exhausted even if you teleport in/out
https://boardgamegeek.com/thread/1671635/article/25115569#25115569

Magic Spring happens the turn it was found and is manditory:
https://boardgamegeek.com/thread/1656181/article/23992755#23992755
