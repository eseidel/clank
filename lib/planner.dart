// This shouldn't really import clank.dart since this likely ends up as a
// client-side file where as clank.dart will be server side?
import 'dart:collection';
import 'dart:math';

import 'clank.dart';
import 'graph.dart';
import 'cards.dart';

// Responsible for making decisions, asynchronous, not trust-worthy.
abstract class Planner {
  Future<Action> nextAction(Turn turn, Board board);
}

class Action {}

class PlayCard extends Action {
  final CardType cardType;
  PlayCard(this.cardType);
}

class Traverse extends Action {
  final Edge edge;
  final bool takeItem;
  final int spendHealth;
  Traverse({required this.edge, required this.takeItem, this.spendHealth = 0}) {
    assert(spendHealth >= 0);
    assert(spendHealth <= edge.swordsCost);
    assert(!takeItem || edge.end.loot.isNotEmpty);
  }
}

class Purchase extends Action {
  final CardType cardType;
  Purchase({required this.cardType}) {
    assert(cardType.skillCost > 0);
    assert(cardType.swordsCost == 0);
  }
}

class Fight extends Action {
  final CardType cardType;
  Fight({required this.cardType}) {
    assert(cardType.skillCost == 0);
    assert(cardType.swordsCost > 0);
  }
}

class UseDevice extends Action {
  final CardType cardType;
  UseDevice({required this.cardType}) {
    assert(cardType.skillCost > 0);
    assert(cardType.swordsCost == 0);
  }
}

class EndTurn extends Action {}

// Planner can't modify turn directly?
class Turn {
  final Player player;
  int skill = 0;
  int boots = 0;
  int swords = 0;
  int leftoverClankReduction = 0; // always negative
  Turn({required this.player});

  List<Card> get hand => player.deck.hand;

  bool usingTeleporter = false;
  bool hasKey = false;

  void addUseEffectsFromCard(CardType cardType) {
    skill += cardType.skill;
    boots += cardType.boots;
    swords += cardType.swords;
  }
  // Player, starting location, other state?
  // Current resources

  // Does this belong on board instead?
  int adjustClank(Board board, int desired) {
    // You can't ever have both negative accumulated and a positive clank area.
    assert(leftoverClankReduction == 0 ||
        board.clankArea.countFor(player.color) == 0);
    // lefover zero, desired neg ->  apply, letting leftover to remainder.
    // leftover neg, desired neg  -> just update leftover
    // leftover neg, desired pos  -> reduce leftover, reduce desired, apply
    int actual = 0;
    if (leftoverClankReduction == 0) {
      actual = board.adjustClank(player.color, desired);
      leftoverClankReduction = min(desired - actual, 0);
    } else {
      assert(leftoverClankReduction < 0);
      // First apply to to the leftovers.
      int reduced = desired + leftoverClankReduction;
      if (reduced <= 0) {
        leftoverClankReduction = reduced;
      } else {
        actual = board.adjustClank(player.color, reduced);
        leftoverClankReduction = min(reduced - actual, 0);
      }
    }
    return actual;
  }

  int hpAvailableForMonsterTraversals(Board board) {
    // We can't spend more cubes than we have or available health points.
    return min(board.playerCubeStashes.countFor(player.color),
        board.healthForPlayer(player.color) - 1);
  }

  @override
  String toString() {
    return '${skill}sk ${boots}b ${swords}sw -${leftoverClankReduction}c';
  }
}

bool cardUsableAtLocation(CardType cardType, Space location) {
  if (cardType.location == Location.crystalCave) {
    return location.isCrystalCave;
  }
  if (cardType.location == Location.deep) {
    return location.inDepths;
  }
  assert(cardType.location == Location.everywhere);
  return true;
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
  Future<Action> nextAction(Turn turn, Board board) async {
    if (_actions.isEmpty) {
      return EndTurn();
    }
    return _actions.removeFirst();
  }
}

class ActionGenerator {
  final Turn turn;
  final Board board;

  ActionGenerator(this.turn, this.board);

  Iterable<PlayCard> possibleCardPlays() {
    // TODO: This should only return each unique CardType once.
    return turn.hand.map((card) => PlayCard(card.type));
  }

  Iterable<Traverse> possibleMoves() sync* {
    int hpAvailableForTraversal = turn.hpAvailableForMonsterTraversals(board);
    bool haveResourcesFor(Edge edge) {
      if (edge.requiresArtifact && !turn.player.hasArtifact) return false;
      if (turn.usingTeleporter) return true;
      if (edge.requiresKey && !turn.hasKey) return false;
      if (edge.bootsCost > turn.boots) return false;
      if (edge.swordsCost > (turn.swords + hpAvailableForTraversal)) {
        return false;
      }
      return true;
    }

    Space current = turn.player.token.location!;
    for (var edge in current.edges) {
      if (!haveResourcesFor(edge)) {
        continue;
      }
      bool hasItem = edge.end.loot.isNotEmpty;
      bool takeItem = hasItem &&
          (edge.end.special != Special.artifact || turn.player.canTakeArtifact);

      // Yield one per possible distribution of health vs. swords spend.
      // For paths with zero swords this executes once with hpSpend = 0.
      int maxHpSpend = min(hpAvailableForTraversal, edge.swordsCost);
      int minHpSpend = max(edge.swordsCost - turn.swords, 0);
      for (int hpSpend = minHpSpend; hpSpend <= maxHpSpend; hpSpend++) {
        assert(hpSpend + turn.swords >= edge.swordsCost);
        yield Traverse(edge: edge, takeItem: takeItem, spendHealth: hpSpend);
      }
    }
  }

  Iterable<Action> possiblePurchases() sync* {
    bool canAffordPurchase(CardType cardType) {
      if (cardType.interaction != Interaction.buy) return false;
      if (cardType.skillCost > turn.skill) return false;
      return true;
    }

    bool canDefeat(CardType cardType) {
      if (cardType.interaction != Interaction.fight) return false;
      if (cardType.swordsCost > turn.swords) return false;
      return true;
    }

    bool canAffordDevice(CardType cardType) {
      if (cardType.interaction != Interaction.use) return false;
      if (cardType.skillCost > turn.skill) return false;
      return true;
    }

    for (var cardType in board.availableCardTypes) {
      if (!cardUsableAtLocation(cardType, turn.player.location)) {
        continue;
      }
      if (canAffordPurchase(cardType)) {
        yield Purchase(cardType: cardType);
      }
      if (canDefeat(cardType)) {
        yield Fight(cardType: cardType);
      }
      if (canAffordDevice(cardType)) {
        yield UseDevice(cardType: cardType);
      }
    }
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
  Future<Action> nextAction(Turn turn, Board board) async {
    ActionGenerator generator = ActionGenerator(turn, board);
    List<Action> possible = [];
    possible.addAll(generator.possibleCardPlays());
    // If cards in hand, play all those first?
    if (possible.isNotEmpty) {
      return possible.first;
    }
    possible.addAll(generator.possibleMoves());
    possible.addAll(generator.possiblePurchases());

    if (possible.isNotEmpty) {
      possible.shuffle(_random);
      return possible.first;
    }

    return EndTurn();
  }
}
