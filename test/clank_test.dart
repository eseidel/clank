import 'dart:math';

import 'package:clank/actions.dart';
import 'package:clank/clank.dart';
import 'package:clank/graph.dart';
import 'package:test/test.dart';
import 'common.dart';

void main() {
  test('deck shuffles when empty', () {
    PlayerDeck deck = PlayerDeck();
    expect(deck.cardCount, 0);
    expect(deck.discardPlayAreaAndDrawNewHand(Random(0), 1), 0);
    deck.addAll(box.make('Burgle', 1));
    expect(deck.cardCount, 1);
    deck.addAll(box.make('Burgle', 5));
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
    var game = makeGameWithPlayerCount(1);
    expect(game.players.length, 1);
    expect(game.players.first.deck.cardCount, 10);
  });

  test('clank damage cubes', () {
    var board = Board();
    expect(board.damageTakenByPlayer(PlayerColor.blue), 0);
    expect(board.healthForPlayer(PlayerColor.blue), 10);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 30);
    board.takeDamageForPlayer(PlayerColor.blue, 2);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 2);
    expect(board.healthForPlayer(PlayerColor.blue), 8);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 28);
    board.healDamageForPlayer(PlayerColor.blue, 1);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 1);
    expect(board.healthForPlayer(PlayerColor.blue), 9);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 29);
    board.healDamageForPlayer(PlayerColor.blue, 2);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 0);
    expect(board.healthForPlayer(PlayerColor.blue), 10);
    expect(board.playerCubeStashes.countFor(PlayerColor.blue), 30);

    board.adjustClankForPlayer(PlayerColor.blue, 30);
    board.moveDragonAreaToBag();
    // Not valid to try to take damage with no cubes (should check first).
    expect(() => board.takeDamageForPlayer(PlayerColor.blue, 2),
        throwsArgumentError);
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
    var game = makeGameWithPlayerCount(1);
    var turn = game.turn;
    expect(game.board.clankArea.totalPlayerCubes, 0);
    addAndPlayCard(game, 'Stumble');
    expect(turn.leftoverClankReduction, 0);
    expect(game.board.clankArea.totalPlayerCubes, 1);

    addAndPlayCard(game, 'Move Silently');
    expect(turn.leftoverClankReduction, -1);
    expect(game.board.clankArea.totalPlayerCubes, 0);
  });

  test('drawCards edgecase', () {
    PlayerDeck deck = PlayerDeck(cards: box.make('Burgle', 3));
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
    var game = makeGameWithPlayerCount(1);
    Board board = game.board;
    var turn = game.turn;
    var player = turn.player;
    expect(board.clankArea.totalPlayerCubes, 0);
    expect(board.stashCountFor(player), 30);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, 0);
    turn.adjustActivePlayerClank(2);
    expect(board.stashCountFor(player), 28);
    expect(board.clankAreaCountFor(player), 2);
    expect(turn.leftoverClankReduction, 0);

    // Running out of clank in stash:
    // stash: 0, area: 30, leftover: 0, new: +2 -> stash: 0, area: 30, leftover: 0
    game = makeGameWithPlayerCount(1);
    board = game.board;
    turn = game.turn;
    player = turn.player;
    turn.adjustActivePlayerClank(30);
    expect(board.stashCountFor(player), 0);
    expect(board.clankAreaCountFor(player), 30);
    expect(turn.leftoverClankReduction, 0);

    // Can't add clank once run out:
    turn.adjustActivePlayerClank(2);
    expect(board.stashCountFor(player), 0);
    expect(board.clankAreaCountFor(player), 30);
    expect(turn.leftoverClankReduction, 0);

    // Negative clank pulls back from clank area:
    // stash: 0, area: 30, leftover: 0, new: -2 -> stash: 2, area: 28, leftover: 0
    turn.adjustActivePlayerClank(-2);
    expect(board.stashCountFor(player), 2);
    expect(board.clankAreaCountFor(player), 28);
    expect(turn.leftoverClankReduction, 0);

    // Negative clank accumulates when area empty:
    // stash: 30, area: 0, leftover: 0, new: -2 -> stash: 30, area: 0, leftover: -2
    game = makeGameWithPlayerCount(1);
    board = game.board;
    turn = game.turn;
    player = turn.player;
    turn.adjustActivePlayerClank(-2);
    expect(board.stashCountFor(player), 30);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, -2);
    turn.adjustActivePlayerClank(-2);
    expect(board.stashCountFor(player), 30);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, -4);

    // Adding clank reduces accumlated negative:
    // stash: 30, area: 0, leftover: -4, new: 2 -> stash: 30, area: 0, leftover: -2
    turn.adjustActivePlayerClank(2);
    expect(board.stashCountFor(player), 30);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, -2);

    // Adding clank can take you back positive:
    // stash: 30, area: 0, leftover: -2, new: 3 -> stash: 29, area: 1, leftover: 0
    turn.adjustActivePlayerClank(3);
    expect(board.stashCountFor(player), 29);
    expect(board.clankAreaCountFor(player), 1);
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
    game = makeGameWithPlayerCount(1);
    board = game.board;
    turn = game.turn;
    player = turn.player;
    turn.adjustActivePlayerClank(30);
    board.moveDragonAreaToBag();
    expect(board.stashCountFor(player), 0);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, 0);
    turn.adjustActivePlayerClank(-2);
    expect(board.stashCountFor(player), 0);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, -2);
    // Adding clank here could be blocked for two reasons, either due to
    // no cubes in stash or negative leftover.
    turn.adjustActivePlayerClank(2);
    expect(board.stashCountFor(player), 0);
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, 0); // -2 would also be reasonable.
  });

  test('drawCards effect', () {
    var game = makeGameWithPlayerCount(1);
    var turn = game.turn;
    var player = turn.player;
    expect(turn.hand.length, 5);
    addAndPlayCard(game, 'Diamond'); // adds Diamond, plays = draw 1
    expect(player.deck.playArea.length, 1);
    expect(turn.hand.length, 6);
    addAndPlayCard(game, 'Brilliance'); // draw 3
    expect(player.deck.playArea.length, 2);
    expect(turn.hand.length, 9);
    expect(player.deck.drawPile.length, 1);
    expect(player.deck.discardPile.length, 0);
    addAndPlayCard(game, 'Brilliance'); // draw 3
    expect(player.deck.playArea.length, 3);
    expect(player.deck.drawPile.length, 0);
    expect(turn.hand.length, 10);
  });

  test('gainGold effect', () {
    var game = makeGameWithPlayerCount(1);
    var turn = game.turn;
    var player = turn.player;
    expect(player.gold, 0);
    expect(turn.hand.length, 5);
    addAndPlayCard(game, 'Pickaxe'); // gain 2 gold
    expect(turn.hand.length, 5);
    expect(player.deck.playArea.length, 1);
    expect(player.gold, 2);
    addAndPlayCard(game, 'Treasure Map'); // gain 5 gold
    expect(turn.hand.length, 5);
    expect(player.deck.playArea.length, 2);
    expect(player.gold, 7);
  });

  test('dragon attack rage cube count', () {
    var twoPlayer = makeGameWithPlayerCount(2);
    twoPlayer.board.dungeonRow = []; // Remove any danger cards.
    var threePlayer = makeGameWithPlayerCount(3);
    threePlayer.board.dungeonRow = []; // Remove any danger cards.
    var fourPlayer = makeGameWithPlayerCount(4);
    fourPlayer.board.dungeonRow = []; // Remove any danger cards.

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
    var twoPlayer = makeGameWithPlayerCount(2);
    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 3);
    twoPlayer.board.dungeonRow = box.make('Kobold', 1);
    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 4);
    twoPlayer.board.dungeonRow = box.make('Kobold', 2);
    expect(twoPlayer.board.cubeCountForNormalDragonAttack(), 5);
  });

  test('acquireClank effect', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    board.dungeonRow.addAll(box.make('Emerald', 1));
    var emerald = board.dungeonRow.last.type;
    var turn = game.turn;
    turn.skill = emerald.skillCost;
    expect(board.clankArea.totalPlayerCubes, 0);
    game.executeAction(AcquireCard(cardType: emerald));
    expect(board.clankArea.totalPlayerCubes, 2);
  });

  test('acquireSwords effect', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    board.dungeonRow.addAll(box.make('Silver Spear', 1));
    var silverSpear = board.dungeonRow.last.type;
    var turn = game.turn;
    turn.skill = silverSpear.skillCost;
    expect(turn.swords, 0);
    game.executeAction(AcquireCard(cardType: silverSpear));
    expect(turn.swords, 1);
  });

  test('acquireBoots effect', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    board.dungeonRow.addAll(box.make('Boots of Swiftness', 1));
    var bootsOfSwiftness = board.dungeonRow.last.type;
    var turn = game.turn;
    turn.skill = bootsOfSwiftness.skillCost;
    expect(turn.boots, 0);
    game.executeAction(AcquireCard(cardType: bootsOfSwiftness));
    expect(turn.boots, 1);
  });

  test('acquireHearts effect', () {
    var game = makeGameWithPlayerCount(1);
    var turn = game.turn;
    var player = turn.player;

    var board = game.board;
    board.dungeonRow.addAll(box.make('Amulet of Vigor', 2));
    var amuletOfVigor = board.dungeonRow.last.type;

    // Does nothing if you haven't taken damage.
    expect(board.damageTakenBy(player), 0);
    turn.skill = amuletOfVigor.skillCost;
    game.executeAction(AcquireCard(cardType: amuletOfVigor));
    expect(board.damageTakenBy(player), 0);

    // But heals one on acquire if you have.
    board.takeDamage(player, 2);
    expect(board.damageTakenBy(player), 2);
    turn.skill = amuletOfVigor.skillCost;
    game.executeAction(AcquireCard(cardType: amuletOfVigor));
    expect(board.damageTakenBy(player), 1);
  });

  test('negative clank', () {
    var game = makeGameWithPlayerCount(1);
    var turn = game.turn;
    expect(game.board.clankArea.totalPlayerCubes, 0);
    addAndPlayCard(game, 'Stumble');
    expect(turn.leftoverClankReduction, 0);
    expect(game.board.clankArea.totalPlayerCubes, 1);

    addAndPlayCard(game, 'Move Silently');
    expect(turn.leftoverClankReduction, -1);
    expect(game.board.clankArea.totalPlayerCubes, 0);
  });

  test('dragon reveal causes attack', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    // Refill works, dragonRevealed is false for non-dragon cards.
    board.dungeonRow = [];
    board.dungeonDeck = box.make('Move Silently', 6); // no dragon
    bool dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, false);
    expect(board.dungeonRow.length, 6);

    // Revealing a dragon shows dragonRevealed (also testing partial refill)
    board.dungeonRow.removeRange(0, 3);
    board.dungeonDeck = box.make('MonkeyBot 3000', 1); // dragon!
    dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, true);
    expect(board.dungeonRow.length, 4);

    board.dungeonDeck = box.make('MonkeyBot 3000', 1); // dragon!
    dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, true);
    expect(board.dungeonRow.length, 5);

    board.dungeonDeck = box.make('Move Silently', 6); // no dragon
    dragonRevealed = board.refillDungeonRow().dragonAttacks;
    expect(dragonRevealed, false);
    expect(board.dungeonRow.length, 6);
  });

  test('arriveClank effect', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    // Refill works, dragonRevealed is false for non-dragon cards.
    board.dungeonRow = [];
    board.dungeonDeck = box.make('Overlord', 1); // arrival clank, no dragon
    ArrivalTriggers triggers = board.refillDungeonRow();
    expect(triggers.dragonAttacks, false);
    expect(triggers.clankForAll, 1);
    expect(board.dungeonRow.length, 1);

    board.dungeonDeck = box.make('Overlord', 2); // arrival clank, no dragon
    triggers = board.refillDungeonRow();
    expect(triggers.dragonAttacks, false);
    expect(triggers.clankForAll, 2);
    expect(board.dungeonRow.length, 3);
  });

  test('arrival effects happen before dragon attack', () {
    var game = makeGameWithPlayerCount(2);
    var board = game.board;
    board.dungeonRow = [];
    board.dungeonDeck = box.make('Overlord', 1); // arrival clank, no dragon
    expect(board.clankArea.totalPlayerCubes, 0);
    game.activePlayer.deck.hand = []; // avoid assert in executeEndOfTurn.
    game.executeEndOfTurn();
    expect(board.clankArea.totalPlayerCubes, 2);
    expect(board.dungeonRow.length, 1);

    board.dungeonDeck = box.make('Overlord', 1); // arrival clank, no dragon
    board.dungeonDeck.addAll(box.make('Animated Door', 1)); // dragon!
    game.activePlayer.deck.hand = []; // avoid assert in executeEndOfTurn.
    game.executeEndOfTurn();
    expect(board.clankArea.totalPlayerCubes, 0);
    // 24 dragon cubes + 2 from each overlord, per player = 28
    // Dragon attack: 3 cubes for 2 players, 28 - 3 = 25.
    expect(board.dragonBag.totalCubes, 25);
  });

  test('canTakeArtifact', () {
    var game = makeGameWithPlayerCount(1);
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
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    board.dungeonRow = box.make('Kobold', 1);
    var turn = game.turn;
    turn.swords = 1;
    game.executeAction(Fight(cardType: board.dungeonRow.first.type));
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 0);
    expect(turn.skill, 1);
    expect(turn.swords, 0);
  });

  test('use device', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    board.dungeonRow = box.make('Ladder', 1);
    var turn = game.turn;
    turn.skill = 3;
    game.executeAction(UseDevice(cardType: board.dungeonRow.first.type));
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 0);
    expect(turn.boots, 2);
    expect(turn.skill, 0);
  });

  test('zero score if knocked out in depths', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    expect(game.pointsForPlayer(player), 0);
    player.setGoldWithoutEffects(5);
    expect(game.pointsForPlayer(player), 5);
    player.status = PlayerStatus.knockedOut;
    expect(game.pointsForPlayer(player), 5);
    player.token.location = Space.depths(0, 0);
    expect(game.pointsForPlayer(player), 0);
  });

  test('picking up an artifact increases dragon rage', () {
    var game = makeGameWithPlayerCount(2);
    var player = game.activePlayer;
    var turn = game.turn;
    turn.boots = 5; // plenty.
    var artifactRoom = game.board.graph.allSpaces
        .firstWhere((space) => space.expectedArtifactValue > 0);
    var edge = artifactRoom.edges.first.end.edges
        .firstWhere((edge) => edge.end == artifactRoom);
    expect(player.hasArtifact, false);
    int initialRage = game.board.rageIndex;
    game.executeAction(Traverse(edge: edge, takeItem: true));
    expect(player.hasArtifact, true);
    expect(game.board.rageIndex, initialRage + 1);
  });

  test('cubes are not duplicated', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;

    addAndPlayCard(game, 'Stumble');
    expect(board.stashCountFor(player), 29);
    expect(board.clankAreaCountFor(player), 1);
    board.dungeonRow = [];
    board.dungeonDeck = box.make('Orc Grunt', 1);
    board.dragonBag.dragonCubesLeft = 0;
    player.deck.hand = [];
    game.executeEndOfTurn();
    expect(board.healthFor(player), 9);
    expect(board.clankAreaCountFor(player), 0);
    expect(board.bagCountFor(player), 0);
    expect(board.stashCountFor(player), 29);
  });

  test('fighting goblin', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;

    var goblin = box.cardTypeByName('Goblin');
    var turn = game.turn;
    turn.swords = 4;
    expect(player.gold, 0);
    expect(board.availableCardTypes.contains(goblin), isTrue);
    game.executeAction(Fight(cardType: goblin));
    expect(turn.swords, 2);
    expect(player.gold, 1);
    expect(board.availableCardTypes.contains(goblin), isTrue);
    // It's possible to fight the goblin repeatedly.
    game.executeAction(Fight(cardType: goblin));
    expect(turn.swords, 0);
    expect(player.gold, 2);
    expect(board.availableCardTypes.contains(goblin), isTrue);
    // And it's never discarded (per the rules)
    expect(board.dungeonDiscard, isEmpty);
  });

  test('using items', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var allItems = game.box.makeAllLootTokens();
    var turn = game.turn;
    void addItemAndUse(String name) {
      var item = allItems.firstWhere((item) => item.loot.name == name);
      player.loot.add(item);
      game.executeAction(UseItem(item: item.loot));
    }

    game.board.takeDamage(player, 9);
    expect(game.board.damageTakenBy(player), 9);
    addItemAndUse('Potion of Greater Healing');
    expect(game.board.damageTakenBy(player), 7);
    addItemAndUse('Potion of Healing');
    expect(game.board.damageTakenBy(player), 6);
    addItemAndUse('Potion of Strength');
    expect(turn.swords, 2);
    addItemAndUse('Potion of Swiftness');
    expect(turn.boots, 1);
    expect(player.loot, isEmpty);
    expect(game.board.usedItems.length, 4);
  });

  test('discardImmediately items', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var allItems = game.box.makeAllLootTokens();
    var turn = game.turn;
    var board = game.board;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1);
    builder.connect(from, to);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    void takeItem(String name) {
      turn.boots += 1;
      player.token.moveTo(from);
      var item = allItems.firstWhere((item) => item.loot.name == name);
      item.moveTo(to);
      game.executeAction(Traverse(edge: from.edges.first, takeItem: true));
    }

    expect(turn.skill, 0);
    expect(player.loot, isEmpty);
    takeItem('Greater Skill Boost');
    expect(turn.skill, 5);
    expect(player.loot, isEmpty);

    takeItem('Skill Boost');
    expect(turn.skill, 7);
    expect(player.loot, isEmpty);

    expect(player.gold, 0);
    takeItem('Greater Treasure');
    expect(player.gold, 5);
    expect(player.loot, isEmpty); // Implementing gold as a number, not tokens.

    takeItem('Treasure');
    expect(player.gold, 7);
    expect(player.loot, isEmpty); // Implementing gold as a number, not tokens.

    expect(turn.hand.length, 5);
    takeItem('Flash of Brilliance');
    expect(turn.hand.length, 8);
    expect(player.loot, isEmpty);

    player.deck.hand = fiveUniqueCards(); // replace 8c hand with 5 unique cards
    expect(turn.cardTypesInDiscardAndPlayArea.length, 0);
    expect(player.deck.cardCount, 7); // 5 unique in hand, only 2 left in draw
    takeItem('Magic Spring');
    player.deck.discardHand();
    executeChoice(game, 1, expectedChoiceCount: 5); // unique types = 5 choices
    game.executeEndOfTurn();
    expect(player.deck.cardCount, 6);
  });

  test('conditional points effects', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();

    void addCard(String name) {
      var card = box.make(name, 1).first;
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
    player.setGoldWithoutEffects(5);
    expect(game.pointsForPlayer(player), 54);
    player.setGoldWithoutEffects(7);
    expect(game.pointsForPlayer(player), 56);
    player.setGoldWithoutEffects(10);
    expect(game.pointsForPlayer(player), 60);
  });

  test('Exiting dungeon awards mastery token', () {
    var game = makeGameWithPlayerCount(1);
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
    var turn = game.turn;
    turn.boots = 1;
    // Regardless of takeItem, a Mastery Token is awarded.
    game.executeAction(Traverse(edge: edge, takeItem: false));
    player.hasLoot(game.box.lootByName('Mastery Token'));
    expect(game.pointsForPlayer(player), 50); // 30 + 20 for token.
    game.updatePlayerStatuses();
    // Previously points depended on inGame status, ensure it doesn't:
    expect(game.pointsForPlayer(player), 50);
    expect(player.inGame, isFalse);
  });

  test('teleport', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var board = game.board;
    board.dungeonRow = box.make('Teleporter', 1);
    var turn = game.turn;
    turn.skill = 4;
    turn.boots = 3;
    expect(turn.teleports, 0);
    // Test use-device teleports
    game.executeAction(UseDevice(cardType: board.dungeonRow.first.type));
    expect(turn.teleports, 1);
    // Play card teleports work too
    addAndPlayCard(game, 'Invoker of the Ancients');
    expect(turn.teleports, 2);

    var edge = player.location.edges.first;
    game.executeAction(
        Traverse(edge: edge, takeItem: false, useTeleport: true));
    expect(turn.teleports, 1);
    expect(turn.boots, 3);
  });

  test('initial dungeon row can trigger arrival clank', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    expect(board.clankArea.totalPlayerCubes, 0); // Random seed has none.

    board.dungeonDeck = game.box.make('Watcher', 6);
    board.dungeonRow = [];
    var triggers = board.fillDungeonRowFirstTimeReplacingDragons(Random());
    expect(triggers.clankForAll, 6); // Arrival clank triggers.
  });

  test('unique values', () {
    var game = makeGameWithPlayerCount(1);
    game.board.dungeonRow = game.box.make('Master Burglar', 3);
    expect(game.board.availableCardTypes.length, 5); // 1 for row, 4 on reserve.
  });

  test('arriveReturnDragonCubes effect', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;

    board.dungeonRow = [];

    expect(board.dragonBag.dragonCubesLeft, 24);
    board.dungeonDeck = box.make('Shrine', 1);
    ArrivalTriggers triggers = board.refillDungeonRow();
    expect(board.dungeonRow.length, 1);
    game.executeArrivalTriggers(triggers);
    expect(triggers.refillDragonCubes, 3);
    expect(board.dragonBag.dragonCubesLeft, 24);

    board.dragonBag.dragonCubesLeft = 10;
    board.dungeonDeck = box.make('Shrine', 1);
    triggers = board.refillDungeonRow();
    expect(board.dungeonRow.length, 2);
    game.executeArrivalTriggers(triggers);
    expect(triggers.refillDragonCubes, 3);
    expect(board.dragonBag.dragonCubesLeft, 13);

    board.dragonBag.dragonCubesLeft = 10;
    board.dungeonDeck = box.make('Shrine', 2);
    triggers = board.refillDungeonRow();
    expect(board.dungeonRow.length, 4);
    game.executeArrivalTriggers(triggers);
    expect(triggers.refillDragonCubes, 6);
    expect(board.dragonBag.dragonCubesLeft, 16);
  });

  test('availableMarketItemTypes', () {
    var game = makeGameWithPlayerCount(1);
    expect(game.board.marketItems.length, 7);
    var types = game.board.availableMarketItemTypes;
    expect(types.length, 3);
    expect(types.any((t) => t.isBackpack), isTrue);
    expect(types.any((t) => t.isMasterKey), isTrue);
    expect(types.any((t) => t.isCrown), isTrue);
    var crown = types.firstWhere((t) => t.isCrown);
    expect(crown.points, 10);

    game.board.marketItems = [];
    expect(game.board.availableMarketItemTypes, isEmpty);
  });

  test('key lets you pass through locked tunnels', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var turn = game.turn;
    var player = turn.player;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1);
    builder.connect(from, to, requiresKey: true);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    expect(ActionGenerator(turn).possibleMoves().length, 0);
    turn.boots = 1;
    expect(
        () => game
            .executeAction(Traverse(edge: from.edges.first, takeItem: false)),
        throwsArgumentError);
    expect(ActionGenerator(turn).possibleMoves().length, 0); // Boots but no key
    player.loot.add(board.marketItems.firstWhere((token) => token.isMasterKey));
    expect(ActionGenerator(turn).possibleMoves().length, 1);
  });

  test('backpack allows additional artifacts', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var turn = game.turn;
    var player = turn.player;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, special: Special.artifact);
    builder.connect(from, to);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    var allTokens = box.makeAllLootTokens();
    player.loot.add(allTokens.firstWhere((token) => token.isArtifact));
    var artifact = allTokens.firstWhere((token) => token.isArtifact);
    artifact.moveTo(to);

    turn.boots = 10; // plenty
    var moves = ActionGenerator(turn).possibleMoves();
    expect(moves.length, 1);
    expect(player.canTakeArtifact, false);
    expect(moves.first.takeItem, false); // We don't have space for another.
    expect(
        () => game
            .executeAction(Traverse(edge: from.edges.first, takeItem: true)),
        throwsArgumentError); // attempted take throws.

    // Reset after exeception:
    player.token.moveTo(from);
    player.loot.add(allTokens.firstWhere((token) => token.isBackpack));
    expect(player.canTakeArtifact, true);
    moves = ActionGenerator(turn).possibleMoves();
    expect(moves.length, 1);
    expect(moves.first.takeItem, true); // We now have space!
    game.executeAction(Traverse(edge: from.edges.first, takeItem: true));
    expect(player.loot.where((loot) => loot.isArtifact).length, 2);
  });
}
