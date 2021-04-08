import 'dart:math';

import 'package:clank/clank.dart';
import 'package:test/test.dart';

void main() {
  test('deck shuffles when empty', () {
    Deck deck = Deck();
    expect(deck.cardCount, 0);
    expect(() => deck.discardPlayAreaAndDrawNewHand(Random(0), 1),
        throwsArgumentError);
    deck.add(Card());
    expect(deck.cardCount, 1);
    deck.addAll(List.generate(5, (_) => Card()));
    expect(deck.cardCount, 6);
    expect(deck.hand.length, 0);
    expect(deck.discardPile.length, 6);
    expect(deck.drawPile.length, 0);
    deck.discardPlayAreaAndDrawNewHand(Random(0));
    expect(deck.hand.length, 5);
    expect(deck.discardPile.length, 0);
    expect(deck.drawPile.length, 1);
  });
}
