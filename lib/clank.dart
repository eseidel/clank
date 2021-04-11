import 'dart:math';

import 'package:clank/cards.dart';

import 'graph.dart';
import 'planner.dart';

enum PlayerStatus {
  inGame,
  escaped,
  knockedOut,
}

// Responsible for storing player data.  Synchronous, trusted.
class Player {
  PlayerDeck deck;
  PlayerStatus status = PlayerStatus.inGame;
  Planner planner;
  late PlayerToken token;
  late PlayerColor color;

  int gold = 0;
  List<LootToken> loot = [];
  Player({required this.planner, required this.deck});

  Space get location => token.location!;

  void takeLoot(LootToken token) {
    assert(token.location != null);
    token.removeFromBoard();
    loot.add(token);
  }

  bool get hasArtifact => loot.any((token) => token is ArtifactToken);
  bool get inGame => status == PlayerStatus.inGame;

  bool get canTakeArtifact {
    int artifactCount =
        loot.fold(0, (sum, token) => (token is ArtifactToken) ? 1 : 0);
    // Allow more artifacts with backpacks.
    int maxArtifacts = 1;
    return artifactCount < maxArtifacts;
  }

  bool updateStatus(Board board) {
    // Don't ever change status once we set it, it's used for mastery token
    // score bonus caculation, etc.
    if (!inGame) {
      return false;
    }
    if (location == board.graph.start && hasArtifact) {
      status = PlayerStatus.escaped;
      print('$this escaped!');
      return true;
    }
    if (board.healthForPlayer(color) <= 0) {
      status = PlayerStatus.knockedOut;
      print('$this was knocked out!');
      return true;
    }
    return false;
  }

  int calculateTotalPoints() {
    int total = 0;
    total += deck.calculateTotalPoints();
    total += loot.fold(0, (sum, loot) => sum + loot.points);
    total += gold;
    // Mastery token bonus for escaping.
    total += status == PlayerStatus.escaped ? 20 : 0;
    return total;
  }

  @override
  String toString() => '${colorToString(color)}';
}

class ClankGame {
  final List<Player> players;
  late Player activePlayer;
  late Board board;
  int? seed;
  final Random _random;
  bool isComplete = false;
  Player? playerFirstOut;
  int countdownTrackIndex = 0;

  ClankGame({required List<Planner> planners, this.seed})
      : players = planners
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
    // print('$player moved: ${edge.end}');
    if (action.takeItem) {
      assert(player.location.loot.isNotEmpty);
      // What do we do when takeItem is a lie (there are no tokens)?
      Token token = player.location.loot.first;
      assert(token is LootToken);
      LootToken loot = token as LootToken;
      assert(!(loot is Artifact) || player.canTakeArtifact);
      print('$player loots $loot');
      player.takeLoot(loot);
    }
    // TODO: handle keys, exhaustion, etc.
  }

  void executePurchase(Turn turn, Purchase action) {
    CardType cardType = action.cardType;
    turn.skill -= cardType.skillCost;
    assert(turn.skill >= 0);
    // Should fighting be handled as a separate action?
    turn.swords -= cardType.swordsCost;
    assert(turn.swords >= 0);

    Card card = board.purchaseCard(cardType);
    turn.player.deck.add(card);
    print('${turn.player} buys $card');
  }

  void executeCardClank(Turn turn, CardType card) {
    int actualAdjustment = board.adjustClank(activePlayer.color, card.clank);
    if (actualAdjustment != card.clank) {
      assert(card.clank.isNegative ||
          board.playerCubeStashes.countFor(turn.player.color) == 0);
      turn.leftoverClankReduction += actualAdjustment - card.clank;
    }
  }

  void executeAction(Turn turn, Action action) {
    if (action is PlayCard) {
      turn.playCardIgnoringEffects(action.card);
      if (action.card.clank != 0) {
        executeCardClank(turn, action.card.type);
      }
      return;
    }
    if (action is EndTurn) {
      return;
    }
    if (action is Traverse) {
      executeTraverse(turn, action);
      return;
    }
    if (action is Purchase) {
      executePurchase(turn, action);
      return;
    }
    assert(false);
  }

  void executeEndOfTurn(Turn turn) {
    // You must play all cards
    assert(turn.hand.isEmpty);
    activePlayer.deck.discardPlayAreaAndDrawNewHand(_random);
    // Refill the dungeon row
    bool dragonAttacks = board.refillDungeonRow();
    // Perform dragon attacks as needed from dungeon row.
    if (dragonAttacks) {
      board.dragonAttack(_random);
    }
  }

  void moveCountdownTrack() {
    countdownTrackIndex++;
    if (countdownTrackIndex >= 4) {
      // Knock out any remaining players.
      for (var player in players) {
        board.takeDamage(player.color, Board.playerMaxHealth);
        player.updateStatus(board);
      }
      isComplete = true;
      return;
    }
    int additionalCubes = [0, 1, 2, 3][countdownTrackIndex];
    board.dragonAttack(_random, additionalCubes: additionalCubes);
  }

  bool updatePlayerStatuses() {
    bool changedStatus = false;
    for (var player in players) {
      changedStatus |= player.updateStatus(board);
    }
    return changedStatus;
  }

  // This probably belongs outside of the game class.
  Future<void> takeTurn() async {
    final turn = Turn(player: activePlayer);
    // If the player is the first-out, perform countdown turn instead.
    if (activePlayer == playerFirstOut) {
      moveCountdownTrack();
      return;
    }
    // If the player is otherwise off board (dead, out), ignore the turn.
    if (activePlayer.status != PlayerStatus.inGame) {
      return;
    }
    Action action;
    do {
      action = await activePlayer.planner.nextAction(turn, board);
      // Never trust what comes back from a plan?
      executeAction(turn, action);
      //print(turn);
    } while (!(action is EndTurn));
    executeEndOfTurn(turn);
    bool statusChanged = updatePlayerStatuses();
    // If players changed status, start countdown track!
    if (playerFirstOut == null && statusChanged) {
      playerFirstOut =
          players.firstWhere((player) => player.status != PlayerStatus.inGame);
    }
    isComplete = checkForEndOfGame();
    activePlayer = nextPlayer();
  }

  bool checkForEndOfGame() {
    // Once all players are out of the dungeon or knocked out the game ends.
    return !players.any((player) => player.status == PlayerStatus.inGame);
  }

  static PlayerDeck createStarterDeck() {
    var library = Library();
    PlayerDeck deck = PlayerDeck();
    deck.addAll(library.make('Burgle', 6));
    deck.addAll(library.make('Stumble', 2));
    deck.addAll(library.make('Sidestep', 1));
    deck.addAll(library.make('Scramble', 1));
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
    // Hack to assign colors for now.  Planners should choose?
    for (var color in PlayerColor.values) {
      if (color.index < players.length) {
        players[color.index].color = color;
      }
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
    Library library = Library();
    board.reserve = Reserve(library);

    board.dungeonDeck = library.makeDungeonDeck().toList();
    board.fillDungeonRowFirstTimeReplacingDragons(_random);
    // Set Rage level
    board.setRageLevelForNumberOfPlayers(players.length);
  }
}

class Reserve {
  final List<List<Card>> piles;
  Reserve(Library library)
      : piles = [
          library.makeAll('Mercenary'),
          library.makeAll('Explore'),
          library.makeAll('Secret Tome'),
        ] {
    // Goblin
    // Secret Tome
  }

  // Should this be CardType instead of Card?
  Iterable<CardType> get availableCardTypes sync* {
    for (var pile in piles) {
      if (pile.isNotEmpty) yield pile.first.type;
    }
  }

  Card purchaseCard(CardType cardType) {
    for (var pile in piles) {
      if (pile.isNotEmpty && pile.first.type == cardType) {
        return pile.removeLast();
      }
    }
    throw ArgumentError('No cards in reserve of type $cardType');
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

enum PlayerColor {
  red,
  yellow,
  green,
  blue,
}

String colorToString(PlayerColor color) {
  return ['Red', 'Yellow', 'Green', 'Blue'][color.index];
}

class CubeCounts {
  final List<int> _playerCubeCounts;

  CubeCounts({int startWith = 0})
      : _playerCubeCounts = List.filled(PlayerColor.values.length, startWith);

  void addTo(PlayerColor color, [int amount = 1]) {
    assert(amount >= 0);
    _playerCubeCounts[color.index] += amount;
  }

  int takeFrom(PlayerColor color, [int amount = 1]) {
    assert(amount >= 0);
    int current = _playerCubeCounts[color.index];
    int taken = min(current, amount);
    _playerCubeCounts[color.index] -= taken;
    assert(_playerCubeCounts[color.index] >= 0);
    return taken;
  }

  int countFor(PlayerColor color) => _playerCubeCounts[color.index];

  int get totalCubes =>
      _playerCubeCounts.fold(0, (previous, count) => previous + count);
}

class DragonBag extends CubeCounts {
  int dragonCubesLeft = Board.dragonMaxCubeCount;

  CubeCounts pickCubes(Random random, int count) {
    int dragonIndex = -1;
    List<int> cubes = [];
    for (var color in PlayerColor.values) {
      cubes.addAll(List.filled(countFor(color), color.index));
    }
    cubes.addAll(List.filled(dragonCubesLeft, dragonIndex));
    cubes.shuffle(random);

    CubeCounts counts = CubeCounts();
    for (var picked in cubes.take(count)) {
      if (picked != dragonIndex) {
        counts.addTo(PlayerColor.values[picked], 1);
      }
    }
    return counts;
  }
  // Player cube, give it back to them.
  // Dragon cube, give it back to the Board/whatever.
}

extension Pile<T> on List<T> {
  List<T> takeAndRemoveUpTo(int count) {
    int actual = min(count, length);
    List<T> taken = take(actual).toList();
    removeRange(0, actual);
    return taken;
  }
}

class Board {
  static const int playerMaxHealth = 10;
  static const int dragonMaxCubeCount = 24;
  static const int playerMaxCubeCount = 30;
  static const int dungeonRowMaxSize = 6;
  static const List<int> rageValues = <int>[2, 2, 3, 3, 4, 4, 5];

  int rageIndex = 0; // TODO: Set according to number of players.

  Graph graph = FrontGraphBuilder().build();
  late Reserve reserve;
  List<Card> dungeonDiscard = [];
  List<Card> dungeonRow = [];
  late List<Card> dungeonDeck;

  // Should these be private?
  CubeCounts playerCubeStashes = CubeCounts(startWith: playerMaxCubeCount);
  CubeCounts playerDamageTaken = CubeCounts();
  CubeCounts clankArea = CubeCounts();
  DragonBag dragonBag = DragonBag();

  Board();

  void fillDungeonRowFirstTimeReplacingDragons(Random random) {
    assert(dungeonRow.isEmpty);
    dungeonDeck.shuffle(random); // Our job to shuffle first time.
    // On first fill, replace any dragon cards.
    List<Card> newCards = dungeonDeck
        .where((card) => !card.type.dragon)
        .take(dungeonRowMaxSize)
        .toList();
    for (var card in newCards) {
      dungeonDeck.remove(card);
    }
    dungeonDeck.shuffle(random);
    dungeonRow.addAll(newCards);
  }

  bool refillDungeonRow() {
    int needed = dungeonRowMaxSize - dungeonRow.length;
    List<Card> newCards = dungeonDeck.takeAndRemoveUpTo(needed);
    bool newDragon = newCards.any((card) => card.type.dragon);
    dungeonRow.addAll(newCards);
    return newDragon;
  }

  void increaseDragonRage() {
    if (rageIndex < rageValues.length - 1) {
      rageIndex++;
    }
  }

  int get dragonRageCubeCount => rageValues[rageIndex];

  int damageTakenByPlayer(PlayerColor color) =>
      playerDamageTaken.countFor(color);

  int healthForPlayer(PlayerColor color) =>
      playerMaxHealth - damageTakenByPlayer(color);

  void takeDamage(PlayerColor color, int amount) {
    playerDamageTaken.addTo(color, amount);
  }

  int adjustClank(PlayerColor color, int amount) {
    assert(amount != 0);
    if (amount > 0) {
      int takenCount = playerCubeStashes.takeFrom(color, amount);
      clankArea.addTo(color, takenCount);
      return takenCount;
    }
    int takenCount = clankArea.takeFrom(color, amount.abs());
    playerCubeStashes.addTo(color, takenCount);
    return takenCount * -1;
  }

  void setRageLevelForNumberOfPlayers(int playerCount) {
    // playerCount = 1 is not supported in the base rules, left in for testing.
    // assert(playerCount > 1);
    assert(playerCount <= 4);
    rageIndex = [3, 2, 1, 0][playerCount - 1];
  }

  int cubeCountForNormalDragonAttack() {
    int dungeonRowDangerCount =
        dungeonRow.fold(0, (sum, card) => card.type.danger ? 1 : 0);
    return dragonRageCubeCount + dungeonRowDangerCount;
  }

  void dragonAttack(Random random, {int additionalCubes = 0}) {
    // Take clank from area to bag.
    for (var color in PlayerColor.values) {
      dragonBag.addTo(color, clankArea.countFor(color));
    }
    clankArea = CubeCounts();
    int numberOfCubes = cubeCountForNormalDragonAttack() + additionalCubes;
    print('DRAGON ATTACK ($numberOfCubes cubes)');
    var drawn = dragonBag.pickCubes(random, numberOfCubes);
    for (var color in PlayerColor.values) {
      playerDamageTaken.addTo(color, drawn.countFor(color));
    }
  }

  void assertTotalClankCubeCounts() {
    for (var color in PlayerColor.values) {
      int total = playerCubeStashes.countFor(color);
      total += playerDamageTaken.countFor(color);
      total += clankArea.countFor(color);
      total += dragonBag.countFor(color);
      assert(total == playerMaxCubeCount);
    }
  }

  Iterable<CardType> get availableCardTypes {
    return reserve.availableCardTypes
        .followedBy(dungeonRow.map((card) => card.type));
  }

  Card purchaseCard(CardType cardType) {
    if (cardType.set == CardSet.reserve) {
      return reserve.purchaseCard(cardType);
    }
    Card card = dungeonRow.firstWhere((card) => card.type == cardType);
    dungeonRow.remove(card);
    return card;
  }
}

class PlayerDeck {
  // First is the 'top' of the pile (next to draw).
  List<Card> drawPile = <Card>[];
  // First is first drawn.
  List<Card> hand = <Card>[];
  // First is first played.
  List<Card> playArea = <Card>[];
  // last is the 'top' (most recently discarded), but order doesn't matter.
  late List<Card> discardPile;

  PlayerDeck({List<Card>? cards}) {
    discardPile = cards ?? <Card>[];
  }

  List<Card> get allCards {
    List<Card> allCards = [];
    allCards.addAll(drawPile);
    allCards.addAll(hand);
    allCards.addAll(discardPile);
    allCards.addAll(playArea);
    return allCards;
  }

  int get cardCount => allCards.length;

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

  int calculateTotalPoints() {
    return allCards.fold(0, (sum, card) => sum + card.points);
  }
}

class Card {
  final CardType type;
  // Don't construct this const (would end up sharing instances).
  Card._(this.type);

  String get name => type.name;
  int get skill => type.skill;
  int get boots => type.boots;
  int get swords => type.swords;

  int get clank => type.clank;
  int get points => type.points;

  @override
  String toString() => type.name;
}

class Library {
  CardType cardTypeByName(String name) =>
      baseSetAllCardTypes.firstWhere((type) => type.name == name);

  List<Card> make(String name, int amount) =>
      List.generate(amount, (_) => Card._(cardTypeByName(name)));

  List<Card> makeAll(String name) {
    var type = cardTypeByName(name);
    return List.generate(type.count, (_) => Card._(type));
  }

  Iterable<Card> makeDungeonDeck() {
    var dungeonTypes =
        baseSetAllCardTypes.where((type) => type.set == CardSet.dungeon);
    var dungeonCardLists = dungeonTypes
        .map((type) => List.generate(type.count, (_) => Card._(type)));
    return dungeonCardLists.expand((element) => element);
  }
}

// This could be an enum using one of the enum packages.
class Artifact {
  final String name;
  final int value;
  const Artifact._(this.name, this.value);

  factory Artifact.byValue(int desiredValue) {
    return all.firstWhere((artifact) => artifact.value == desiredValue);
  }

  @override
  String toString() => '$value:$name';

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

class ArtifactToken extends LootToken {
  Artifact artifact;
  ArtifactToken(this.artifact) : super(points: artifact.value);

  @override
  String toString() => artifact.toString();
}
