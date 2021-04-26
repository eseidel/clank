# clank

An attempt a simulating the rules of one of my wife's favorite games: Clank!

https://www.direwolfdigital.com/clank/


## Getting Started

```
dart run bin/simulate.dart
```

## Missing Features
* Market (including backpacks to carry more)

## Issues
* Most games end w/o escape since random planning just walks around.
* Occasional trash exception:
Unhandled exception:
Invalid argument(s): Cannot trash cardType Burgle not found in discard or play area.
#0      Player.trashCardOfType (package:clank/clank.dart:104:5)
#1      TrashCard.execute (package:clank/clank.dart:342:17)
#2      ClankGame.executeEndOfTurnEffects (package:clank/clank.dart:835:14)
#3      ClankGame.executeEndOfTurn (package:clank/clank.dart:860:5)
#4      ClankGame.takeTurn (package:clank/clank.dart:799:5)
<asynchronous suspension>
#5      main (bin/simulate.dart:8:5)

## Edge Case Questions
* Does Treasure Hunter dungeon row replacement cause arrival effects?
* What does treasure hunter do if the dungeon row is empty? (nothing I think?)
* How does Trashing interact with reshuffling?  When does the "choose card" happen?
  For example if you pick a card type and then reshuffle discard (but don't
  draw the reshuffled card) can you still trash it?  (currently we crash)
* Does Gem Collector give refunds (for gems purchased that turn)?
* Should Swagger be sensitive to play order (not give skill with -clank)?

