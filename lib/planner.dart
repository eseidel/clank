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

class Action {
  // Enum?
  // Play a card
  // Acquire a card (from dungeon row or reserve)
  // Use a Device
  // Fight a monster
  // If in Market, spend gold to buy an item.
  // Move through a tunnel
  //    When you move into a room with items you may take one.
}

class PlayCard extends Action {
  final Card card;
  PlayCard(this.card);
}

class Traverse extends Action {
  final Edge edge;
  bool takeItem;
  Traverse({required this.edge, required this.takeItem});
}

class Purchase extends Action {
  final CardType cardType;
  Purchase({required this.cardType}) {
    assert(cardType.swordsCost > 0 || cardType.skillCost > 0);
  }
}

class EndTurn extends Action {}

// Planner can't modify turn directly?
class Turn {
  final Player player;
  int skill = 0;
  int boots = 0;
  int swords = 0;
  int clank = 0;
  Turn({required this.player});

  List<Card> get hand => player.deck.hand;

  bool usingTeleporter = false;
  bool hasKey = false;

  void playCardIgnoringEffects(Card card) {
    player.deck.playCard(card);
    skill += card.skill;
    boots += card.boots;
    swords += card.swords;
    clank += card.clank;
  }
  // Player, starting location, other state?
  // Current resources

  @override
  String toString() {
    return '${skill}sk ${boots}b ${swords}sw ${clank}c';
  }
}

int scoreForPlayer(Player player) {
  // Value of artifacts
  // value from tokens
  // value from gold
  // value from cards
  return 0;
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

  Iterable<Traverse> possibleMoves(Turn turn) sync* {
    bool haveResourcesFor(Edge edge) {
      if (edge.requiresArtifact && !turn.player.hasArtifact) return false;
      if (turn.usingTeleporter) return true;
      if (edge.requiresKey && !turn.hasKey) return false;
      if (edge.bootsCost > turn.boots) return false;
      if (edge.swordsCost > turn.swords) return false;
      return true;
    }

    Space current = turn.player.token.location!;
    for (var edge in current.edges) {
      if (!haveResourcesFor(edge)) {
        continue;
      }
      // TODO: Yield versions which spend hp instead of swords.
      bool hasItem = edge.end.loot.isNotEmpty;
      bool takeItem = hasItem &&
          (edge.end.special != Special.artifact || turn.player.canTakeArtifact);
      yield Traverse(edge: edge, takeItem: takeItem);
    }
  }

  Iterable<Action> possiblePurchases(Turn turn, Board board) sync* {
    bool canPurchase(CardType cardType) {
      if (cardType.swordsCost > turn.swords) return false;
      if (cardType.skillCost > turn.skill) return false;
      return true;
    }

    for (var cardType in board.availableCardTypes) {
      if (canPurchase(cardType)) {
        yield Purchase(cardType: cardType);
      }
    }
  }

  @override
  Future<Action> nextAction(Turn turn, Board board) async {
    // If cards in hand, play all those?
    if (turn.hand.isNotEmpty) {
      return PlayCard(turn.hand.first);
    }

    List<Action> possibleActions = [];
    possibleActions.addAll(possibleMoves(turn));
    possibleActions.addAll(possiblePurchases(turn, board));

    if (possibleActions.isNotEmpty) {
      possibleActions.shuffle(_random);
      return possibleActions.first;
    }

    return EndTurn();
  }
}
