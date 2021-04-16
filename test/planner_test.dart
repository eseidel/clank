import 'package:clank/actions.dart';
import 'package:clank/box.dart';
import 'package:clank/clank.dart';
import 'package:clank/graph.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

void main() {
  Library library = Library();

  ClankGame makeGameWithPlayerCount(int count) {
    return ClankGame(
        planners: List.generate(count, (index) => MockPlanner()), seed: 10);
  }

  void addAndPlayCard(ClankGame game, Turn turn, String name,
      {int? orEffectIndex}) {
    var card = library.make(name, 1).first;
    turn.player.deck.hand.add(card);
    game.executeAction(turn, PlayCard(card.type, orEffectIndex: orEffectIndex));
  }

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

  test('possibleCardPlays', () {
    var game = makeGameWithPlayerCount(1);
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
}
