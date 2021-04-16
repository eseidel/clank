import 'dart:math';

import 'package:clank/cards.dart';
import 'package:clank/clank.dart';
import 'package:clank/graph.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

void main() {
  Library library = Library();
  // CardType cardType(String name) => library.cardTypeByName(name);

  // Does this belong on Turn?
  int stashClankCount(Board board, Player player) =>
      board.playerCubeStashes.countFor(player.color);

  int areaClankCount(Board board, Player player) =>
      board.clankArea.countFor(player.color);

  // int bagClankCount(Board board, Player player) =>
  //     board.dragonBag.countFor(player.color);

  CardType cardType(String name) => library.cardTypeByName(name);

  void addAndPlayCard(ClankGame game, Turn turn, String name,
      {int? orEffectIndex}) {
    var card = library.make(name, 1).first;
    turn.player.deck.hand.add(card);
    game.executeAction(turn, PlayCard(card.type, orEffectIndex: orEffectIndex));
  }

  test('deck shuffles when empty', () {
    PlayerDeck deck = PlayerDeck();
    expect(deck.cardCount, 0);
    expect(deck.discardPlayAreaAndDrawNewHand(Random(0), 1), 0);
    deck.addAll(library.make('Burgle', 1));
    expect(deck.cardCount, 1);
    deck.addAll(library.make('Burgle', 5));
    expect(deck.cardCount, 6);
    expect(deck.hand.length, 0);
    expect(deck.discardPile.length, 6);
    expect(deck.drawPile.length, 0);
    deck.discardPlayAreaAndDrawNewHand(Random(0));
    expect(deck.hand.length, 5);
    expect(deck.discardPile.length, 0);
    expect(deck.drawPile.length, 1);
  });

  test('initial deal', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 0);
    expect(game.players.length, 1);
    expect(game.players.first.deck.cardCount, 10);
  });

  test('clank damage cubes', () {
    var board = Board();
    expect(board.damageTakenByPlayer(PlayerColor.blue), 0);
    expect(board.healthForPlayer(PlayerColor.blue), 10);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 30);
    board.takeDamage(PlayerColor.blue, 2);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 2);
    expect(board.healthForPlayer(PlayerColor.blue), 8);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 28);
    board.healDamage(PlayerColor.blue, 1);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 1);
    expect(board.healthForPlayer(PlayerColor.blue), 9);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 29);
    board.healDamage(PlayerColor.blue, 2);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 0);
    expect(board.healthForPlayer(PlayerColor.blue), 10);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 30);

    board.adjustClank(PlayerColor.blue, 30);
    board.moveDragonAreaToBag();
    // Not valid to try to take damage with no cubes (should check first).
    expect(() => board.takeDamage(PlayerColor.blue, 2), throwsArgumentError);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 0);
    expect(board.healthForPlayer(PlayerColor.blue), 10);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 0);
  });

  test('takeAndRemoveUpTo', () {
    List<int> list = [1, 2, 3];
    var a = list.takeAndRemoveUpTo(1);
    expect(a.length, 1);
    expect(a[0], 1);

    var b = list.takeAndRemoveUpTo(3);
    expect(b.length, 2);
    expect(b[0], 2);
    expect(b[1], 3);

    var c = [1];
    var d = c.takeAndRemoveUpTo(3);
    expect(d.length, 1);
    expect(d[0], 1);
    expect(c.length, 0);
  });

  test('negative clank', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 10);
    Turn turn = Turn(player: game.players.first);
    expect(game.board.clankArea.totalPlayerCubes, 0);
    addAndPlayCard(game, turn, 'Stumble');
    expect(turn.leftoverClankReduction, 0);
    expect(game.board.clankArea.totalPlayerCubes, 1);

    addAndPlayCard(game, turn, 'Move Silently');
    expect(turn.leftoverClankReduction, -1);
    expect(game.board.clankArea.totalPlayerCubes, 0);
  });

  test('drawCards edgecase', () {
    PlayerDeck deck = PlayerDeck(cards: library.make('Burgle', 3));
    Random random = Random(0);
    deck.drawCards(random, 2);
    expect(deck.hand.length, 2);
    deck.drawCards(random, 2);
    expect(deck.hand.length, 3);
  });

  test('leftover negative clank', () {
    // Sources: personal stash, clank area, leftover negative, adjustmnet

    // Common-case, clank addition:
    // stash: 30, area: 0, leftover: 0, new: +2 -> stash: 28, area: 2, leftover: 0
    ClankGame game = ClankGame(planners: [MockPlanner()], seed: 10);
    Board board = game.board;
    var player = game.players.first;
    Turn turn = Turn(player: player);
    expect(board.clankArea.totalPlayerCubes, 0);
    expect(stashClankCount(board, player), 30);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, 0);
    turn.adjustClank(board, 2);
    expect(stashClankCount(board, player), 28);
    expect(areaClankCount(board, player), 2);
    expect(turn.leftoverClankReduction, 0);

    // Running out of clank in stash:
    // stash: 0, area: 30, leftover: 0, new: +2 -> stash: 0, area: 30, leftover: 0
    game = ClankGame(planners: [MockPlanner()], seed: 10);
    board = game.board;
    player = game.players.first;
    turn.adjustClank(board, 30);
    expect(stashClankCount(board, player), 0);
    expect(areaClankCount(board, player), 30);
    expect(turn.leftoverClankReduction, 0);

    // Can't add clank once run out:
    turn.adjustClank(board, 2);
    expect(stashClankCount(board, player), 0);
    expect(areaClankCount(board, player), 30);
    expect(turn.leftoverClankReduction, 0);

    // Negative clank pulls back from clank area:
    // stash: 0, area: 30, leftover: 0, new: -2 -> stash: 2, area: 28, leftover: 0
    turn.adjustClank(board, -2);
    expect(stashClankCount(board, player), 2);
    expect(areaClankCount(board, player), 28);
    expect(turn.leftoverClankReduction, 0);

    // Negative clank accumulates when area empty:
    // stash: 30, area: 0, leftover: 0, new: -2 -> stash: 30, area: 0, leftover: -2
    game = ClankGame(planners: [MockPlanner()], seed: 10);
    board = game.board;
    player = game.players.first;
    turn.adjustClank(board, -2);
    expect(stashClankCount(board, player), 30);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, -2);
    turn.adjustClank(board, -2);
    expect(stashClankCount(board, player), 30);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, -4);

    // Adding clank reduces accumlated negative:
    // stash: 30, area: 0, leftover: -4, new: 2 -> stash: 30, area: 0, leftover: -2
    turn.adjustClank(board, 2);
    expect(stashClankCount(board, player), 30);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, -2);

    // Adding clank can take you back positive:
    // stash: 30, area: 0, leftover: -2, new: 3 -> stash: 29, area: 1, leftover: 0
    turn.adjustClank(board, 3);
    expect(stashClankCount(board, player), 29);
    expect(areaClankCount(board, player), 1);
    expect(turn.leftoverClankReduction, 0);

    // Order of "negative clank" vs. "can't apply clank" -- NOT IN RULES
    // stash: 0, area: 0, lefover -2, new: 2 -> stash: 0, area: 30, lefover: 0
    // Keeping leftover -2 would also be valid.
    // This would only come up in a case of:
    // - All cubes in dragon bag (or health bar)
    // - Negative clank (e.g. Move Silently)
    // - Positive clank (e.g. Dead Run) -- Does this negate the negative?
    // - Heal (or dragon attack and then heal)
    // - Postive Clank -> Should this now add to area?  Currently don't.
    game = ClankGame(planners: [MockPlanner()], seed: 10);
    board = game.board;
    player = game.players.first;
    turn.adjustClank(board, 30);
    board.moveDragonAreaToBag();
    expect(stashClankCount(board, player), 0);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, 0);
    turn.adjustClank(board, -2);
    expect(stashClankCount(board, player), 0);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, -2);
    // Adding clank here could be blocked for two reasons, either due to
    // no cubes in stash or negative leftover.
    turn.adjustClank(board, 2);
    expect(stashClankCount(board, player), 0);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, 0); // -2 would also be reasonable.
  });

  test('drawCards effect', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 0);
    var player = game.players.first;
    Turn turn = Turn(player: player);
    expect(turn.hand.length, 5);
    addAndPlayCard(game, turn, 'Diamond'); // adds Diamond, plays = draw 1
    expect(player.deck.playArea.length, 1);
    expect(turn.hand.length, 6);
    addAndPlayCard(game, turn, 'Brilliance'); // draw 3
    expect(player.deck.playArea.length, 2);
    expect(turn.hand.length, 9);
    expect(player.deck.drawPile.length, 1);
    expect(player.deck.discardPile.length, 0);
    addAndPlayCard(game, turn, 'Brilliance'); // draw 3
    expect(player.deck.playArea.length, 3);
    expect(player.deck.drawPile.length, 0);
    expect(turn.hand.length, 10);
  });

  test('gainGold effect', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 0);
    var player = game.players.first;
    Turn turn = Turn(player: player);
    expect(player.gold, 0);
    expect(turn.hand.length, 5);
    addAndPlayCard(game, turn, 'Pickaxe'); // gain 2 gold
    expect(turn.hand.length, 5);
    expect(player.deck.playArea.length, 1);
    expect(player.gold, 2);
    addAndPlayCard(game, turn, 'Treasure Map'); // gain 5 gold
    expect(turn.hand.length, 5);
    expect(player.deck.playArea.length, 2);
    expect(player.gold, 7);
  });

  test('dragon attack rage cube count', () {
    var twoPlayer =
        ClankGame(planners: [MockPlanner(), MockPlanner()], seed: 0);
    var threePlayer = ClankGame(
        planners: [MockPlanner(), MockPlanner(), MockPlanner()], seed: 0);
    var fourPlayer = ClankGame(
        planners: [MockPlanner(), MockPlanner(), MockPlanner(), MockPlanner()],
        seed: 0);

    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 3);
    expect(threePlayer.board.cubeCountForNormalDragonAttack(), 2);
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 2);

    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 2);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 3);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 3);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 4);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 4);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 5);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 5);
    fourPlayer.board.increaseDragonRage();
    expect(fourPlayer.board.cubeCountForNormalDragonAttack(), 5);
  });

  test('dragon attack cube count with danger', () {
    var twoPlayer =
        ClankGame(planners: [MockPlanner(), MockPlanner()], seed: 0);
    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 3);
    twoPlayer.board.dungeonRow = library.make('Kobold', 1);
    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 4);
    twoPlayer.board.dungeonRow = library.make('Kobold', 2);
    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 5);
  });

  test('acquireClank effect', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 10);
    var board = game.board;
    board.dungeonRow.addAll(library.make('Emerald', 1));
    var emerald = board.dungeonRow.last.type;
    Turn turn = Turn(player: game.players.first);
    turn.skill = emerald.skillCost;
    expect(board.clankArea.totalPlayerCubes, 0);
    game.executeAction(turn, AcquireCard(cardType: emerald));
    expect(board.clankArea.totalPlayerCubes, 2);
  });

  test('acquireSwords effect', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    board.dungeonRow.addAll(library.make('Silver Spear', 1));
    var silverSpear = board.dungeonRow.last.type;
    Turn turn = Turn(player: game.players.first);
    turn.skill = silverSpear.skillCost;
    expect(turn.swords, 0);
    game.executeAction(turn, AcquireCard(cardType: silverSpear));
    expect(turn.swords, 1);
  });

  test('acquireBoots effect', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    board.dungeonRow.addAll(library.make('Boots of Swiftness', 1));
    var bootsOfSwiftness = board.dungeonRow.last.type;
    Turn turn = Turn(player: game.players.first);
    turn.skill = bootsOfSwiftness.skillCost;
    expect(turn.boots, 0);
    game.executeAction(turn, AcquireCard(cardType: bootsOfSwiftness));
    expect(turn.boots, 1);
  });

  test('acquireHearts effect', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.players.first;
    var board = game.board;
    board.dungeonRow.addAll(library.make('Amulet of Vigor', 2));
    var amuletOfVigor = board.dungeonRow.last.type;
    Turn turn = Turn(player: game.players.first);

    // Does nothing if you haven't taken damage.
    expect(board.damageTakenByPlayer(player.color), 0);
    turn.skill = amuletOfVigor.skillCost;
    game.executeAction(turn, AcquireCard(cardType: amuletOfVigor));
    expect(board.damageTakenByPlayer(player.color), 0);

    // But heals one on acquire if you have.
    board.takeDamage(player.color, 2);
    expect(board.damageTakenByPlayer(player.color), 2);
    turn.skill = amuletOfVigor.skillCost;
    game.executeAction(turn, AcquireCard(cardType: amuletOfVigor));
    expect(board.damageTakenByPlayer(player.color), 1);
  });

  test('negative clank', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 10);
    Turn turn = Turn(player: game.players.first);
    expect(game.board.clankArea.totalPlayerCubes, 0);
    addAndPlayCard(game, turn, 'Stumble');
    expect(turn.leftoverClankReduction, 0);
    expect(game.board.clankArea.totalPlayerCubes, 1);

    addAndPlayCard(game, turn, 'Move Silently');
    expect(turn.leftoverClankReduction, -1);
    expect(game.board.clankArea.totalPlayerCubes, 0);
  });

  test('dragon reveal causes attack', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    // Refill works, dragonRevealed is false for non-dragon cards.
    board.dungeonRow = [];
    board.dungeonDeck = library.make('Move Silently', 6); // no dragon
    bool dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, false);
    expect(board.dungeonRow.length, 6);

    // Revealing a dragon shows dragonRevealed (also testing partial refill)
    board.dungeonRow.removeRange(0, 3);
    board.dungeonDeck = library.make('MonkeyBot 3000', 1); // dragon!
    dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, true);
    expect(board.dungeonRow.length, 4);

    board.dungeonDeck = library.make('MonkeyBot 3000', 1); // dragon!
    dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, true);
    expect(board.dungeonRow.length, 5);

    board.dungeonDeck = library.make('Move Silently', 6); // no dragon
    dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, false);
    expect(board.dungeonRow.length, 6);
  });

  test('arriveClank effect', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    // Refill works, dragonRevealed is false for non-dragon cards.
    board.dungeonRow = [];
    board.dungeonDeck = library.make('Overlord', 1); // arrival clank, no dragon
    ArrivalTriggers triggers = board.refillDungeonRow();
    expect(triggers.dragonAttacks, false);
    expect(triggers.clankForAll, 1);
    expect(board.dungeonRow.length, 1);

    board.dungeonDeck = library.make('Overlord', 2); // arrival clank, no dragon
    triggers = board.refillDungeonRow();
    expect(triggers.dragonAttacks, false);
    expect(triggers.clankForAll, 2);
    expect(board.dungeonRow.length, 3);
  });

  test('arrival effects happen before dragon attack', () {
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()], seed: 10);
    var board = game.board;
    Turn turn = Turn(player: game.activePlayer);
    board.dungeonRow = [];
    board.dungeonDeck = library.make('Overlord', 1); // arrival clank, no dragon
    expect(board.clankArea.totalPlayerCubes, 0);
    game.activePlayer.deck.hand = []; // avoid assert in executeEndOfTurn.
    game.executeEndOfTurn(turn);
    expect(board.clankArea.totalPlayerCubes, 2);
    expect(board.dungeonRow.length, 1);

    board.dungeonDeck = library.make('Overlord', 1); // arrival clank, no dragon
    board.dungeonDeck.addAll(library.make('Animated Door', 1)); // dragon!
    game.activePlayer.deck.hand = []; // avoid assert in executeEndOfTurn.
    game.executeEndOfTurn(turn);
    expect(board.clankArea.totalPlayerCubes, 0);
    // 24 dragon cubes + 2 from each overlord, per player = 28
    // Dragon attack: 3 cubes for 2 players, 28 - 3 = 25.
    expect(board.dragonBag.totalCubes, 25);
  });

  test('canTakeArtifact', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    expect(player.canTakeArtifact, true);
    var loot = game.box.makeAllLootTokens();
    // Previously only the loot item determined if had an artifact. :/
    player.loot = [
      loot.firstWhere((token) => token.isArtifact),
      loot.firstWhere((token) => token.isMajorSecret)
    ];
    expect(player.canTakeArtifact, false);
  });

  test('fight monsters', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var board = game.board;
    board.dungeonRow = library.make('Kobold', 1);
    Turn turn = Turn(player: player);
    turn.swords = 1;
    game.executeAction(turn, Fight(cardType: board.dungeonRow.first.type));
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 0);
    expect(turn.skill, 1);
    expect(turn.swords, 0);
  });

  test('use device', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var board = game.board;
    board.dungeonRow = library.make('Ladder', 1);
    Turn turn = Turn(player: player);
    turn.skill = 3;
    game.executeAction(turn, UseDevice(cardType: board.dungeonRow.first.type));
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 0);
    expect(turn.boots, 2);
    expect(turn.skill, 0);
  });

  test('zero score if knocked out in depths', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    expect(game.pointsForPlayer(player), 0);
    player.gold = 5;
    expect(game.pointsForPlayer(player), 5);
    player.status = PlayerStatus.knockedOut;
    expect(game.pointsForPlayer(player), 5);
    player.token.location = Space.depths(0, 0);
    expect(game.pointsForPlayer(player), 0);
  });

  test('picking up an artifact increases dragon rage', () {
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()]);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    turn.boots = 5; // plenty.
    var artifactRoom = game.board.graph.allSpaces
        .firstWhere((space) => space.expectedArtifactValue > 0);
    var edge = artifactRoom.edges.first.end.edges
        .firstWhere((edge) => edge.end == artifactRoom);
    expect(player.hasArtifact, false);
    int initialRage = game.board.rageIndex;
    game.executeTraverse(turn, Traverse(edge: edge, takeItem: true));
    expect(player.hasArtifact, true);
    expect(game.board.rageIndex, initialRage + 1);
  });

  test('consider moves which involve spending health', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1);
    builder.connect(from, to, monsters: 2);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = Turn(player: player);
    turn.boots = 5; // plenty
    turn.swords = 1; // Not enough.
    var generator = ActionGenerator(turn, board);
    var moves = generator.possibleMoves();
    expect(moves.length, 2); // spend 1 hp, spend 2 hp.
    expect(moves.any((move) => move.spendHealth > 0), true);

    // TODO: Can't spend hp if you're almost dead.
    // TODO: Can't spend hp if you have no cubes to spend.
  });

  test('cubes are not duplicated', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Stumble');
    expect(board.playerCubeStashes.countFor(player.color), 29);
    expect(board.clankArea.countFor(player.color), 1);
    board.dungeonRow = [];
    board.dungeonDeck = library.make('Orc Grunt', 1);
    board.dragonBag.dragonCubesLeft = 0;
    player.deck.hand = [];
    game.executeEndOfTurn(turn);
    expect(board.healthForPlayer(player.color), 9);
    expect(board.clankArea.countFor(player.color), 0);
    expect(board.dragonBag.countFor(player.color), 0);
    expect(board.playerCubeStashes.countFor(player.color), 29);
  });

  test('fighting goblin', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    var goblin = library.cardTypeByName('Goblin');
    Turn turn = Turn(player: player);
    turn.swords = 4;
    expect(player.gold, 0);
    expect(board.availableCardTypes.contains(goblin), isTrue);
    game.executeAction(turn, Fight(cardType: goblin));
    expect(turn.swords, 2);
    expect(player.gold, 1);
    expect(board.availableCardTypes.contains(goblin), isTrue);
    // It's possible to fight the goblin repeatedly.
    game.executeAction(turn, Fight(cardType: goblin));
    expect(turn.swords, 0);
    expect(player.gold, 2);
    expect(board.availableCardTypes.contains(goblin), isTrue);
    // And it's never discarded (per the rules)
    expect(board.dungeonDiscard, isEmpty);
  });

  test('using items', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var allItems = game.box.makeAllLootTokens();
    Turn turn = Turn(player: player);
    void addItemAndUse(String name) {
      var item = allItems.firstWhere((item) => item.loot.name == name);
      player.loot.add(item);
      game.executeAction(turn, UseItem(item: item.loot));
    }

    game.board.takeDamage(player.color, 9);
    expect(game.board.damageTakenByPlayer(player.color), 9);
    addItemAndUse('Potion of Greater Healing');
    expect(game.board.damageTakenByPlayer(player.color), 7);
    addItemAndUse('Greater Treasure');
    expect(player.gold, 5);
    addItemAndUse('Greater Skill Boost');
    expect(turn.skill, 5);
    addItemAndUse('Flash of Brilliance');
    expect(player.deck.hand.length, 8);
    addItemAndUse('Potion of Healing');
    expect(game.board.damageTakenByPlayer(player.color), 6);
    addItemAndUse('Treasure');
    expect(player.gold, 7);
    addItemAndUse('Skill Boost');
    expect(turn.skill, 7);
    addItemAndUse('Potion of Strength');
    expect(turn.swords, 2);
    addItemAndUse('Potion of Swiftness');
    expect(turn.boots, 1);
    expect(player.loot, isEmpty);
    expect(game.board.usedItems.length, 9);
  });

  test('conditional points effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();

    void addCard(String name) {
      var card = library.make(name, 1).first;
      player.deck.hand.add(card);
    }

    void addLoot(String name) {
      var newLoot = allLoot.firstWhere((loot) => loot.loot.name == name);
      player.loot.add(newLoot);
    }

    expect(game.pointsForPlayer(player), 0);
    addCard('Secret Tome');
    expect(game.pointsForPlayer(player), 7);
    addCard('Wizard');
    expect(game.pointsForPlayer(player), 9);
    addCard('Secret Tome');
    expect(game.pointsForPlayer(player), 18);

    addCard("Dragon's Eye");
    expect(game.pointsForPlayer(player), 18);
    addLoot('Mastery Token');
    expect(game.pointsForPlayer(player), 48);

    addCard('The Duke');
    expect(game.pointsForPlayer(player), 48);
    player.gold = 5;
    expect(game.pointsForPlayer(player), 54);
    player.gold = 7;
    expect(game.pointsForPlayer(player), 56);
    player.gold = 10;
    expect(game.pointsForPlayer(player), 60);
  });

  test('conditional points dwarven peddler', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();

    void addCard(String name) {
      var card = library.make(name, 1).first;
      player.deck.hand.add(card);
    }

    void addLoot(String name) {
      var newLoot = allLoot.firstWhere((loot) => loot.loot.name == name);
      player.loot.add(newLoot);
    }

    expect(game.pointsForPlayer(player), 0);
    addCard('Dwarven Peddler');
    addLoot('Chalice');
    expect(game.pointsForPlayer(player), 7);
    addLoot('Dragon Egg');
    expect(game.pointsForPlayer(player), 14);

    player.loot = [];
    expect(game.pointsForPlayer(player), 0);
    addLoot('Dragon Egg');
    expect(game.pointsForPlayer(player), 3);
    addLoot('Monkey Idol');
    expect(game.pointsForPlayer(player), 12);

    player.loot = [];
    expect(game.pointsForPlayer(player), 0);
    addLoot('Chalice');
    expect(game.pointsForPlayer(player), 7);
    addLoot('Monkey Idol');
    expect(game.pointsForPlayer(player), 16);
  });

  test('Exiting dungeon awards mastery token', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();
    // Move to right next to the start.
    var goal = board.graph.start;
    var nextToGoal = goal.edges.first.end;
    player.token.moveTo(nextToGoal);
    player.loot.add(allLoot.firstWhere((token) => token.points == 30));
    expect(player.hasArtifact, isTrue);
    var edge = nextToGoal.edges.firstWhere((edge) => edge.end == goal);
    Turn turn = Turn(player: player);
    turn.boots = 1;
    // Regardless of takeItem, a Mastery Token is awarded.
    game.executeTraverse(turn, Traverse(edge: edge, takeItem: false));
    player.hasLoot(game.box.lootByName('Mastery Token'));
    expect(game.pointsForPlayer(player), 50); // 30 + 20 for token.
    game.updatePlayerStatuses();
    // Previously points depended on inGame status, ensure it doesn't:
    expect(game.pointsForPlayer(player), 50);
    expect(player.inGame, isFalse);
  });

  test('teleport', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var board = game.board;
    board.dungeonRow = library.make('Teleporter', 1);
    Turn turn = Turn(player: player);
    turn.skill = 4;
    turn.boots = 3;
    expect(turn.teleports, 0);
    // Test use-device teleports
    game.executeAction(turn, UseDevice(cardType: board.dungeonRow.first.type));
    expect(turn.teleports, 1);
    // Play card teleports work too
    addAndPlayCard(game, turn, 'Invoker of the Ancients');
    expect(turn.teleports, 2);

    var edge = player.location.edges.first;
    game.executeTraverse(
        turn, Traverse(edge: edge, takeItem: false, useTeleport: true));
    expect(turn.teleports, 1);
    expect(turn.boots, 3);
  });

  test('mountain king triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var crown =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.loot.isCrown);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'The Mountain King');
    expect(turn.skill, 2);
    expect(turn.boots, 1);
    expect(turn.swords, 1);
    player.loot.add(crown);
    game.executeTriggeredEffects(turn);
    expect(turn.boots, 2);
    expect(turn.swords, 2);
  });

  test('queen of hearts triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var crown =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.loot.isCrown);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    game.board.takeDamage(player.color, 2);
    addAndPlayCard(game, turn, 'The Queen of Hearts');
    expect(game.board.damageTakenByPlayer(player.color), 2);
    expect(turn.skill, 3);
    expect(turn.swords, 1);
    player.loot.add(crown);
    game.executeTriggeredEffects(turn);
    expect(game.board.damageTakenByPlayer(player.color), 1);
  });

  test('kobold merchant triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Kobold Merchant');
    expect(turn.skill, 0);
    expect(player.gold, 2);
    player.loot.add(artifact);
    game.executeTriggeredEffects(turn);
    expect(turn.skill, 2);
  });

  test('rebel triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Rebel Miner');
    expect(player.deck.hand.length, 5);
    expect(player.gold, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 5);

    addAndPlayCard(game, turn, 'Rebel Soldier');
    expect(player.deck.hand.length, 5);
    expect(turn.swords, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 7); // Draw for both rebels.
    expect(player.deck.hand.length, 7); // Triggering again does nothing.

    addAndPlayCard(game, turn, 'Rebel Scout');
    expect(player.deck.hand.length, 7);
    expect(turn.boots, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 8); // Draw only for the new rebel.

    addAndPlayCard(game, turn, 'Rebel Captain');
    expect(player.deck.hand.length, 8);
    expect(turn.skill, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 9); // Draw only for the new rebel.
  });

  test('wand of recall triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Wand of Recall');
    expect(turn.skill, 2);
    game.executeTriggeredEffects(turn);
    expect(turn.teleports, 0);
    player.loot.add(artifact);
    game.executeTriggeredEffects(turn);
    expect(turn.teleports, 1);
  });

  test('archaeologist triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var monkeyIdol =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isMonkeyIdol);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    expect(player.deck.hand.length, 5);
    addAndPlayCard(game, turn, 'Archaeologist');
    expect(player.deck.hand.length, 6);
    expect(turn.skill, 0);
    game.executeTriggeredEffects(turn);
    expect(turn.skill, 0);
    player.loot.add(monkeyIdol);
    game.executeTriggeredEffects(turn);
    expect(turn.skill, 2);
  });

  test('crystal cave exhaustion', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, isCrystalCave: true);
    builder.connect(from, to);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = Turn(player: player);
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn, board);
    var moves = generator.possibleMoves();
    expect(moves.length, 1); // Move to 'to'
    game.executeAction(turn, moves.first);
    expect(turn.exhausted, isTrue);

    moves = generator.possibleMoves();
    expect(moves.length, 0); // No legal moves, despite having 4 boots.
    expect(turn.boots, 4);

    turn.teleports = 1;
    moves = generator.possibleMoves();
    expect(moves.length, 1); // Teleporting is still possible.
    game.executeAction(turn, moves.first);
    expect(turn.boots, 4);
    expect(turn.exhausted, isTrue);

    moves = generator.possibleMoves();
    expect(moves.length, 0); // Even after teleporting, still exhausted.
    expect(turn.boots, 4);

    addAndPlayCard(game, turn, 'Dead Run');
    expect(turn.exhausted, isFalse);
    expect(turn.boots, 6);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // No longer exhausted!

    // TODO: Test teleporting into a room still gets exhausted.
  });

  test('flying carpet ignores exhaustion and monsters', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, isCrystalCave: true);
    builder.connect(from, to, monsters: 1);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = Turn(player: player);
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn, board);
    var moves = generator.possibleMoves();
    expect(moves.length, 1); // Move to 'to'
    game.executeAction(turn, moves.first);
    expect(turn.exhausted, isTrue);
    expect(board.damageTakenByPlayer(player.color), 1); // From monster

    moves = generator.possibleMoves();
    expect(moves.length, 0); // No legal moves, despite having 4 boots.
    expect(turn.boots, 4);

    addAndPlayCard(game, turn, 'Flying Carpet');
    expect(turn.exhausted, isFalse);
    expect(turn.boots, 6);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // No longer exhausted!

    game.executeAction(turn, moves.first);
    expect(turn.boots, 5);
    expect(turn.exhausted, isFalse);
    expect(board.damageTakenByPlayer(player.color), 1); // no more dmg taken!
  });

  test('treasure hunter', () {
    // Seed is important to ensure dungeonRow doesn't have duplicates.
    var game = ClankGame(planners: [MockPlanner()], seed: 0);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    addAndPlayCard(game, turn, 'Treasure Hunter');
    expect(turn.skill, 2);
    expect(turn.swords, 2);
    expect(turn.queuedEffects.length, 1);
    // Cards with complex actions are split into two.
    var possibleActions = ActionGenerator(turn, board).possibleQueuedEffects();
    expect(possibleActions.length, 6); // One per card (no duplicates);
    game.executeAction(turn, possibleActions.first);
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 6);
    expect(board.dragonBag.totalCubes, 24); // No attacks were made.
  });

  test('treasure hunter triggers arrival effects', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 10);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);
    board.dungeonDeck = game.library.make('Watcher', 1);
    addAndPlayCard(game, turn, 'Treasure Hunter');
    var possibleActions = ActionGenerator(turn, board).possibleQueuedEffects();
    game.executeAction(turn, possibleActions.first);
    expect(board.clankArea.totalPlayerCubes, 1); // Arrival clank triggers.
  });

  test('initial dungeon row can trigger arrival clank', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 10);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);
    expect(board.clankArea.totalPlayerCubes, 0); // Random seed has none.

    board.dungeonDeck = game.library.make('Watcher', 6);
    board.dungeonRow = [];
    var triggers = board.fillDungeonRowFirstTimeReplacingDragons(Random());
    expect(triggers.clankForAll, 6); // Arrival clank triggers.
  });

  test('Master Burglar', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var turn = Turn(player: player);

    addAndPlayCard(game, turn, 'Master Burglar');
    expect(turn.skill, 2);
    expect(player.deck.cardCount, 11); // Starter + one Master Burglar.
    // Starting with 6 burgles, one will always be in the first hand.
    player.deck.discardPile.addAll(player.deck.hand);
    player.deck.hand = [];
    game.executeEndOfTurn(turn);
    expect(player.deck.cardCount, 10); // One burgle gone.
    expect(player.countOfCards(game.library.cardTypeByName('Burgle')), 5);
  });

  test('unique values', () {
    var game = ClankGame(planners: [MockPlanner()]);
    game.board.dungeonRow = game.library.make('Master Burglar', 3);
    expect(game.board.availableCardTypes.length, 5); // 1 for row, 4 on reserve.
  });

  test('master key unlocks tunnels', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();
    var key = allLoot.firstWhere((loot) => loot.loot.name == 'Master Key');

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1);
    builder.connect(from, to, requiresKey: true);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = Turn(player: player);
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn, board);
    var moves = generator.possibleMoves();
    expect(moves.length, 0); // Only available edge requires key.

    turn.player.loot.add(key);
    expect(player.hasMasterKey, isTrue);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // Can now go through edge!
    game.executeAction(turn, moves.first);
    expect(turn.boots, 4);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // And back, key isn't used up.
    expect(player.hasMasterKey, isTrue);
  });

  test('Gem Collector', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    board.dungeonRow = library.make('Emerald', 2);
    var emerald = board.dungeonRow.last.type;
    turn.skill = emerald.skillCost;
    game.executeAction(turn, AcquireCard(cardType: emerald));
    expect(board.clankArea.countFor(player.color), 2);
    expect(turn.leftoverClankReduction, 0);
    expect(turn.skill, 0);

    addAndPlayCard(game, turn, 'Gem Collector');
    expect(board.clankArea.countFor(player.color), 0);
    expect(turn.leftoverClankReduction, 0);
    expect(turn.skill, 2); // No refunds are issued from the previous purchase.

    turn.skill = emerald.skillCost;
    game.executeAction(turn, AcquireCard(cardType: emerald));
    expect(turn.skill, 2); // Second purchase is 2 skill cheaper!
  });

  test('possibleCardPlays', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    var turn = Turn(player: player);
    var generator = ActionGenerator(turn, board);

    player.deck.hand = [];
    var plays = generator.possibleCardPlays();
    expect(plays.length, 0);

    player.deck.hand = library.make('Burgle', 5);
    plays = generator.possibleCardPlays();
    expect(plays.length, 1); // Only consider one play per card type.

    player.deck.hand = library.make('Mister Whiskers', 1);
    plays = generator.possibleCardPlays();
    expect(plays.length, 2); // Multiple considered plays for OR types.

    // player.deck.hand = library.make('Apothecary', 1);
    // plays = generator.possibleCardPlays();
    // expect(plays.length, 1); // Only one play when conditions can't be met.

    // player.deck.hand = library.make('Apothecary', 1);
    // player.deck.hand.addAll(library.make('Burgle', 2));
    // plays = generator.possibleCardPlays();
    // expect(plays.length, 5); // 2 burgle + 3 apothecary options

    // player.deck.hand = library.make('Apothecary', 1);
    // player.deck.hand.addAll(library.make('Burgle', 1));
    // player.deck.hand.addAll(library.make('Stumble', 1));

    // plays = generator.possibleCardPlays();
    // expect(plays.length, 8); // 2 burgle + 2 x 3 apothecary options.
  });

  test('Underworld Dealing', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var underWorldDealing = cardType('Underworld Dealing');
    addAndPlayCard(game, turn, underWorldDealing.name, orEffectIndex: 0);
    expect(player.gold, 1);

    // Not allowed to play the second effect w/o the gold for it.
    expect(
        () => addAndPlayCard(game, turn, underWorldDealing.name,
            orEffectIndex: 1),
        throwsArgumentError);

    player.gold = 7;
    addAndPlayCard(game, turn, underWorldDealing.name, orEffectIndex: 1);
    expect(player.gold, 0);
    expect(player.deck.discardPile.length, 2);
  });

  test('Wand of Wind', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var wandOfWind = cardType('Wand of Wind');
    addAndPlayCard(game, turn, wandOfWind.name, orEffectIndex: 0);
    expect(turn.teleports, 1);

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, special: Special.majorSecret);
    var secret =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isMajorSecret);
    to.tokens.add(secret);
    builder.connect(from, to, monsters: 2);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    addAndPlayCard(game, turn, wandOfWind.name, orEffectIndex: 1);
    expect(player.loot.length, 1);

    // Artifacts are not secrets and can't be grabbed.
    from = Space.at(0, 0);
    to = Space.at(0, 1, special: Special.majorSecret);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    to.tokens.add(artifact);
    builder.connect(from, to, monsters: 2);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    expect(() => addAndPlayCard(game, turn, wandOfWind.name, orEffectIndex: 1),
        throwsArgumentError);
  }, skip: 'Unimplemented');

  test('arriveReturnDragonCubes effect', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var turn = Turn(player: game.activePlayer);

    board.dungeonRow = [];

    expect(board.dragonBag.dragonCubesLeft, 24);
    board.dungeonDeck = library.make('Shrine', 1);
    ArrivalTriggers triggers = board.refillDungeonRow();
    expect(board.dungeonRow.length, 1);
    game.executeArrivalTriggers(turn, triggers);
    expect(triggers.refillDragonCubes, 3);
    expect(board.dragonBag.dragonCubesLeft, 24);

    board.dragonBag.dragonCubesLeft = 10;
    board.dungeonDeck = library.make('Shrine', 1);
    triggers = board.refillDungeonRow();
    expect(board.dungeonRow.length, 2);
    game.executeArrivalTriggers(turn, triggers);
    expect(triggers.refillDragonCubes, 3);
    expect(board.dragonBag.dragonCubesLeft, 13);

    board.dragonBag.dragonCubesLeft = 10;
    board.dungeonDeck = library.make('Shrine', 2);
    triggers = board.refillDungeonRow();
    expect(board.dungeonRow.length, 4);
    game.executeArrivalTriggers(turn, triggers);
    expect(triggers.refillDragonCubes, 6);
    expect(board.dragonBag.dragonCubesLeft, 16);
  });

  test('Shrine use effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var shrine = cardType('Shrine');
    board.dungeonRow = library.make('Shrine', 2);
    turn.skill = 2;
    game.executeAction(turn, UseDevice(cardType: shrine, orEffectIndex: 0));
    expect(player.gold, 1);

    board.takeDamage(player.color, 2);
    turn.skill = 2;
    game.executeAction(turn, UseDevice(cardType: shrine, orEffectIndex: 1));
    expect(board.damageTakenByPlayer(player.color), 1);
  });

  test('Mister Whiskers', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var mrWhiskers = cardType('Mister Whiskers');
    turn.adjustClank(board, 2);
    expect(board.clankArea.totalPlayerCubes, 2);
    expect(board.dragonBag.totalCubes, 24);
    expect(board.cubeCountForNormalDragonAttack(), 3);
    addAndPlayCard(game, turn, mrWhiskers.name, orEffectIndex: 0);
    expect(board.dragonBag.totalCubes, 23); // 24 + 2 - 3 = 23
    expect(board.clankArea.totalPlayerCubes, 0);
    // Might have might have taken damage depending on random.

    expect(turn.leftoverClankReduction, 0);
    addAndPlayCard(game, turn, mrWhiskers.name, orEffectIndex: 1);
    expect(turn.leftoverClankReduction, -2);
  });

  test('Dragon Shrine', () {
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var dragonShrine = cardType('Dragon Shrine');
    expect(board.cubeCountForNormalDragonAttack(), 3);
    board.dungeonRow = library.make('Dragon Shrine', 2);
    expect(board.cubeCountForNormalDragonAttack(), 5); // +1 danger from each
    turn.skill = 4;
    game.executeAction(
        turn, UseDevice(cardType: dragonShrine, orEffectIndex: 0));
    expect(player.gold, 2);
    expect(board.cubeCountForNormalDragonAttack(), 4);
    expect(board.dungeonDiscard.length, 1);

    turn.skill = 4;
    game.executeAction(
        turn, UseDevice(cardType: dragonShrine, orEffectIndex: 1));
    expect(player.deck.cardCount, 10); // 10 starter cards.
    player.deck.discardPile.addAll(player.deck.hand);
    player.deck.hand = [];
    game.executeEndOfTurn(turn);
    expect(player.deck.cardCount, 9); // One card gone
  }, skip: 'Dragon Shrine unimplemented');

  test('Apothecary', () {
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var apothecary = cardType('Apothecary');
    // 1 discard -> 3 swords
    addAndPlayCard(game, turn, apothecary.name, orEffectIndex: 0);
    expect(turn.swords, 3);
    expect(player.deck.hand.length, 4);
    expect(player.deck.discardPile.length, 1);
    // 1 discard -> 2 gold
    addAndPlayCard(game, turn, apothecary.name, orEffectIndex: 1);
    expect(player.gold, 2);
    expect(player.deck.hand.length, 3);
    expect(player.deck.discardPile.length, 2);
    // 1 discard -> 1 heart
    board.takeDamage(player.color, 2);
    addAndPlayCard(game, turn, apothecary.name, orEffectIndex: 2);
    expect(board.damageTakenByPlayer(player.color), 9);
    expect(player.deck.hand.length, 2);
    expect(player.deck.discardPile.length, 3);
  }, skip: 'Apothecary unimplemented');
}
