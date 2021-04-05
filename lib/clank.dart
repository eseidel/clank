import 'dart:math';

class Planner {}

class ClankGame {
  final List<Planner> planners;
  bool isComplete = false;
  ClankGame({required this.planners});

  void takeTurn() {
    isComplete = true;
  }

  void setup() {}
}

// class Turn {
//   // Player id?
//   List<Card> cardsPlayed;
//   int clank;
//   int boots;
//   int skill;
//   int
// }

class Deck {
  // First is the "top" of the pile (next to draw).
  List<Card> drawPile = <Card>[];
  // First is first drawn.
  List<Card> hand = <Card>[];
  // last is the "top" (most recently discarded), but order doesn't matter.
  late List<Card> discardPile;

  Deck({List<Card>? cards}) {
    discardPile = cards ?? <Card>[];
  }

  int get cardCount => drawPile.length + hand.length + discardPile.length;

  void add(Card card) {
    discardPile.add(card);
  }

  void addAll(Iterable<Card> cards) {
    for (var card in cards) discardPile.add(card);
  }

  void discard(Card card) {
    if (!hand.contains(card)) {
      throw ArgumentError("Hand does not contain $card. Can't discard it.");
    }
    discardPile.add(card);
  }

  List<Card> drawNewHand(Random random, int count) {
    discardPile.addAll(hand);
    hand = [];
    if (drawPile.length < count) {
      drawPile = discardPile;
      discardPile = [];
      drawPile.shuffle(random);
    }
    if (count > drawPile.length) {
      throw ArgumentError(
          "Can't draw $count cards, only ${drawPile.length} in deck!");
    }
    hand = drawPile.take(count).toList();
    drawPile = drawPile.sublist(count); // take() doens't actually remove.
    return hand;
  }
}

class Card {}

// Dungeon Row
// Reserve
// Dungeon Discard Pile
//
// Player
// - Discard Pile
// - Gold
//
// Turn
// - Player Resources (Skill, Swords, Boots)
// - Clank Change (positive or negative)
//
//
// Cards
// - Burgle
// - Stumble
// - Sidestep
// - Scramble
// - Monsters
//
// Tokens
// - Artifact
// - Major Secret
// - Minor Secret
// - Market Item
// - Monkey Idol
// - Mastery token
// - Gold
//
//
// Dragon Rage
//
// Clank
// - Dragon Cubes
// - Player Cubes
//
//
// Reserve
// - Goblin (Monster)
// - Mercenery
// - Explore
// - Secret Tome
//
//
