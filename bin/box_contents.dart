import 'package:clank/cards.dart';

// These asserts belong on the CardType construtor, but can't currently due to:
//https://github.com/dart-lang/language/issues/312
void sanityAsserts() {
  Set<String> uniqueNames = {};
  for (var cardType in baseSetAllCardTypes) {
    uniqueNames.add(cardType.name);
    assert(cardType.isMonster || cardType.swordsCost == 0);
    assert(!cardType.isDevice || cardType.skillCost > 0);
    assert(cardType.set == CardSet.starter ||
        (cardType.swordsCost > 0 || cardType.skillCost > 0));
  }
  assert(uniqueNames.length == baseSetAllCardTypes.length);
}

void main() {
  sanityAsserts();
  print('${baseSetAllCardTypes.length} card types implemented');

  // 183 total
  // https://boardgamegeek.com/thread/1761044/there-full-list-cards-base-set
  const int maxCards = 183;

  int totalCards =
      baseSetAllCardTypes.fold(0, (sum, cardType) => sum + cardType.count);
  print('generating $totalCards of $maxCards cards');
}
