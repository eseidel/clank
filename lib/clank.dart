import 'dart:math';

import 'graph.dart';
import 'planner.dart';

enum PlayerStatus {
  inGame,
  escaped,
  knockedOut,
}

// Responsible for storing player data.  Synchronous, trusted.
class Player {
  Deck deck;
  PlayerStatus status = PlayerStatus.inGame;
  Planner planner;
  late PlayerToken token;

  List<Token> loot = [];
  Player({required this.planner, required this.deck});

  Space get location => token.location!;

  void takeLoot(Token token) {
    assert(!(Token is PlayerToken));
    assert(token.location != null);
    token.removeFromBoard();
    loot.add(token);
  }
}

class ClankGame {
  final List<Player> players;
  late Player activePlayer;
  late Board board;
  int? seed;
  final Random _random;
  bool isComplete = false;
  ClankGame({required List<Planner> playerConnections, this.seed})
      : players = playerConnections
            .map((connection) =>
                Player(planner: connection, deck: createStarterDeck()))
            .toList(),
        _random = Random(seed) {
    activePlayer = players.first;
    setup();
  }

  Player nextPlayer() {
    int index = players.indexOf(activePlayer);
    if (index == players.length - 1) return players.first;
    return players[index + 1];
  }

  void executeAction(Turn turn, Action action) {
    if (action is PlayCard) {
      turn.playCardIgnoringEffects(action.card);
      return;
    }
    if (action is EndTurn) {
      return;
    }
    if (action is Traverse) {
      Edge edge = action.edge;
      turn.boots -= edge.bootsCost;
      Player player = turn.player;
      player.token.moveTo(edge.end);
      // TODO: Other move-entry effects (like crystal cave).
      print('MoveTo: ${edge.end}');
      if (action.takeItem) {
        // What do we do when takeItem is a lie (there are no tokens)?
        player.takeLoot(player.location.loot.first);
      }
      // TODO: handle keys, exhaustion, etc.
      return;
    }
    assert(false);
  }

  void executeEndOfTurn(Turn turn) {
    // You must play all cards
    assert(turn.hand.isEmpty);
    activePlayer.deck.discardPlayAreaAndDrawNewHand(_random);
    // Refill the dungeon row
    // Perform dragon attacks as needed from dungeon row.
  }

  // This probably belongs outside of the game class.
  Future<void> takeTurn() async {
    final turn = Turn(player: activePlayer);
    // If the player is the first-out, perform countdown turn instead.
    // If the player is otherwise off board (dead, out), ignore the turn.
    Action action;
    do {
      action = await activePlayer.planner.nextAction(turn);
      // Never trust what comes back from a plan?
      executeAction(turn, action);
    } while (!(action is EndTurn));
    executeEndOfTurn(turn);
    isComplete = checkForEndOfGame();
    activePlayer = nextPlayer();
  }

  bool checkForEndOfGame() {
    // Once all players are out of the dungeon or knocked out the game ends.
    return players.any((player) => player.status == PlayerStatus.inGame);
  }

  static Deck createStarterDeck() {
    var library = Library();
    Deck deck = Deck();
    deck.addAll(List.generate(6, (_) => library.makeBurgle()));
    deck.addAll(List.generate(2, (_) => library.makeStumble()));
    deck.add(library.makeSidestep());
    deck.add(library.makeScramble());
    return deck;
  }

  void placeLootTokens() {
    // TODO: Implement placeLootTokens.
    // Artifacts (excluding randomly based on player count)
    // Minor Secrets
    // Major Secrets
    // Monkey Tokens
  }

  void setup() {
    // Each player is dealt a hand in the constructor currently.
    for (var player in players) {
      player.deck.discardPlayAreaAndDrawNewHand(_random);
    }
    // Build the board graph.
    board = Board();
    // Place all the players at the start.
    for (var player in players) {
      player.token = PlayerToken();
      player.token.moveTo(board.graph.start);
    }
    placeLootTokens();
    // Fill reserve.
    // Set Rage level
  }
}

// Labels for spaces derived from their visual position computed from the
// upper-level corner (where the start space is). Start space would be (-1, 0).
// class Coord {
//   final int row;
//   final int column;
//   Coord(this.row, this.column);
// }

class Board {
  Graph graph = FrontGraphBuilder().build();
  List<Card> reserve = [];
  List<Card> dungeonDiscard = [];
  List<Card> dungeonRow = [];

  Board();
}

class Deck {
  // First is the 'top' of the pile (next to draw).
  List<Card> drawPile = <Card>[];
  // First is first drawn.
  List<Card> hand = <Card>[];
  // First is first played.
  List<Card> playArea = <Card>[];
  // last is the 'top' (most recently discarded), but order doesn't matter.
  late List<Card> discardPile;

  Deck({List<Card>? cards}) {
    discardPile = cards ?? <Card>[];
  }

  int get cardCount => drawPile.length + hand.length + discardPile.length;

  void add(Card card) {
    discardPile.add(card);
  }

  void addAll(Iterable<Card> cards) {
    for (var card in cards) {
      discardPile.add(card);
    }
  }

  void playCard(Card card) {
    if (!hand.contains(card)) {
      throw ArgumentError("Hand does not contain $card. Can't discard it.");
    }
    hand.remove(card);
    playArea.add(card);
  }

  // void discard(Card card) {
  //   if (!hand.contains(card)) {
  //     throw ArgumentError('Hand does not contain $card. Can't discard it.');
  //   }
  //   hand.remove(card);
  //   discardPile.add(card);
  // }

  List<Card> discardPlayAreaAndDrawNewHand(Random random, [int count = 5]) {
    assert(hand.isEmpty);
    discardPile.addAll(playArea);
    playArea = [];
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

class Card {
  final String name;
  final int skill;
  final int boots;
  final int swords;
  final int clank;

  // You don't want to construct this const (you'll end up sharing instances)
  Card({
    this.name = '',
    this.skill = 0,
    this.boots = 0,
    this.swords = 0,
    this.clank = 0,
  });
}

class Library {
  // Starter cards
  Card makeBurgle() => Card(name: 'Burgle', skill: 1);
  Card makeScramble() => Card(name: 'Scramble', skill: 1, boots: 1);
  Card makeSidestep() => Card(name: 'Sidestep', boots: 1);
  Card makeStumble() => Card(name: 'Stumble', clank: 1);
}

// This could be an enum using one of the enum packages.
class Artifact {
  final String name;
  final int value;
  const Artifact._(this.name, this.value);

  factory Artifact.byValue(int desiredValue) {
    return all.firstWhere((artifact) => artifact.value == desiredValue);
  }

  static List<Artifact> all = [
    const Artifact._('Ring', 5),
    const Artifact._('Ankh', 7),
    const Artifact._('Vase', 10),
    const Artifact._('Bananas', 15),
    const Artifact._('Shield', 20),
    const Artifact._('Chestplate', 25),
    const Artifact._('Thurible', 30),
  ];
}

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
