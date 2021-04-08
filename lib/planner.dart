// This shouldn't really import clank.dart since this likely ends up as a
// client-side file where as clank.dart will be server side?
import 'dart:math';

import 'clank.dart';
import 'graph.dart';

// Responsible for making decisions, asynchronous, not trust-worthy.
abstract class Planner {
  Future<Action> nextAction(Turn turn);
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

class RandomPlanner implements Planner {
  int? seed;
  Random _random;
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

  List<Edge> affordableEdges(Turn turn) {
    bool haveResourcesFor(Edge edge) {
      if (turn.usingTeleporter) return true;
      if (edge.requiresKey && !turn.hasKey) return false;
      if (edge.bootsCost < turn.boots) return false;
      if (edge.swordsCost < turn.swords) return false;
      return true;
    }

    Space current = turn.player.token.location!;
    return current.edges.where(haveResourcesFor).toList();
  }

  @override
  Future<Action> nextAction(Turn turn) async {
    // If cards in hand, play all those?
    if (turn.hand.isNotEmpty) {
      return PlayCard(turn.hand.first);
    }
    // Look at all possible moves.  Pick one at random.
    List<Edge> possibleMoves = affordableEdges(turn);
    if (possibleMoves.isNotEmpty) {
      possibleMoves.shuffle(_random);
      Edge edge = possibleMoves.first;
      // Does this need to specify which item?
      return Traverse(edge: edge, takeItem: edge.end.loot.isNotEmpty);
    }

    return EndTurn();
  }
}
