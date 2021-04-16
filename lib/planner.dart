// This shouldn't really import clank.dart since this likely ends up as a
// client-side file where as clank.dart will be server side?
import 'dart:collection';
import 'dart:math';

import 'actions.dart';

// Responsible for making decisions, asynchronous, not trust-worthy.
abstract class Planner {
  Future<Action> nextAction(ActionGenerator generator);
}

// Distance between two points is a multi-variable result
// Minimum Turns (exhaustions)
// Boots
// Swords
// Keys?

class MockPlanner implements Planner {
  final Queue<Action> _actions;
  MockPlanner({List<Action> actions = const []})
      : _actions = Queue.from(actions);

  @override
  Future<Action> nextAction(ActionGenerator generator) async {
    if (_actions.isEmpty) {
      return EndTurn();
    }
    return _actions.removeFirst();
  }
}

class RandomPlanner implements Planner {
  int? seed;
  final Random _random;
  RandomPlanner({this.seed}) : _random = Random(seed);
  // Evaluating board states?
  // Clank tokens
  // Dragon position
  // Distance to entrance
  // Distance to artifact(s)
  // Current score?
  //
  // Simplest proxy for board state?
  // Current expected score = current score + likelyhood of not being zero?
  // Expected Score ==

  @override
  Future<Action> nextAction(ActionGenerator generator) async {
    List<Action> possible = [];
    possible.addAll(generator.possibleCardPlays());
    // If cards in hand, play all those first?
    if (possible.isNotEmpty) {
      return possible.first;
    }
    possible.addAll(generator.possibleMoves());
    possible.addAll(generator.possibleCardAcquisitions());
    possible.addAll(generator.possibleItemUses());
    possible.addAll(generator.possibleQueuedEffects());

    if (possible.isNotEmpty) {
      possible.shuffle(_random);
      return possible.first;
    }

    return EndTurn();
  }
}
