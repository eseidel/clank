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
  Player({required this.planner, PlayerDeck? deck})
      : deck = deck ?? PlayerDeck();

  Space get location => token.location!;

  void takeLoot(LootToken token) {
    assert(token.location != null);
    token.removeFromBoard();
    loot.add(token);
  }

  bool get hasArtifact => loot.any((token) => token.isArtifact);
  bool get inGame => status == PlayerStatus.inGame;

  bool get canTakeArtifact {
    int artifactCount =
        loot.fold(0, (sum, token) => sum + (token.isArtifact ? 1 : 0));
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
    // Zero score if you get knocked out while still in the depths.
    if (status == PlayerStatus.knockedOut && location.inDepths) {
      return 0;
    }
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

  void executeAcquireLoot(Turn turn, LootToken token) {
    Player player = turn.player;
    assert(!token.isArtifact || player.canTakeArtifact);
    executeAcquireLootEffects(turn, token);
    print('$player loots $token');
    player.takeLoot(token);
  }

  void executeTraverse(Turn turn, Traverse action) {
    Edge edge = action.edge;
    turn.boots -= edge.bootsCost;
    assert(turn.boots >= 0);
    if (action.spendHealth > 0) {
      board.takeDamage(turn.player.color, action.spendHealth);
    }
    turn.swords -= (edge.swordsCost - action.spendHealth);
    assert(turn.swords >= 0);

    Player player = turn.player;
    player.token.moveTo(edge.end);
    // TODO: Other move-entry effects (like crystal cave).
    // print('$player moved: ${edge.end}');
    if (action.takeItem) {
      assert(player.location.loot.isNotEmpty);
      // What do we do when takeItem is a lie (there are no tokens)?
      var token = player.location.loot.first;
      executeAcquireLoot(turn, token);
    }
    // TODO: handle keys, exhaustion, etc.
  }

  void executeAcquireCardEffects(Turn turn, Card card) {
    if (card.type.acquireClank != 0) {
      turn.adjustClank(board, card.type.acquireClank);
    }
    turn.swords += card.type.acquireSwords;
    turn.boots += card.type.acquireBoots;
    if (card.type.acquireHearts != 0) {
      board.healDamage(turn.player.color, card.type.acquireHearts);
    }
  }

  void executeAcquireLootEffects(Turn turn, LootToken token) {
    if (token.loot.acquireRage != 0) {
      board.increaseDragonRage(token.loot.acquireRage);
    }
  }

  void executeAcquireCard(Turn turn, AcquireCard action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.buy);
    turn.skill -= cardType.skillCost;
    assert(turn.skill >= 0);
    assert(cardType.swordsCost == 0);

    Card card = board.takeCard(cardType);
    turn.player.deck.add(card);
    executeAcquireCardEffects(turn, card);
    print('${turn.player} buys $card');
  }

  void executeFight(Turn turn, Fight action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.fight);
    turn.swords -= cardType.swordsCost;
    assert(turn.swords >= 0);
    assert(cardType.skillCost == 0);

    Card card = board.takeCard(cardType);
    if (!card.type.neverDiscards) {
      board.dungeonDiscard.add(card);
    }
    executeCardUseEffects(turn, action.cardType);
    print('${turn.player} fought $card');
  }

  void executeOthersClank(CardType cardType) {
    // No need to adjust turn negative clank balance since its just others.
    for (var player in players) {
      if (player != activePlayer) {
        board.adjustClank(player.color, cardType.othersClank);
      }
    }
  }

  // Used by both PlayCard and Fight.
  void executeCardUseEffects(Turn turn, CardType cardType) {
    assert(cardUsableAtLocation(cardType, turn.player.location));
    turn.addUseEffectsFromCard(cardType);
    if (cardType.clank != 0) {
      turn.adjustClank(board, cardType.clank);
    }
    if (cardType.drawCards != 0) {
      turn.player.deck.drawCards(_random, cardType.drawCards);
    }
    if (cardType.othersClank != 0) {
      executeOthersClank(cardType);
    }
    turn.player.gold += cardType.gainGold;
  }

  void executeUseDevice(Turn turn, UseDevice action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.use);
    turn.skill -= cardType.skillCost;
    assert(turn.skill >= 0);
    assert(cardType.swordsCost == 0);

    Card card = board.takeCard(cardType);
    board.dungeonDiscard.add(card);
    executeCardUseEffects(turn, action.cardType);
    print('${turn.player} used $card');
  }

  void executeAction(Turn turn, Action action) {
    if (action is PlayCard) {
      turn.player.deck.playCard(action.cardType);
      executeCardUseEffects(turn, action.cardType);
      return;
    }
    if (action is EndTurn) {
      return;
    }
    if (action is Traverse) {
      executeTraverse(turn, action);
      return;
    }
    if (action is AcquireCard) {
      executeAcquireCard(turn, action);
      return;
    }
    if (action is Fight) {
      executeFight(turn, action);
      return;
    }
    if (action is UseDevice) {
      executeUseDevice(turn, action);
      return;
    }
    assert(false);
  }

  void addClankForAll(Turn turn, int clank) {
    for (var player in players) {
      if (player == activePlayer) {
        turn.adjustClank(board, clank);
      } else {
        board.adjustClank(player.color, clank);
      }
    }
  }

  void executeEndOfTurn(Turn turn) {
    // You must play all cards
    assert(turn.hand.isEmpty);
    activePlayer.deck.discardPlayAreaAndDrawNewHand(_random);
    // Refill the dungeon row
    ArrivalTriggers triggers = board.refillDungeonRow();
    if (triggers.clankForAll != 0) {
      addClankForAll(turn, triggers.clankForAll);
    }
    // Triggers happen before dragon attacks.
    if (triggers.dragonAttacks) {
      board.dragonAttack(_random);
    }
    // TODO: ASSERTs do not pass yet!  We're leaking cubes.
    // board.assertTotalClankCubeCounts();
  }

  void knockOutAllPlayersStillInGame() {
    for (var player in players) {
      if (player.inGame) {
        player.status = PlayerStatus.knockedOut;
      }
    }
  }

  void moveCountdownTrack() {
    countdownTrackIndex++;
    if (countdownTrackIndex >= 4) {
      knockOutAllPlayersStillInGame();
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
    Box box = Box();
    var allTokens = box.makeAllLootTokens().toList();

    Iterable<Space> spacesWithSpecial(Special special) =>
        board.graph.allSpaces.where((space) => space.special == special);

    // Artifacts (excluding randomly based on player count)
    var artifacts = allTokens.where((token) => token.isArtifact).toList();
    for (var space in spacesWithSpecial(Special.artifact)) {
      var token = artifacts
          .firstWhere((token) => token.points == space.expectedArtifactValue);
      assert(token.location == null);
      token.moveTo(space);
    }
    // Minor Secrets
    var minorSecrets = allTokens.where((token) => token.isMinorSecret).toList();
    minorSecrets.shuffle(_random);
    for (var space in spacesWithSpecial(Special.minorSecret)) {
      minorSecrets.removeLast().moveTo(space);
    }
    // Major Secrets
    var majorSecrets = allTokens.where((token) => token.isMajorSecret).toList();
    majorSecrets.shuffle(_random);
    for (var space in spacesWithSpecial(Special.majorSecret)) {
      majorSecrets.removeLast().moveTo(space);
    }
    // TODO: Monkey Tokens
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
    // TODO: Goblin
  }

  Iterable<CardType> get availableCardTypes sync* {
    for (var pile in piles) {
      if (pile.isNotEmpty) yield pile.first.type;
    }
  }

  Card takeCard(CardType cardType) {
    // Goblin is a special hack, and is never discarded.
    if (cardType.neverDiscards) {
      return Card._(cardType);
    }
    for (var pile in piles) {
      if (pile.isNotEmpty && pile.first.type == cardType) {
        return pile.removeLast();
      }
    }
    throw ArgumentError('No cards in reserve of type $cardType');
  }
}

// Maybe this just get merged in with Artifact and MarketItem to be Loot?
enum LootType {
  majorSecret,
  minorSecret,
  artifact,
  market,
}

class Loot {
  final LootType type;
  final String name;
  final int count;
  final int points;
  final int hearts;
  final int gold;
  final int skill;
  final int drawCards;
  final int acquireRage;
  final int boots;
  final int swords;

  const Loot.majorSecret({
    required this.name,
    required this.count,
    this.points = 0,
    this.hearts = 0,
    this.gold = 0,
    this.skill = 0,
    this.drawCards = 0,
  })  : type = LootType.majorSecret,
        boots = 0,
        swords = 0,
        acquireRage = 0;

  const Loot.minorSecret({
    required this.name,
    required this.count,
    this.points = 0,
    this.hearts = 0,
    this.gold = 0,
    this.skill = 0,
    this.drawCards = 0,
    this.acquireRage = 0,
    this.boots = 0,
    this.swords = 0,
  }) : type = LootType.minorSecret;

  const Loot.artifact({
    required this.name,
    required this.points,
  })   : type = LootType.artifact,
        count = 1,
        hearts = 0,
        gold = 0,
        skill = 0,
        drawCards = 0,
        boots = 0,
        swords = 0,
        acquireRage = 1;

  const Loot.market({
    required this.name,
    required this.count,
    required this.points,
  })   : type = LootType.market,
        hearts = 0,
        gold = 0,
        skill = 0,
        drawCards = 0,
        boots = 0,
        swords = 0,
        acquireRage = 0;
}

List<Loot> allLootDescriptions = const [
  // Major Secrets
  Loot.majorSecret(name: 'Chalice', count: 3, points: 7),
  Loot.majorSecret(name: 'Potion of Greater Healing', count: 2, hearts: 2),
  Loot.majorSecret(name: 'Greater Treasure', count: 2, gold: 5),
  Loot.majorSecret(name: 'Greater Skill Boost', count: 2, skill: 5),
  Loot.majorSecret(name: 'Flash of Brilliance', count: 2, drawCards: 3),

  // Minor Secrets
  Loot.minorSecret(name: 'Dragon Egg', count: 3, points: 3, acquireRage: 1),
  Loot.minorSecret(name: 'Potion of Healing', count: 3, hearts: 1),
  Loot.minorSecret(name: 'Treasure', count: 3, gold: 2),
  Loot.minorSecret(name: 'Skill Boost', count: 3, skill: 2),
  Loot.minorSecret(name: 'Potion of Strength', count: 2, swords: 2),
  Loot.minorSecret(name: 'Potion of Swiftness', count: 2, boots: 1),
  // Don't know how to trash yet.
  // Loot.minor(name: 'Magic Spring', count: 2, endOfTurnTrash: 1),

  // Artifacts
  Loot.artifact(name: 'Ring', points: 5),
  Loot.artifact(name: 'Ankh', points: 7),
  Loot.artifact(name: 'Vase', points: 10),
  Loot.artifact(name: 'Bananas', points: 15),
  Loot.artifact(name: 'Shield', points: 20),
  Loot.artifact(name: 'Chestplate', points: 25),
  Loot.artifact(name: 'Thurible', points: 30),

  // Market -- unclear if these belong as Loot?
  // They never have a location on the board.
  // They never use any of the effects secrets do.
  // But they do get counted for points (and physically manifest as tokens).
  Loot.market(name: 'Master Key', count: 2, points: 5),
  Loot.market(name: 'Backpack', count: 2, points: 5),
  Loot.market(name: 'Crown (10)', count: 1, points: 10),
  Loot.market(name: 'Crown (9)', count: 1, points: 9),
  Loot.market(name: 'Crown (8)', count: 1, points: 8),
];

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

  Iterable<LootToken> makeAllLootTokens() {
    return allLootDescriptions
        .map((loot) => List.generate(loot.count, (_) => LootToken(loot)))
        .expand((element) => element);
  }
}

enum PlayerColor {
  red,
  yellow,
  green,
  blue,
}

String colorToString(PlayerColor color) {
  return ['Red', 'Yellow', 'Green', 'Blue'][color.index];
}

// An alternative would be 120 instances of a Cube class which had an enum
// representing where each cube was at that moment.
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

  int get totalPlayerCubes =>
      _playerCubeCounts.fold(0, (previous, count) => previous + count);
}

class DragonBag extends CubeCounts {
  int dragonCubesLeft = Board.dragonMaxCubeCount;

  CubeCounts pickAndRemoveCubes(Random random, int count) {
    int dragonIndex = -1;
    List<int> cubes = [];
    for (var color in PlayerColor.values) {
      cubes.addAll(List.filled(countFor(color), color.index));
    }
    cubes.addAll(List.filled(dragonCubesLeft, dragonIndex));
    cubes.shuffle(random);

    // Player cube, give it back to them.
    // Dragon cube, give it back to the Board/whatever.
    CubeCounts counts = CubeCounts();
    for (var picked in cubes.take(count)) {
      if (picked == dragonIndex) {
        dragonCubesLeft -= 1;
      } else {
        _playerCubeCounts[picked] -= 1;
        counts.addTo(PlayerColor.values[picked], 1);
      }
    }
    return counts;
  }

  int get totalCubes => totalPlayerCubes + dragonCubesLeft;
}

extension Pile<T> on List<T> {
  List<T> takeAndRemoveUpTo(int count) {
    int actual = min(count, length);
    List<T> taken = take(actual).toList();
    removeRange(0, actual);
    return taken;
  }
}

class ArrivalTriggers {
  bool dragonAttacks;
  int clankForAll;
  ArrivalTriggers({required this.dragonAttacks, required this.clankForAll});
}

class Board {
  static const int playerMaxHealth = 10;
  static const int dragonMaxCubeCount = 24;
  static const int playerMaxCubeCount = 30;
  static const int dungeonRowMaxSize = 6;
  static const List<int> rageValues = <int>[2, 2, 3, 3, 4, 4, 5];

  int rageIndex = 0;

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

  ArrivalTriggers refillDungeonRow() {
    int needed = dungeonRowMaxSize - dungeonRow.length;
    List<Card> newCards = dungeonDeck.takeAndRemoveUpTo(needed);
    bool newDragon = newCards.any((card) => card.type.dragon);
    int arrivalClank =
        newCards.fold(0, (sum, card) => sum + card.type.arriveClank);
    dungeonRow.addAll(newCards);
    return ArrivalTriggers(dragonAttacks: newDragon, clankForAll: arrivalClank);
  }

  void increaseDragonRage([int amount = 1]) {
    rageIndex = min(rageIndex + amount, rageValues.length - 1);
  }

  int get dragonRageCubeCount => rageValues[rageIndex];

  int damageTakenByPlayer(PlayerColor color) =>
      playerDamageTaken.countFor(color);

  int healthForPlayer(PlayerColor color) =>
      playerMaxHealth - damageTakenByPlayer(color);

  void takeDamage(PlayerColor color, int amount) {
    // It is *not* OK to call this if you can't take damage.
    // All damage sources are by-choice, other than the dragon
    // And the dragon gives cubes when taking damage.
    int takenCount = playerCubeStashes.takeFrom(color, amount);
    if (takenCount != amount) {
      throw ArgumentError("Don't call takeDamage without enough cubes left");
    }
    playerDamageTaken.addTo(color, amount);
  }

  int healDamage(PlayerColor color, int amount) {
    // It's OK to call this even if you can't heal.
    int healed = playerDamageTaken.takeFrom(color, amount);
    playerCubeStashes.addTo(color, healed);
    return healed;
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
        dungeonRow.fold(0, (sum, card) => sum + (card.type.danger ? 1 : 0));
    return dragonRageCubeCount + dungeonRowDangerCount;
  }

  void moveDragonAreaToBag() {
    for (var color in PlayerColor.values) {
      dragonBag.addTo(color, clankArea.countFor(color));
    }
    clankArea = CubeCounts();
  }

  void dragonAttack(Random random, {int additionalCubes = 0}) {
    moveDragonAreaToBag();
    int numberOfCubes = cubeCountForNormalDragonAttack() + additionalCubes;
    print('DRAGON ATTACK ($numberOfCubes cubes)');
    var drawn = dragonBag.pickAndRemoveCubes(random, numberOfCubes);
    for (var color in PlayerColor.values) {
      // Give the cubes back so they can be used for damage accounting.
      playerCubeStashes.addTo(color, drawn.countFor(color));
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

  Card takeCard(CardType cardType) {
    if (cardType.set == CardSet.reserve) {
      return reserve.takeCard(cardType);
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

  void playCard(CardType cardType) {
    Card card = hand.firstWhere((card) => card.type == cardType);
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

  int drawCards(Random random, int count) {
    List<Card> drawn = [];
    if (drawPile.length < count) {
      drawn = drawPile;
      drawPile = discardPile;
      discardPile = [];
      drawPile.shuffle(random);
    }
    int leftToDraw = count - drawn.length;
    drawn.addAll(drawPile.takeAndRemoveUpTo(leftToDraw));
    hand.addAll(drawn);
    return drawn.length;
  }

  int discardPlayAreaAndDrawNewHand(Random random, [int count = 5]) {
    assert(hand.isEmpty);
    discardPile.addAll(playArea);
    playArea = [];
    return drawCards(random, count);
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

class LootToken extends Token {
  Loot loot;
  LootToken(this.loot);

  bool get isArtifact => loot.type == LootType.artifact;
  bool get isMinorSecret => loot.type == LootType.minorSecret;
  bool get isMajorSecret => loot.type == LootType.majorSecret;

  int get points => loot.points;

  @override
  String toString() => loot.toString();
}
