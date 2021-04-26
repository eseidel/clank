import 'package:clank/actions.dart';
import 'package:clank/graph.dart';
import 'package:test/test.dart';
import 'package:clank/clank.dart';
import 'common.dart';

void main() {
  test('consider moves which involve spending health', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1);
    builder.connect(from, to, monsters: 2);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = game.turn;
    turn.boots = 5; // plenty
    turn.swords = 1; // Not enough.
    var generator = ActionGenerator(turn);
    var moves = generator.possibleMoves();
    expect(moves.length, 2); // spend 1 hp, spend 2 hp.
    expect(moves.any((move) => move.spendHealth > 0), true);

    // Can't spend HP when almost dead.
    var hpLeft = board.healthFor(player);
    board.takeDamage(player, hpLeft - 1);
    expect(board.healthFor(player), 1);
    expect(generator.possibleMoves().length, 0); // no hp left to spend!

    board.healDamage(player, 1);
    expect(generator.possibleMoves().length, 1); // spend 1 hp.

    // Can't spend hp if you have no cubes to spend.
    var cubesLeft = board.stashCountFor(player);
    turn.adjustActivePlayerClank(cubesLeft);

    expect(generator.possibleMoves().length, 0); // no cubes to spend!
  });

  test('can traverse one way with teleport', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;
    var turn = game.turn;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1);
    builder.connect(to, from, oneway: true);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    turn.boots = 5;
    expect(ActionGenerator(turn).possibleMoves().length, 0); // one way
    turn.teleports += 1;
    expect(ActionGenerator(turn).possibleMoves().length, 1); // ok to teleport

    // Attempting to use the edge w/o teleport throws:
    expect(
        () => game.executeAction(Traverse(
            edge: from.edges.first, takeItem: false, useTeleport: false)),
        throwsArgumentError);

    // Attempting to spend teleports we don't have throws:
    turn.teleports = 0;
    expect(
        () => game.executeAction(Traverse(
            edge: from.edges.first, takeItem: false, useTeleport: true)),
        throwsArgumentError);
  });

  test('crystal cave exhaustion', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, isCrystalCave: true);
    builder.connect(from, to);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = game.turn;
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn);
    var moves = generator.possibleMoves();
    expect(moves.length, 1); // Move to 'to'
    game.executeAction(moves.first);
    expect(turn.exhausted, isTrue);

    moves = generator.possibleMoves();
    expect(moves.length, 0); // No legal moves, despite having 4 boots.
    expect(turn.boots, 4);

    turn.teleports = 1;
    moves = generator.possibleMoves();
    expect(moves.length, 1); // Teleporting is still possible.
    game.executeAction(moves.first);
    expect(turn.boots, 4);
    expect(turn.exhausted, isTrue);

    moves = generator.possibleMoves();
    expect(moves.length, 0); // Even after teleporting, still exhausted.
    expect(turn.boots, 4);

    addAndPlayCard(game, 'Dead Run');
    expect(turn.exhausted, isFalse);
    expect(turn.boots, 6);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // No longer exhausted!
  });

  test('crystal cave exhaustion after teleport', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, isCrystalCave: true);
    builder.connect(from, to);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = game.turn;
    turn.teleports = 1;
    var generator = ActionGenerator(turn);
    var moves = generator.possibleMoves();
    expect(moves.length, 1); // teleport to 'to' (no boots, can't 'move').
    game.executeAction(moves.first);
    expect(turn.exhausted, isTrue);

    turn.boots = 4;
    moves = generator.possibleMoves();
    expect(moves.length, 0); // No legal moves, despite having 4 boots.
    expect(turn.boots, 4);

    turn.teleports = 1;
    moves = generator.possibleMoves();
    expect(moves.length, 1); // Teleporting is still possible.
    game.executeAction(moves.first);
    expect(turn.boots, 4);
    expect(turn.exhausted, isTrue);

    moves = generator.possibleMoves();
    expect(moves.length, 0); // Even after teleporting again, still exhausted.
    expect(turn.boots, 4);

    addAndPlayCard(game, 'Dead Run');
    expect(turn.exhausted, isFalse);
    expect(turn.boots, 6);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // No longer exhausted!
  });

  test('master key unlocks tunnels', () {
    var game = makeGameWithPlayerCount(1);
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

    var turn = game.turn;
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn);
    var moves = generator.possibleMoves();
    expect(moves.length, 0); // Only available edge requires key.

    turn.player.loot.add(key);
    expect(player.hasMasterKey, isTrue);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // Can now go through edge!
    game.executeAction(moves.first);
    expect(turn.boots, 4);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // And back, key isn't used up.
    expect(player.hasMasterKey, isTrue);
  });

  test('possibleCardPlays', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;

    var turn = game.turn;
    var generator = ActionGenerator(turn);

    player.deck.hand = [];
    var plays = generator.possibleCardPlays();
    expect(plays.length, 0);

    player.deck.hand = box.make('Burgle', 5);
    plays = generator.possibleCardPlays();
    expect(plays.length, 1); // Only consider one play per card type.

    player.deck.hand = box.make('Mister Whiskers', 1);
    plays = generator.possibleCardPlays();
    expect(plays.length, 1); // Even Or types have a single play.

    // player.deck.hand = box.make('Apothecary', 1);
    // plays = generator.possibleCardPlays();
    // expect(plays.length, 1); // Only one play when conditions can't be met.

    // player.deck.hand = box.make('Apothecary', 1);
    // player.deck.hand.addAll(box.make('Burgle', 2));
    // plays = generator.possibleCardPlays();
    // expect(plays.length, 5); // 2 burgle + 3 apothecary options

    // player.deck.hand = box.make('Apothecary', 1);
    // player.deck.hand.addAll(box.make('Burgle', 1));
    // player.deck.hand.addAll(box.make('Stumble', 1));

    // plays = generator.possibleCardPlays();
    // expect(plays.length, 8); // 2 burgle + 2 x 3 apothecary options.
  });

  test('Buy from Market', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var turn = game.turn;
    var player = turn.player;

    expect(ActionGenerator(turn).possibleMarketBuys().length, 0);

    var marketSpace =
        board.graph.allSpaces.firstWhere((space) => space.isMarket);
    player.token.moveTo(marketSpace);

    expect(ActionGenerator(turn).possibleMarketBuys().length, 0); // no gold.
    turn.gainGold(7);
    expect(ActionGenerator(turn).possibleMarketBuys().length, 3);
    var buyAction = ActionGenerator(turn).possibleMarketBuys().first;
    game.executeAction(buyAction);
    expect(player.gold, 0);
    expect(player.loot.first.isMarketItem, isTrue);
  });
}
