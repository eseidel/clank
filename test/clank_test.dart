import 'dart:math';

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

  void addAndPlayCard(ClankGame game, Turn turn, String name) {
    var card = library.make(name, 1).first;
    turn.player.deck.hand.add(card);
    game.executeAction(turn, PlayCard(card.type));
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
    var game = ClankGame(planners: [MockPlanner()], seed: 0);
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
    ClankGame game = ClankGame(planners: [MockPlanner()]);
    Board board = game.board;
    var player = game.players.first;
    Turn turn = Turn(player: player);
    expect(stashClankCount(board, player), 30);
    expect(areaClankCount(board, player), 0);
    expect(turn.leftoverClankReduction, 0);
    turn.adjustClank(board, 2);
    expect(stashClankCount(board, player), 28);
    expect(areaClankCount(board, player), 2);
    expect(turn.leftoverClankReduction, 0);

    // Running out of clank in stash:
    // stash: 0, area: 30, leftover: 0, new: +2 -> stash: 0, area: 30, leftover: 0
    game = ClankGame(planners: [MockPlanner()]);
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
    game = ClankGame(planners: [MockPlanner()]);
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
    game = ClankGame(planners: [MockPlanner()]);
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
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    board.dungeonRow.addAll(library.make('Emerald', 1));
    var emerald = board.dungeonRow.last.type;
    Turn turn = Turn(player: game.players.first);
    turn.skill = emerald.skillCost;
    expect(board.clankArea.totalPlayerCubes, 0);
    game.executeAction(turn, Purchase(cardType: emerald));
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
    game.executeAction(turn, Purchase(cardType: silverSpear));
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
    game.executeAction(turn, Purchase(cardType: bootsOfSwiftness));
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
    game.executeAction(turn, Purchase(cardType: amuletOfVigor));
    expect(board.damageTakenByPlayer(player.color), 0);

    // But heals one on acquire if you have.
    board.takeDamage(player.color, 2);
    expect(board.damageTakenByPlayer(player.color), 2);
    turn.skill = amuletOfVigor.skillCost;
    game.executeAction(turn, Purchase(cardType: amuletOfVigor));
    expect(board.damageTakenByPlayer(player.color), 1);
  });

  test('negative clank', () {
    var game = ClankGame(planners: [MockPlanner()]);
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
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()]);
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
    player.loot = [ArtifactToken(Artifact.all.first)];
    expect(player.canTakeArtifact, false);
    // TODO: Test other loot doesn't confuse canTakeArtifact.
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
    expect(player.calculateTotalPoints(), 0);
    player.gold = 5;
    expect(player.calculateTotalPoints(), 5);
    player.status = PlayerStatus.knockedOut;
    expect(player.calculateTotalPoints(), 5);
    player.token.location = Space.depths(0, 0);
    expect(player.calculateTotalPoints(), 0);
  });
}
