import 'dart:math';

import 'package:clank/cards.dart';

import 'actions.dart';
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

// Responsible for storing per-turn data as well as helpers for
// executing a turn.  This is the only place where both Player and Board
// are accessible at the same time.
class Turn {
  final Player player;
  final Board board;
  int skill = 0;
  int boots = 0;
  int swords = 0;
  // Teleport is not immediate, and can be accumulated between cards:
  // https://boardgamegeek.com/thread/1654963/article/23962792#23962792
  int teleports = 0;
  bool _exhausted = false; // Entered a crystal cave.
  bool ignoreExhaustion = false;
  bool ignoreMonsters = false;
  bool gemTwoSkillDiscount = false;
  int leftoverClankReduction = 0; // always negative
  // Some cards have effects which require other conditions to complete
  // Hold them in unresolvedTriggers until they do. (e.g. Rebel Scout)
  List<TriggerEffects> unresolvedTriggers = [];

  // Actions from cards which don't have to happen immediately, but must
  // happen by end of turn.
  List<QueuedEffect> queuedEffects = [];

  // Actions which happen as result of end of turn (e.g. trashing)
  List<EndOfTurnEffect> endOfTurnEffects = [];

  Turn({required this.player, required this.board});

  List<Card> get hand => player.deck.hand;

  void enteredCrystalCave() => _exhausted = true;
  bool get exhausted => _exhausted && !ignoreExhaustion;

  void addTurnResourcesFromCard(CardType cardType) {
    skill += cardType.skill;
    boots += cardType.boots;
    swords += cardType.swords;
    teleports += cardType.teleports;
  }

  int skillCostForCard(CardType cardType) {
    if (gemTwoSkillDiscount && cardType.isGem) {
      return cardType.skillCost - 2;
    }
    return cardType.skillCost;
  }

  // Does this belong on board instead?
  int adjustActivePlayerClank(int desired) {
    // You can't ever have both negative accumulated and a positive clank area.
    assert(leftoverClankReduction == 0 || board.clankAreaCountFor(player) == 0);
    // lefover zero, desired neg ->  apply, letting leftover to remainder.
    // leftover neg, desired neg  -> just update leftover
    // leftover neg, desired pos  -> reduce leftover, reduce desired, apply
    int actual = 0;
    if (leftoverClankReduction == 0) {
      actual = board.adjustClank(player, desired);
      leftoverClankReduction = min(desired - actual, 0);
    } else {
      assert(leftoverClankReduction < 0);
      // First apply to to the leftovers.
      int reduced = desired + leftoverClankReduction;
      if (reduced <= 0) {
        leftoverClankReduction = reduced;
      } else {
        actual = board.adjustClank(player, reduced);
        leftoverClankReduction = min(reduced - actual, 0);
      }
    }
    return actual;
  }

  int hpAvailableForMonsterTraversals() {
    // We can't spend more cubes than we have or available health points.
    return min(board.stashCountFor(player), board.healthFor(player) - 1);
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

class ActionExecutor {
  final Turn turn;
  final Board board;
  final Random _random;
  final ClankGame game;

  // TODO: Remove all these?
  final Box box;
  final Library library;

  ActionExecutor(
      {required this.turn, required Random random, required this.game})
      : board = turn.board,
        _random = random,
        box = game.box,
        library = game.library;

  void executeAcquireLoot(LootToken token) {
    Player player = turn.player;
    assert(!token.isArtifact || player.canTakeArtifact);
    executeAcquireLootEffects(token);
    print('$player loots $token');
    player.takeLoot(token);
  }

  void executeRoomEntryEffects(Traverse action) {
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
      executeAcquireLoot(token);
    }
  }

  void executeTraverse(Traverse action) {
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
        board.takeDamage(turn.player, action.spendHealth);
      }
      if (!turn.ignoreMonsters) {
        turn.swords -= (edge.swordsCost - action.spendHealth);
      }
      assert(turn.swords >= 0);
    }

    Player player = turn.player;
    player.token.moveTo(edge.end);
    executeRoomEntryEffects(action);
  }

  void executeAcquireCardEffects(Card card) {
    if (card.type.acquireClank != 0) {
      turn.adjustActivePlayerClank(card.type.acquireClank);
    }
    turn.swords += card.type.acquireSwords;
    turn.boots += card.type.acquireBoots;
    if (card.type.acquireHearts != 0) {
      board.healDamage(turn.player, card.type.acquireHearts);
    }
  }

  void executeAcquireLootEffects(LootToken token) {
    if (token.loot.acquireRage != 0) {
      board.increaseDragonRage(token.loot.acquireRage);
    }
  }

  void executeAcquireCard(AcquireCard action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.buy);
    turn.skill -= turn.skillCostForCard(cardType);
    assert(turn.skill >= 0);
    assert(cardType.swordsCost == 0);

    Card card = board.takeCard(cardType);
    turn.player.deck.add(card);
    executeAcquireCardEffects(card);
    print('${turn.player} acquires $card');
  }

  void executeFight(Fight action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.fight);
    turn.swords -= cardType.swordsCost;
    assert(turn.swords >= 0);
    assert(cardType.skillCost == 0);

    Card card = board.takeCard(cardType);
    if (!card.type.neverDiscards) {
      board.dungeonDiscard.add(card);
    }
    executeCardUseEffects(action.cardType, orEffect: null);
    print('${turn.player} fought $card');
  }

  EndOfTurnEffect createEndOfTurnEffect(EndOfTurn effect) {
    switch (effect) {
      case EndOfTurn.trashPlayedBurgle:
        return TrashCard(library.cardTypeByName('Burgle'));
    }
  }

  void executeOrSpecial(OrSpecial special) {
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

  void executeOrEffect(OrEffect orEffect) {
    turn.player.gold += orEffect.gainGold;
    if (orEffect.hearts != 0) {
      board.healDamage(turn.player, orEffect.hearts);
    }
    turn.swords += orEffect.swords;
    if (orEffect.clank != 0) {
      turn.adjustActivePlayerClank(orEffect.clank);
    }
    OrSpecial? special = orEffect.special;
    if (special != null) {
      executeOrSpecial(special);
    }
  }

  // Used by both PlayCard and Fight.
  void executeCardUseEffects(CardType cardType, {required OrEffect? orEffect}) {
    assert(cardUsableAtLocation(cardType, turn.player.location));
    turn.addTurnResourcesFromCard(cardType);
    if (cardType.clank != 0) {
      turn.adjustActivePlayerClank(cardType.clank);
    }
    if (cardType.drawCards != 0) {
      turn.player.deck.drawCards(_random, cardType.drawCards);
    }
    if (cardType.othersClank != 0) {
      game.addClankForOthers(cardType.othersClank);
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
      executeOrEffect(orEffect);
    }
  }

  void executeUseDevice(UseDevice action) {
    CardType cardType = action.cardType;
    assert(cardType.interaction == Interaction.use);
    turn.skill -= cardType.skillCost;
    assert(turn.skill >= 0);
    assert(cardType.swordsCost == 0);

    Card card = board.takeCard(cardType);
    board.dungeonDiscard.add(card);
    executeCardUseEffects(cardType, orEffect: action.orEffect);
    print('${turn.player} uses device $card');
  }

  void executeItemUseEffects(Loot itemType) {
    assert(itemType.usable);

    turn.swords += itemType.swords;
    turn.boots += itemType.boots;
    turn.skill += itemType.skill;
    turn.player.gold += itemType.gold;

    if (itemType.hearts != 0) {
      board.healDamage(turn.player, itemType.hearts);
    }
    if (itemType.drawCards != 0) {
      turn.player.deck.drawCards(_random, itemType.drawCards);
    }
  }

  void executeUseItem(UseItem action) {
    Loot itemType = action.item;
    assert(itemType.usable);
    var item = turn.player.useItem(itemType);
    board.usedItems.add(item);
    executeItemUseEffects(itemType);
    print('${turn.player} uses item $item');
  }

  void executeAction(Action action) {
    if (action is PlayCard) {
      turn.player.deck.playCard(action.cardType);
      executeCardUseEffects(action.cardType, orEffect: action.orEffect);
      return;
    }
    if (action is EndTurn) {
      return;
    }
    if (action is Traverse) {
      executeTraverse(action);
      return;
    }
    if (action is AcquireCard) {
      executeAcquireCard(action);
      return;
    }
    if (action is Fight) {
      executeFight(action);
      return;
    }
    if (action is UseDevice) {
      executeUseDevice(action);
      return;
    }
    if (action is UseItem) {
      executeUseItem(action);
      return;
    }
    // Should this really be its own action subclass?
    if (action is ReplaceCardInDungeonRow) {
      var triggers =
          board.replaceCardInDungeonRowIgnoringDragon(action.cardType);
      game.executeArrivalTriggers(triggers);
      return;
    }
    assert(false);
  }
}

class ClankGame {
  late List<Player> players;
  late Turn turn;
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
        .map((planner) => Player(
            planner: planner,
            deck: PlayerDeck(cards: library.createStarterDeck())))
        .toList();
    setupPlayersAndBoard();
    // Set turn before filling dungeon row as it could cause clank to be
    // distributed to all players.
    turn = Turn(player: players.first, board: board);
    setupTokensAndCards();
  }

  Player nextPlayer() {
    int index = players.indexOf(turn.player);
    if (index == players.length - 1) return players.first;
    return players[index + 1];
  }

  Player get activePlayer => turn.player;

  void addClankForAll(int clank) {
    for (var player in players) {
      if (player == activePlayer) {
        turn.adjustActivePlayerClank(clank);
      } else {
        board.adjustClank(player, clank);
      }
    }
  }

  void addClankForOthers(int clank) {
    // No need to adjust turn negative clank balance since its just others.
    for (var player in players) {
      if (player != activePlayer) {
        board.adjustClank(player, clank);
      }
    }
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

  void applyTriggeredEffect(Effect effect) {
    assert(effect.triggered);
    turn.skill += effect.skill;
    turn.boots += effect.boots;
    turn.swords += effect.swords;
    turn.teleports += effect.teleports;
    if (effect.drawCards > 0) {
      turn.player.deck.drawCards(_random, effect.drawCards);
    }
    if (effect.hearts > 0) {
      board.healDamage(turn.player, effect.hearts);
    }
  }

  // This probably belongs outside of the game class.
  Future<void> takeTurn() async {
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
    ActionExecutor executor =
        ActionExecutor(turn: turn, game: this, random: _random);
    do {
      action = await activePlayer.planner.nextAction(turn);
      // Never trust what comes back from a plan?
      executor.executeAction(action);
      executeTriggeredEffects();
      //print(turn);
    } while (!(action is EndTurn));
    executeEndOfTurn();
    bool statusChanged = updatePlayerStatuses();
    // If players changed status, start countdown track!
    if (playerFirstOut == null && statusChanged) {
      playerFirstOut =
          players.firstWhere((player) => player.status != PlayerStatus.inGame);
    }
    isComplete = checkForEndOfGame();
    turn = Turn(player: nextPlayer(), board: board);
  }

  // Temporary helper until refactoring complete.
  void executeAction(Action action) {
    ActionExecutor(turn: turn, game: this, random: _random)
        .executeAction(action);
  }

  void executeTriggeredEffects() {
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
        applyTriggeredEffect(effect);
      }
      return effect.triggered;
    });
  }

  void executeEndOfTurnEffects() {
    for (var effect in turn.endOfTurnEffects) {
      effect.execute(turn);
    }
  }

  void executeEndOfTurn() {
    // You must play all cards
    assert(turn.hand.isEmpty);
    activePlayer.deck.discardPlayAreaAndDrawNewHand(_random);

    assert(turn.teleports == 0, 'Must use all teleports.');
    assert(turn.queuedEffects.isEmpty, 'Must use all queued effects.');
    executeEndOfTurnEffects();

    // Refill the dungeon row
    ArrivalTriggers triggers = board.refillDungeonRow();
    executeArrivalTriggers(triggers);

    // Triggers happen before dragon attacks.
    // https://boardgamegeek.com/thread/2380191/article/34177411#34177411
    if (triggers.dragonAttacks) {
      board.dragonAttack(_random);
    }
    board.assertTotalClankCubeCounts();
  }

  bool checkForEndOfGame() {
    // Once all players are out of the dungeon or knocked out the game ends.
    return !players.any((player) => player.status == PlayerStatus.inGame);
  }

  int pointsForPlayer(Player player) {
    return player.calculateTotalPoints(box, library);
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

  void setupPlayersAndBoard() {
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
  }

  void setupTokensAndCards() {
    placeLootTokens();
    // Fill reserve.
    board.reserve = Reserve(library);

    board.dungeonDeck = library.makeDungeonDeck().toList();
    // Set Rage level
    board.setRageLevelForNumberOfPlayers(players.length);

    var triggers = board.fillDungeonRowFirstTimeReplacingDragons(_random);
    executeArrivalTriggers(triggers); // Can add clank.
  }

  void executeArrivalTriggers(ArrivalTriggers triggers) {
    if (triggers.clankForAll != 0) {
      addClankForAll(triggers.clankForAll);
    }
    if (triggers.refillDragonCubes != 0) {
      board.refillDragonCubes(triggers.refillDragonCubes);
    }
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

extension PlayerBoard on Board {
  void takeDamage(Player player, int amount) =>
      takeDamageForPlayer(player.color, amount);
  void healDamage(Player player, amount) =>
      healDamageForPlayer(player.color, amount);
  int adjustClank(Player player, int amount) =>
      adjustClankForPlayer(player.color, amount);
  int damageTakenBy(Player player) => damageTakenByPlayer(player.color);
  int healthFor(Player player) => healthForPlayer(player.color);
  int stashCountFor(Player player) => playerCubeStashes.countFor(player.color);
  int clankAreaCountFor(Player player) => clankArea.countFor(player.color);
  int bagCountFor(Player player) => dragonBag.countFor(player.color);
}

// Intentionally does not know about Player object only PlayerColor.
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

  void takeDamageForPlayer(PlayerColor color, int amount) {
    // It is *not* OK to call this if you can't take damage.
    // All damage sources are by-choice, other than the dragon
    // And the dragon gives cubes when taking damage.
    int takenCount = playerCubeStashes.takeFrom(color, amount);
    if (takenCount != amount) {
      throw ArgumentError("Don't call takeDamage without enough cubes left");
    }
    playerDamageTaken.addTo(color, amount);
  }

  int healDamageForPlayer(PlayerColor color, int amount) {
    // It's OK to call this even if you can't heal.
    int healed = playerDamageTaken.takeFrom(color, amount);
    playerCubeStashes.addTo(color, healed);
    return healed;
  }

  int adjustClankForPlayer(PlayerColor color, int amount) {
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
