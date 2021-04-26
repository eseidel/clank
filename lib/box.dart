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

enum LootMode {
  keep,
  canUse,
  // Some secrets take action on acquire and immediately discard.
  // Players have no choice as to when to use them:
  // https://boardgamegeek.com/thread/1740275/article/25266676#25266676
  discardImmediately,
}

class Loot implements EffectSource {
  final LootType type;
  final String name;
  final LootMode mode;
  final int count;
  final int points;
  final int boots;
  final int swords;
  final int hearts;
  final int acquireGold;
  final int acquireSkill;
  final int acquireDrawCards;
  final int acquireRage;
  final Effect? acquireQueuedEffect;

  const Loot.majorSecret({
    required this.name,
    required this.count,
    this.points = 0,
    this.hearts = 0,
    this.acquireGold = 0,
    this.mode = LootMode.discardImmediately,
    this.acquireSkill = 0,
    this.acquireDrawCards = 0,
  })  : type = LootType.majorSecret,
        boots = 0,
        swords = 0,
        acquireRage = 0,
        acquireQueuedEffect = null;

  const Loot.minorSecret({
    required this.name,
    required this.count,
    this.points = 0,
    this.hearts = 0,
    this.acquireGold = 0,
    this.mode = LootMode.discardImmediately,
    this.acquireSkill = 0,
    this.acquireDrawCards = 0,
    this.acquireRage = 0,
    this.boots = 0,
    this.swords = 0,
    this.acquireQueuedEffect,
  }) : type = LootType.minorSecret;

  const Loot.artifact({
    required this.name,
    required this.points,
  })   : type = LootType.artifact,
        count = 1,
        hearts = 0,
        acquireGold = 0,
        acquireSkill = 0,
        acquireDrawCards = 0,
        boots = 0,
        swords = 0,
        mode = LootMode.keep,
        acquireRage = 1,
        acquireQueuedEffect = null;

  const Loot.market({
    required this.name,
    required this.count,
    required this.points,
  })   : type = LootType.market,
        hearts = 0,
        acquireGold = 0,
        acquireSkill = 0,
        acquireDrawCards = 0,
        boots = 0,
        swords = 0,
        mode = LootMode.keep,
        acquireRage = 0,
        acquireQueuedEffect = null;

  const Loot.special({
    required this.name,
    required this.count,
    required this.points,
  })   : type = LootType.special,
        hearts = 0,
        acquireGold = 0,
        acquireSkill = 0,
        acquireDrawCards = 0,
        boots = 0,
        swords = 0,
        mode = LootMode.keep,
        acquireRage = 0,
        acquireQueuedEffect = null;

  // A bit of a hack.  Crown is the only same-named loot with varying points. :/
  bool get isCrown => name.startsWith('Crown');
  bool get isMonkeyIdol => name == 'Monkey Idol';
  bool get isMasterKey => name == 'Master Key';
  bool get isBackpack => name == 'Backpack';

  bool get isUsable => mode == LootMode.canUse;
  bool get discardImmediately => mode == LootMode.discardImmediately;

  @override
  String toString() => name;
}

List<Loot> allLootDescriptions = const [
  // Major Secrets
  Loot.majorSecret(name: 'Chalice', count: 3, points: 7, mode: LootMode.keep),
  Loot.majorSecret(
      name: 'Potion of Greater Healing',
      mode: LootMode.canUse,
      count: 2,
      hearts: 2),
  Loot.majorSecret(name: 'Greater Treasure', count: 2, acquireGold: 5),
  Loot.majorSecret(name: 'Greater Skill Boost', count: 2, acquireSkill: 5),
  Loot.majorSecret(name: 'Flash of Brilliance', count: 2, acquireDrawCards: 3),

  // Minor Secrets
  Loot.minorSecret(
      name: 'Dragon Egg',
      count: 3,
      points: 3,
      acquireRage: 1,
      mode: LootMode.keep),
  Loot.minorSecret(name: 'Treasure', count: 3, acquireGold: 2),
  Loot.minorSecret(name: 'Skill Boost', count: 3, acquireSkill: 2),
  Loot.minorSecret(
      name: 'Potion of Healing', mode: LootMode.canUse, count: 3, hearts: 1),
  Loot.minorSecret(
      name: 'Potion of Strength', mode: LootMode.canUse, count: 2, swords: 2),
  Loot.minorSecret(
      name: 'Potion of Swiftness', mode: LootMode.canUse, count: 2, boots: 1),
  // Magic Spring happens the turn it was found and is manditory:
  // https://boardgamegeek.com/thread/1656181/article/23992755#23992755
  Loot.minorSecret(
      name: 'Magic Spring', count: 2, acquireQueuedEffect: TrashOneCard()),

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

  // These are neither secrets nor artifacts.
  Loot.special(name: 'Mastery Token', count: 4, points: 20),
  Loot.special(name: 'Monkey Idol', count: 3, points: 5),
];

class Reserve {
  final List<List<Card>> piles;
  Reserve(Box box)
      : piles = [
          box.makeAll('Mercenary'),
          box.makeAll('Explore'),
          box.makeAll('Secret Tome'),
          box.makeAll('Goblin'),
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

class Box {
  CardType cardTypeByName(String name) =>
      baseSetAllCardTypes.firstWhere((type) => type.name == name);

  List<Card> make(String name, int amount) =>
      List.generate(amount, (_) => makeOne(name));

  List<Card> makeAll(String name) {
    var type = cardTypeByName(name);
    return List.generate(type.count, (_) => Card._(type));
  }

  Card makeOne(String name) => Card._(cardTypeByName(name));
  Card makeOneOfType(CardType cardType) => Card._(cardType);

  Iterable<CardType> get dungeonCardTypes =>
      baseSetAllCardTypes.where((type) => type.set == CardSet.dungeon);

  Iterable<Card> makeDungeonDeck() {
    var dungeonCardLists = dungeonCardTypes
        .map((type) => List.generate(type.count, (_) => Card._(type)));
    return dungeonCardLists.expand((element) => element);
  }

  List<Card> createStarterDeck() {
    List<Card> deck = [];
    deck.addAll(make('Burgle', 6));
    deck.addAll(make('Stumble', 2));
    deck.addAll(make('Sidestep', 1));
    deck.addAll(make('Scramble', 1));
    return deck;
  }

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

class LootToken extends Token {
  Loot loot;
  LootToken(this.loot);

  bool get isArtifact => loot.type == LootType.artifact;
  bool get isSecret => isMinorSecret || isMajorSecret;
  bool get isMinorSecret => loot.type == LootType.minorSecret;
  bool get isMajorSecret => loot.type == LootType.majorSecret;
  bool get isMonkeyIdol => loot.isMonkeyIdol;
  bool get isMasterKey => loot.isMasterKey;
  bool get isBackpack => loot.isBackpack;
  bool get isCrown => loot.isCrown;

  bool get isUsable => loot.isUsable;
  bool get discardImmediately => loot.discardImmediately;

  int get points => loot.points;

  @override
  String toString() => loot.toString();
}
