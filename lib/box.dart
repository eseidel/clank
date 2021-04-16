import 'cards.dart';
import 'graph.dart';

// Maybe this just get merged in with Artifact and MarketItem to be Loot?
enum LootType {
  majorSecret,
  minorSecret,
  artifact,
  market,
  special,
}

class Loot {
  final LootType type;
  final String name;
  final bool usable;
  final int count;
  final int points;
  final int hearts;
  // TODO: This is not true!  Fix.
  // It is detectable that this is "gold" and not "acquireGold" via cards like
  // "Search" which can increase gold gained in a turn, hence you might wish
  // to acquire a gold secret but delay using until played same turn as Search.
  final int gold;
  final int skill;
  final int drawCards;
  final int acquireRage;
  final int boots;
  final int swords;

  const Loot.majorSecret({
    required this.name,
    required this.count,
    this.points = 0,
    this.hearts = 0,
    this.gold = 0,
    this.usable = false,
    this.skill = 0,
    this.drawCards = 0,
  })  : type = LootType.majorSecret,
        boots = 0,
        swords = 0,
        acquireRage = 0;

  const Loot.minorSecret({
    required this.name,
    required this.count,
    this.points = 0,
    this.hearts = 0,
    this.gold = 0,
    this.usable = false,
    this.skill = 0,
    this.drawCards = 0,
    this.acquireRage = 0,
    this.boots = 0,
    this.swords = 0,
  }) : type = LootType.minorSecret;

  const Loot.artifact({
    required this.name,
    required this.points,
  })   : type = LootType.artifact,
        count = 1,
        hearts = 0,
        gold = 0,
        skill = 0,
        drawCards = 0,
        boots = 0,
        swords = 0,
        usable = false,
        acquireRage = 1;

  const Loot.market({
    required this.name,
    required this.count,
    required this.points,
  })   : type = LootType.market,
        hearts = 0,
        gold = 0,
        skill = 0,
        drawCards = 0,
        boots = 0,
        swords = 0,
        usable = false,
        acquireRage = 0;

  const Loot.special({
    required this.name,
    required this.count,
    required this.points,
  })   : type = LootType.special,
        hearts = 0,
        gold = 0,
        skill = 0,
        drawCards = 0,
        boots = 0,
        swords = 0,
        usable = false,
        acquireRage = 0;

  // A bit of a hack.  Crown is the only same-named loot with varying points. :/
  bool get isCrown => name.startsWith('Crown');
  bool get isMonkeyIdol => name == 'Monkey Idol';
  bool get isMasterKey => name == 'Master Key';
  bool get isBackpack => name == 'Backpack';

  @override
  String toString() => name;
}

List<Loot> allLootDescriptions = const [
  // Major Secrets
  Loot.majorSecret(name: 'Chalice', count: 3, points: 7),
  Loot.majorSecret(
      name: 'Potion of Greater Healing', usable: true, count: 2, hearts: 2),
  Loot.majorSecret(name: 'Greater Treasure', usable: true, count: 2, gold: 5),
  Loot.majorSecret(
      name: 'Greater Skill Boost', usable: true, count: 2, skill: 5),
  Loot.majorSecret(
      name: 'Flash of Brilliance', usable: true, count: 2, drawCards: 3),

  // Minor Secrets
  Loot.minorSecret(name: 'Dragon Egg', count: 3, points: 3, acquireRage: 1),
  Loot.minorSecret(
      name: 'Potion of Healing', usable: true, count: 3, hearts: 1),
  Loot.minorSecret(name: 'Treasure', usable: true, count: 3, gold: 2),
  Loot.minorSecret(name: 'Skill Boost', usable: true, count: 3, skill: 2),
  Loot.minorSecret(
      name: 'Potion of Strength', usable: true, count: 2, swords: 2),
  Loot.minorSecret(
      name: 'Potion of Swiftness', usable: true, count: 2, boots: 1),
  // Don't know how to trash yet.
  // Loot.minor(name: 'Magic Spring', count: 2, endOfTurnTrash: 1),

  // Artifacts
  Loot.artifact(name: 'Ring', points: 5),
  Loot.artifact(name: 'Ankh', points: 7),
  Loot.artifact(name: 'Vase', points: 10),
  Loot.artifact(name: 'Bananas', points: 15),
  Loot.artifact(name: 'Shield', points: 20),
  Loot.artifact(name: 'Chestplate', points: 25),
  Loot.artifact(name: 'Thurible', points: 30),

  // Market -- unclear if these belong as Loot?
  // They never have a location on the board.
  // They never use any of the effects secrets do.
  // But they do get counted for points (and physically manifest as tokens).
  Loot.market(name: 'Master Key', count: 2, points: 5),
  Loot.market(name: 'Backpack', count: 2, points: 5),
  Loot.market(name: 'Crown (10)', count: 1, points: 10),
  Loot.market(name: 'Crown (9)', count: 1, points: 9),
  Loot.market(name: 'Crown (8)', count: 1, points: 8),

  Loot.special(name: 'Mastery Token', count: 4, points: 20),
  Loot.special(name: 'Monkey Idol', count: 3, points: 5),
];

// TODO: Merge this with library?
class Box {
  // 7 Artifacts
  // 11 major secrets
  // - 3 challice (7 pts)
  // - 2 2x heart bottles
  // - 2 5 gold
  // - 2 5 skill
  // - 2 flash of brilliance (draw 3)
  // 18 minor secrets
  // - 3 dragon egg (3 points)
  // - 3 heal 1
  // - 3 2 gold
  // - 3 2 skill
  // - 2 2 swords
  // - 2 trash card (at end of turn)
  // - 2 1 boot
  // 2 master keys
  // 2 backpacks
  // 3 crowns
  // 3 monkey idols
  // 4 mastery tokens
  // Gold (81 total)
  // Gold is meant to be unlimited: https://boardgamegeek.com/thread/1729908/article/25115604#25115604
  // - 12 5 gold
  // - 21 1 gold

  Iterable<LootToken> makeAllLootTokens() {
    return allLootDescriptions
        .map((loot) => List.generate(loot.count, (_) => LootToken(loot)))
        .expand((element) => element);
  }

  Loot lootByName(String name) =>
      allLootDescriptions.firstWhere((type) => type.name == name);
}

class Reserve {
  final List<List<Card>> piles;
  Reserve(Library library)
      : piles = [
          library.makeAll('Mercenary'),
          library.makeAll('Explore'),
          library.makeAll('Secret Tome'),
          library.makeAll('Goblin'),
        ];

  Iterable<CardType> get availableCardTypes sync* {
    for (var pile in piles) {
      if (pile.isNotEmpty) yield pile.first.type;
    }
  }

  Card takeCard(CardType cardType) {
    // Goblin is a special hack, and is never discarded.
    if (cardType.neverDiscards) {
      return Card._(cardType);
    }
    for (var pile in piles) {
      if (pile.isNotEmpty && pile.first.type == cardType) {
        return pile.removeLast();
      }
    }
    throw ArgumentError('No cards in reserve of type $cardType');
  }
}

class Card {
  final CardType type;
  // Don't construct this const (would end up sharing instances).
  Card._(this.type);

  String get name => type.name;
  int get skill => type.skill;
  int get boots => type.boots;
  int get swords => type.swords;

  int get clank => type.clank;
  int get points => type.points;

  @override
  String toString() => type.name;
}

class Library {
  CardType cardTypeByName(String name) =>
      baseSetAllCardTypes.firstWhere((type) => type.name == name);

  List<Card> make(String name, int amount) =>
      List.generate(amount, (_) => Card._(cardTypeByName(name)));

  List<Card> makeAll(String name) {
    var type = cardTypeByName(name);
    return List.generate(type.count, (_) => Card._(type));
  }

  Iterable<Card> makeDungeonDeck() {
    var dungeonTypes =
        baseSetAllCardTypes.where((type) => type.set == CardSet.dungeon);
    var dungeonCardLists = dungeonTypes
        .map((type) => List.generate(type.count, (_) => Card._(type)));
    return dungeonCardLists.expand((element) => element);
  }
}

class LootToken extends Token {
  Loot loot;
  LootToken(this.loot);

  bool get isArtifact => loot.type == LootType.artifact;
  bool get isMinorSecret => loot.type == LootType.minorSecret;
  bool get isMajorSecret => loot.type == LootType.majorSecret;
  bool get isMonkeyIdol => loot.isMonkeyIdol;
  bool get isMasterKey => loot.isMasterKey;
  bool get isBackpack => loot.isBackpack;
  bool get isCrown => loot.isCrown;

  int get points => loot.points;

  @override
  String toString() => loot.toString();
}
