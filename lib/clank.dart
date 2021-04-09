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

  bool get hasArtifact => loot.any((token) => token is ArtifactToken);

  void updateStatus(Space goal) {
    if (location == goal && hasArtifact) {
      status = PlayerStatus.escaped;
    }
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

  void executeTraverse(Turn turn, Traverse action) {
    Edge edge = action.edge;
    turn.boots -= edge.bootsCost;
    assert(turn.boots >= 0);
    // TODO: This does not consider spending health instead of swords.
    turn.swords -= edge.swordsCost;
    assert(turn.swords >= 0);

    Player player = turn.player;
    player.token.moveTo(edge.end);
    // TODO: Other move-entry effects (like crystal cave).
    //print('MoveTo: ${edge.end}');
    if (action.takeItem) {
      // What do we do when takeItem is a lie (there are no tokens)?
      var loot = player.location.loot.first;
      print('Take loot: $loot');
      player.takeLoot(loot);
    }
    // TODO: handle keys, exhaustion, etc.
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
      executeTraverse(turn, action);
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
      //print(turn);
    } while (!(action is EndTurn));
    executeEndOfTurn(turn);
    activePlayer.updateStatus(board.graph.start);
    isComplete = checkForEndOfGame();
    activePlayer = nextPlayer();
  }

  bool checkForEndOfGame() {
    // Once all players are out of the dungeon or knocked out the game ends.
    return !players.any((player) => player.status == PlayerStatus.inGame);
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
    List<Space> spacesWithSpecial(Special special) {
      return board.graph.allSpaces
          .where((space) => space.special == special)
          .toList();
    }

    // TODO: Implement placeLootTokens.
    // Artifacts (excluding randomly based on player count)
    var artifactSpaces = spacesWithSpecial(Special.artifact);
    for (var space in artifactSpaces) {
      var artifact = Artifact.byValue(space.expectedArtifactValue);
      var token = ArtifactToken(artifact);
      token.moveTo(space);
    }
    // // Minor Secrets
    // var minorSecretSpaces = spacesWithSpecial(Special.minorSecret);
    // // Major Secrets
    // var majorSecretSpaces = spacesWithSpecial(Special.majorSecret);
    // // Monkey Tokens
    // var monkeyTokenSpaces = spacesWithSpecial(Special.monkeyShrine);
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

enum MinorSecret {
  potionOfHealing,
  potionOfSwiftness,
  potionOfStrength,
  skillBoost,
  treasure,
  magicSpring,
  dragonEgg,
}

enum MajorSecret {
  potionOfGreaterHealing,
  greaterSkillBoost,
  greaterTreasure,
  flashOfBrilliance,
  challice,
}

class Box {
  // 7 Artifacts
  // 11 major secrets
  // - 3 challice (7 pts)
  // - 2 2x heart bottles
  // - 2 5 gold
  // - 2 5 skill
  // - 2 flash of brilliance (draw 3)
  // 18 minor secrets
  // - 3 dragon egg (3 points)
  // - 3 heal 1
  // - 3 2 gold
  // - 3 2 skill
  // - 2 2 swords
  // - 2 trash card (at end of turn)
  // - 2 1 boot
  // 2 master keys
  // 2 backpacks
  // 3 crowns
  // 3 monkey idols
  // 4 mastery tokens
  // Gold (81 total)
  // Gold is meant to be unlimited: https://boardgamegeek.com/thread/1729908/article/25115604#25115604
  // - 12 5 gold
  // - 21 1 gold
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
  List<int> clankArea = [];
  List<int> dragonBag = [];

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

  @override
  String toString() => name;
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

class ArtifactToken extends Token {
  Artifact artifact;
  ArtifactToken(this.artifact);
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
