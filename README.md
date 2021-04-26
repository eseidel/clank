# clank

An attempt a simulating the rules of one of my wife's favorite games: Clank!

https://www.direwolfdigital.com/clank/


## Getting Started

```
dart run bin/simulate.dart
```

## Issues
* Most games end w/o escape since random planning just wanders randomly.


## Edge Case Questions
* Does Treasure Hunter dungeon row replacement cause arrival effects?
* What does treasure hunter do if the dungeon row is empty? (nothing I think?)
* How does Trashing interact with reshuffling?  When does the "choose card" happen?
  For example if you pick a card type and then reshuffle discard (but don't
  draw the reshuffled card) can you still trash it?  Currently we ignore the "trash".
* Does Gem Collector give refunds (for gems purchased that turn)?
* Should Swagger be sensitive to play order (not give skill with -clank)?

