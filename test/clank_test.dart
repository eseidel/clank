import 'dart:math';

import 'package:clank/clank.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

void main() {
  Library library = Library();

  test('deck shuffles when empty', () {
    PlayerDeck deck = PlayerDeck();
    expect(deck.cardCount, 0);
    expect(() => deck.discardPlayAreaAndDrawNewHand(Random(0), 1),
        throwsArgumentError);
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
    var game = ClankGame(planners: [MockPlanner()]);
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
