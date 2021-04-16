import 'dart:math';

import 'package:clank/cards.dart';

import 'graph.dart';
import 'planner.dart';
import 'box.dart';

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

  LootToken useItem(Loot itemType) {
    LootToken item = loot.firstWhere((item) => item.loot == itemType);
    loot.remove(item);
    return item;
  }

  Iterable<LootToken> get usableItems => loot.where((loot) => loot.loot.usable);

  bool get hasArtifact => loot.any((token) => token.isArtifact);
  bool get hasCrown => loot.any((token) => token.isCrown);
  bool get hasMonkeyIdol => loot.any((token) => token.isMonkeyIdol);
  bool get hasMasterKey => loot.any((token) => token.isMasterKey);
  bool get inGame => status == PlayerStatus.inGame;

  int get companionsInPlayArea => deck.playArea
      .fold(0, (sum, card) => sum + (card.type.isCompanion ? 1 : 0));

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

  bool hasCard(CardType cardType) {
    for (var card in deck.allCards) {
      if (card.type == cardType) return true;
    }
    return false;
  }

  int countOfCards(CardType cardType) {
    return deck.allCards
        .fold(0, (sum, card) => sum + (card.type == cardType ? 1 : 0));
  }

  // There must be a shorter way to write this?
  void trashCardOfType(CardType cardType) {
    for (var card in deck.playArea) {
      if (card.type == cardType) {
        deck.playArea.remove(card);
        return;
      }
    }
    for (var card in deck.discardPile) {
      if (card.type == cardType) {
        deck.discardPile.remove(card);
        return;
      }
    }
  }

  bool hasLoot(Loot lootType) {
    for (var lootToken in loot) {
      if (lootToken.loot == lootType) return true;
    }
    return false;
  }

  int calculateTotalPoints(Box box, Library library) {
    // Zero score if you get knocked out while still in the depths.
    if (status == PlayerStatus.knockedOut && location.inDepths) {
      return 0;
    }
    int total = 0;
    var conditions = PointsConditions(
      gold: gold,
      secretTomeCount: countOfCards(library.cardTypeByName('Secret Tome')),
      hasMasteryToken: hasLoot(box.lootByName('Mastery Token')),
      hasChalice: hasLoot(box.lootByName('Chalice')),
      hasDragonEgg: hasLoot(box.lootByName('Dragon Egg')),
      hasMonkeyIdol: hasLoot(box.lootByName('Monkey Idol')),
    );
    total += deck.calculateTotalPoints(conditions);
    total += loot.fold(0, (sum, loot) => sum + loot.points);
    total += gold;
    return total;
  }

  @override
  String toString() => '${colorToString(color)}';
}

abstract class EndOfTurnEffect {
  void execute(Turn turn);
}

class TrashCard extends EndOfTurnEffect {
  final CardType cardType;
  TrashCard(this.cardType);

  @override
  void execute(Turn turn) {
    turn.player.trashCardOfType(cardType);
  }
}

class ClankGame {
  late List<Player> players;
  late Player activePlayer;
  late Board board;
  late Box box = Box();
  final Library library = Library();
  int? seed;
  final Random _random;
  bool isComplete = false;
  Player? playerFirstOut;
  int countdownTrackIndex = 0;

  ClankGame({required List<Planner> planners, this.seed})
      : _random = Random(seed) {
    players = planners
        .map((planner) =>
            Player(planner: planner, deck: createStarterDeck(library)))
        .toList();
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

  void executeRoomEntryEffects(Turn turn, Traverse action) {
    // print('$player moved: ${edge.end}');
    var player = turn.player;

    // Special effect of exiting with an artifact.
    if (action.edge.end == board.graph.start) {
      assert(turn.player.hasArtifact);
      // A bit of a hack to construct a Mastery Token manually.
      player.loot.add(LootToken(box.lootByName('Mastery Token')));
    }

    // Entering a crystal marks you as exhausted even if you teleport in/out
    // https://boardgamegeek.com/thread/1671635/article/25115569#25115569
    if (action.edge.end.isCrystalCave) {
      turn.enteredCrystalCave();
    }

    if (action.takeItem) {
      assert(player.location.loot.isNotEmpty);
      // What do we do when takeItem is a lie (there are no tokens)?
      var token = player.location.loot.first;
      executeAcquireLoot(turn, token);
    }
  }

  void executeTraverse(Turn turn, Traverse action) {
    Edge edge = action.edge;
    if (action.useTeleport) {
      turn.teleports -= 1;
      assert(turn.teleports >= 0);
    } else {
      assert(!turn.exhausted, 'Not possible to spend boots once exhausted.');
      turn.boots -= edge.bootsCost;
      assert(turn.boots >= 0);
      if (action.spendHealth > 0) {
        assert(!turn.ignoreMonsters,
            'Not possible to spend health after ignore monsters!');
        board.takeDamage(turn.player.color, action.spendHealth);
      }
      if (!turn.ignoreMonsters) {
        turn.swords -= (edge.swordsCost - action.spendHealth);
      }
      assert(turn.swords >= 0);
    }

    Player player = turn.player;
    player.token.moveTo(edge.end);
    executeRoomEntryEffects(turn, action);
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
    turn.skill -= turn.skillCostForCard(cardType);
    assert(turn.skill >= 0);
    assert(cardType.swordsCost == 0);

    Card card = board.takeCard(cardType);
    turn.player.deck.add(card);
    executeAcquireCardEffects(turn, card);
    print('${turn.player} acquires $card');
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
    executeCardUseEffects(turn, action.cardType, orEffect: null);
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

  EndOfTurnEffect createEndOfTurnEffect(EndOfTurn effect) {
    switch (effect) {
      case EndOfTurn.trashPlayedBurgle:
        return TrashCard(library.cardTypeByName('Burgle'));
    }
  }

  void executeOrSpecial(Turn turn, OrSpecial special) {
    switch (special) {
      case OrSpecial.dragonAttack:
        board.dragonAttack(_random);
        break;
      case OrSpecial.spendSevenGoldForTwoSecretTomes:
        if (turn.player.gold < 7) {
          throw ArgumentError('7 gold required.');
        }
        turn.player.gold -= 7;
        var secretTome = library.cardTypeByName('Secret Tome');
        var cards = [
          board.reserve.takeCard(secretTome),
          board.reserve.takeCard(secretTome)
        ];
        turn.player.deck.discardPile.addAll(cards);
        break;
      case OrSpecial.takeSecretFromAdjacentRoom:
        // TODO: Implement.
        break;
      case OrSpecial.teleport:
        turn.teleports += 1;
        break;
      case OrSpecial.trashACard:
        // TODO: Implement.
        break;
    }
  }

  void executeOrEffect(Turn turn, OrEffect orEffect) {
    turn.player.gold += orEffect.gainGold;
    if (orEffect.hearts != 0) {
      board.healDamage(turn.player.color, orEffect.hearts);
    }
    turn.swords += orEffect.swords;
    if (orEffect.clank != 0) {
      turn.adjustClank(board, orEffect.clank);
    }
    OrSpecial? special = orEffect.special;
    if (special != null) {
      executeOrSpecial(turn, special);
    }
  }

  // Used by both PlayCard and Fight.
  void executeCardUseEffects(Turn turn, CardType cardType,
      {required OrEffect? orEffect}) {
    assert(cardUsableAtLocation(cardType, turn.player.location));
    turn.addTurnResourcesFromCard(cardType);
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

    TriggerEffects? triggers = cardType.triggers;
    if (triggers != null) {
      turn.unresolvedTriggers.add(triggers);
    }
    if (cardType.ignoreExhaustion) {
      turn.ignoreExhaustion = true;
    }
    if (cardType.ignoreMonsters) {
      turn.ignoreMonsters = true;
    }

    if (cardType.queuedEffect != null) {
      turn.queuedEffects.add(cardType.queuedEffect!);
    }
    if (cardType.endOfTurn != null) {
      turn.endOfTurnEffects.add(createEndOfTurnEffect(cardType.endOfTurn!));
    }

    if (cardType.specialEffect == SpecialEffect.gemTwoSkillDiscount) {
      turn.gemTwoSkillDiscount = true;
    }

    if (orEffect != null) {
      executeOrEffect(turn, orEffect);
    }
  }

  void executeUseDevice(Turn turn, UseDevice action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.use);
    turn.skill -= cardType.skillCost;
    assert(turn.skill >= 0);
    assert(cardType.swordsCost == 0);

    Card card = board.takeCard(cardType);
    board.dungeonDiscard.add(card);
    executeCardUseEffects(turn, cardType, orEffect: action.orEffect);
    print('${turn.player} uses device $card');
  }

  void executeItemUseEffects(Turn turn, Loot itemType) {
    assert(itemType.usable);

    turn.swords += itemType.swords;
    turn.boots += itemType.boots;
    turn.skill += itemType.skill;
    turn.player.gold += itemType.gold;

    if (itemType.hearts != 0) {
      board.healDamage(turn.player.color, itemType.hearts);
    }
    if (itemType.drawCards != 0) {
      turn.player.deck.drawCards(_random, itemType.drawCards);
    }
  }

  void executeUseItem(Turn turn, UseItem action) {
    Loot itemType = action.item;
    assert(itemType.usable);
    var item = turn.player.useItem(itemType);
    board.usedItems.add(item);
    executeItemUseEffects(turn, itemType);
    print('${turn.player} uses item $item');
  }

  void executeAction(Turn turn, Action action) {
    if (action is PlayCard) {
      turn.player.deck.playCard(action.cardType);
      executeCardUseEffects(turn, action.cardType, orEffect: action.orEffect);
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
    if (action is UseItem) {
      executeUseItem(turn, action);
      return;
    }
    // Should this really be its own action subclass?
    if (action is ReplaceCardInDungeonRow) {
      var triggers =
          board.replaceCardInDungeonRowIgnoringDragon(action.cardType);
      executeArrivalTriggers(turn, triggers);
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

  void executeEndOfTurnEffects(Turn turn) {
    for (var effect in turn.endOfTurnEffects) {
      effect.execute(turn);
    }
  }

  void executeArrivalTriggers(Turn turn, ArrivalTriggers triggers) {
    if (triggers.clankForAll != 0) {
      addClankForAll(turn, triggers.clankForAll);
    }
    if (triggers.refillDragonCubes != 0) {
      board.refillDragonCubes(triggers.refillDragonCubes);
    }
  }

  void executeEndOfTurn(Turn turn) {
    // You must play all cards
    assert(turn.hand.isEmpty);
    activePlayer.deck.discardPlayAreaAndDrawNewHand(_random);

    assert(turn.teleports == 0, 'Must use all teleports.');
    assert(turn.queuedEffects.isEmpty, 'Must use all queued effects.');
    executeEndOfTurnEffects(turn);

    // Refill the dungeon row
    ArrivalTriggers triggers = board.refillDungeonRow();
    executeArrivalTriggers(turn, triggers);

    // Triggers happen before dragon attacks.
    // https://boardgamegeek.com/thread/2380191/article/34177411#34177411
    if (triggers.dragonAttacks) {
      board.dragonAttack(_random);
    }
    board.assertTotalClankCubeCounts();
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
    // FAQ: extra cubes marked on the countdown track apply only to those attacks
    board.dragonAttack(_random, additionalCubes: additionalCubes);
  }

  bool updatePlayerStatuses() {
    bool changedStatus = false;
    for (var player in players) {
      changedStatus |= player.updateStatus(board);
    }
    return changedStatus;
  }

  void applyTriggeredEffect(Turn turn, Effect effect) {
    assert(effect.triggered);
    turn.skill += effect.skill;
    turn.boots += effect.boots;
    turn.swords += effect.swords;
    turn.teleports += effect.teleports;
    if (effect.drawCards > 0) {
      turn.player.deck.drawCards(_random, effect.drawCards);
    }
    if (effect.hearts > 0) {
      board.healDamage(turn.player.color, effect.hearts);
    }
  }

  void executeTriggeredEffects(Turn turn) {
    var player = turn.player;
    // This is a bit of an abuse of removeWhere.
    turn.unresolvedTriggers.removeWhere((trigger) {
      Effect effect = trigger(EffectTriggers(
        haveArtifact: player.hasArtifact,
        haveCrown: player.hasCrown,
        haveMonkeyIdol: player.hasMonkeyIdol,
        twoCompanionsInPlayArea: player.companionsInPlayArea > 1,
      ));
      if (effect.triggered) {
        applyTriggeredEffect(turn, effect);
      }
      return effect.triggered;
    });
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
      executeTriggeredEffects(turn);
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

  int pointsForPlayer(Player player) {
    return player.calculateTotalPoints(box, library);
  }

  static PlayerDeck createStarterDeck(Library library) {
    PlayerDeck deck = PlayerDeck();
    deck.addAll(library.make('Burgle', 6));
    deck.addAll(library.make('Stumble', 2));
    deck.addAll(library.make('Sidestep', 1));
    deck.addAll(library.make('Scramble', 1));
    return deck;
  }

  void placeLootTokens() {
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
    // TODO: Place monkey Tokens
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
    board.reserve = Reserve(library);

    board.dungeonDeck = library.makeDungeonDeck().toList();
    // Set Rage level
    board.setRageLevelForNumberOfPlayers(players.length);

    var triggers = board.fillDungeonRowFirstTimeReplacingDragons(_random);
    Turn turn = Turn(player: activePlayer);
    executeArrivalTriggers(turn, triggers); // Can add clank.
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
  int refillDragonCubes;
  ArrivalTriggers({
    required this.dragonAttacks,
    required this.clankForAll,
    required this.refillDragonCubes,
  });
}

// O(N^2), use only for short lists.
Iterable<T> uniqueValues<T>(Iterable<T> values) {
  List<T> seen = [];
  for (var value in values) {
    if (!seen.contains(value)) seen.add(value);
  }
  return seen;
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
  List<LootToken> usedItems = []; // Mostly for accounting.

  // Should these be private?
  CubeCounts playerCubeStashes = CubeCounts(startWith: playerMaxCubeCount);
  CubeCounts playerDamageTaken = CubeCounts();
  CubeCounts clankArea = CubeCounts();
  DragonBag dragonBag = DragonBag();

  Board();

  ArrivalTriggers fillDungeonRowFirstTimeReplacingDragons(Random random) {
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
    return arrivalTriggersForNewCards(newCards);
  }

  ArrivalTriggers refillDungeonRow() {
    int needed = dungeonRowMaxSize - dungeonRow.length;
    List<Card> newCards = dungeonDeck.takeAndRemoveUpTo(needed);
    dungeonRow.addAll(newCards);
    return arrivalTriggersForNewCards(newCards);
  }

  ArrivalTriggers arrivalTriggersForNewCards(Iterable<Card> newCards,
      {bool ignoreDragon = false}) {
    bool newDragon = newCards.any((card) => card.type.dragon);
    int arrivalClank =
        newCards.fold(0, (sum, card) => sum + card.type.arriveClank);
    int arrivalDragonCubes = newCards.fold(
        0, (sum, card) => sum + card.type.arriveReturnDragonCubes);
    return ArrivalTriggers(
      dragonAttacks: newDragon && !ignoreDragon,
      clankForAll: arrivalClank,
      refillDragonCubes: arrivalDragonCubes,
    );
  }

  ArrivalTriggers replaceCardInDungeonRowIgnoringDragon(CardType cardType) {
    var card = dungeonRow.firstWhere((card) => card.type == cardType);
    dungeonRow.remove(card);
    dungeonDiscard.add(card);
    var newCards = dungeonDeck.takeAndRemoveUpTo(1);
    dungeonRow.addAll(newCards);
    return arrivalTriggersForNewCards(newCards, ignoreDragon: true);
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

  void refillDragonCubes(int count) {
    int maxRefill = Board.dragonMaxCubeCount - dragonBag.dragonCubesLeft;
    int refill = min(count, maxRefill);
    dragonBag.dragonCubesLeft += refill;
  }

  void dragonAttack(Random random, {int additionalCubes = 0}) {
    // FAQ: Players can be damaged regardless of location (e.g. still at flag).
    moveDragonAreaToBag();
    int numberOfCubes = cubeCountForNormalDragonAttack() + additionalCubes;
    print('DRAGON ATTACK ($numberOfCubes cubes)');
    var drawn = dragonBag.pickAndRemoveCubes(random, numberOfCubes);
    for (var color in PlayerColor.values) {
      // Directly move the cubes to damageTaken (bypassing the stash).
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
    return uniqueValues(reserve.availableCardTypes
        .followedBy(dungeonRow.map((card) => card.type)));
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

  int calculateTotalPoints(PointsConditions conditions) {
    int total = 0;
    for (var card in allCards) {
      total += card.points;
      ConditionalPoints? pointsCondition = card.type.pointsCondition;
      if (pointsCondition != null) {
        total += pointsCondition(conditions);
      }
    }
    return total;
  }
}
