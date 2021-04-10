import 'dart:math';

import 'package:clank/clank.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

void main() {
  Library library = Library();

  test('deck shuffles when empty', () {
    Deck deck = Deck();
    expect(deck.cardCount, 0);
    expect(() => deck.discardPlayAreaAndDrawNewHand(Random(0), 1),
        throwsArgumentError);
    deck.add(library.make('Burgle'));
    expect(deck.cardCount, 1);
    deck.addAll(library.makeCards('Burgle', 5));
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
}
