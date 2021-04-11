import 'dart:math';

import 'package:clank/clank.dart';
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
    board.takeDamage(PlayerColor.blue, 2);
    expect(board.damageTakenByPlayer(PlayerColor.blue), 2);
    expect(board.healthForPlayer(PlayerColor.blue), 8);
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
    expect(game.board.clankArea.totalCubes, 0);
    addAndPlayCard(game, turn, 'Stumble');
    expect(turn.leftoverClankReduction, 0);
    expect(game.board.clankArea.totalCubes, 1);

    addAndPlayCard(game, turn, 'Move Silently');
    expect(turn.leftoverClankReduction, -1);
    expect(game.board.clankArea.totalCubes, 0);
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

  test('acquireClank effect', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    board.dungeonRow.addAll(library.make('Emerald', 1));
    var emerald = board.dungeonRow.last.type;
    Turn turn = Turn(player: game.players.first);
    turn.skill = emerald.skillCost; // Enough for Emerald
    expect(board.clankArea.totalCubes, 0);
    game.executeAction(turn, Purchase(cardType: emerald));
    expect(board.clankArea.totalCubes, 2);
  });

  test('negative clank', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var stumble = library.cardTypeByName('Stumble');
    Turn turn = Turn(player: game.players.first);
    expect(game.board.clankArea.totalCubes, 0);
    game.executeCardClank(turn, stumble);
    expect(turn.leftoverClankReduction, 0);
    expect(game.board.clankArea.totalCubes, 1);

    var moveSilently = library.cardTypeByName('Move Silently');
    game.executeCardClank(turn, moveSilently);
    expect(turn.leftoverClankReduction, 1);
    expect(game.board.clankArea.totalCubes, 0);
  });
}
