# clank

An attempt a simulating the rules of one of my wife's favorite games: Clank!

https://www.direwolfdigital.com/clank/


## Getting Started

```
dart run bin/simulate.dart
```

## Issues
* Most games end w/o escape since random planning just wanders randomly.


## Possible future improvements
* Cubes/Tokens could be modeled with single objects and then just an enum to
  indicate where the Cube is.
* Backside of the board could be added.  Probably just pull it from
  kevinkey/klank yaml though since they seem to have a good transcription.


## Edge Case Questions
* Does Treasure Hunter dungeon row replacement cause arrival effects?
  Currently implemented to cause arrival effects.
* Does the initial dungeon row deal cause arrival effects?
  Currently implemented to do so (e.g. can add clank).
* What does treasure hunter do if the dungeon row is empty? (nothing I think?)
  Currently implemented to do nothing.
* How does Trashing interact with reshuffling?  When does the "choose card" happen?
  For example if you pick a card type and then reshuffle discard (but don't
  draw the reshuffled card) can you still trash it?  Currently we ignore the "trash".
* Does Gem Collector give refunds (for gems purchased that turn)?
  Currently does not issue refunds.
* Should Swagger be sensitive to play order (not give skill with -clank)?
  Currently implemented to be sensitive to play order.
* Monkey Idols are not secrets and thus can't be grabbed by Wand of Wind, right?
  Currently does not allow grabbing Monkey Idols.
