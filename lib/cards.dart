enum CardSet {
  starter,
  reserve,
  dungeon,
}

// Could be subtype instead?
enum Interaction {
  fight, // monster
  use, // device
  buy, // everything else
}

enum Location {
  everywhere,
  crystalCave,
  deep,
}

enum CardSubType {
  none,
  companion,
  gem,
  device,
  monster,
}

class CardType {
  final String name;
  final CardSet set;
  final int skill;
  final int boots;
  final int swords;

  final int clank;
  final int points;

  final int othersClank;

  final int skillCost;
  final int swordsCost;

  final bool dragon;
  final bool danger;
  final Location location;

  final int arriveClank;

  final int acquireClank;
  final int acquireSwords;
  final int acquireHearts;
  final int acquireBoots;

  final int count;
  final int drawCards;
  final int gainGold;
  final PlayEffect playEffect;
  final PointsEffect pointsEffect;
  final CardSubType subtype;

  final bool neverDiscards; // Special just for Goblin.

  // Split into subtype specific constructors.
  const CardType({
    required this.name,
    required this.set,
    required this.count,
    this.skill = 0,
    this.boots = 0,
    this.swords = 0,
    this.clank = 0,
    this.skillCost = 0,
    this.swordsCost = 0,
    this.points = 0,
    this.dragon = false,
    this.arriveClank = 0,
    this.acquireClank = 0,
    this.acquireSwords = 0,
    this.acquireHearts = 0,
    this.acquireBoots = 0,
    this.danger = false,
    this.location = Location.everywhere,
    this.drawCards = 0,
    this.gainGold = 0,
    this.othersClank = 0,
    this.playEffect = PlayEffect.none,
    this.pointsEffect = PointsEffect.none,
    this.subtype = CardSubType.none,
    this.neverDiscards = false,
  });

  Interaction get interaction {
    if (subtype == CardSubType.device) return Interaction.use;
    if (subtype == CardSubType.monster) return Interaction.fight;
    return Interaction.buy;
  }

  bool get isMonster => subtype == CardSubType.monster;
  bool get isCompanion => subtype == CardSubType.companion;
  bool get isDevice => subtype == CardSubType.device;
  bool get isGem => subtype == CardSubType.gem;

  @override
  String toString() => name;
}

enum PlayEffect {
  none,
}

enum PointsEffect {
  none,
  tenIfMasteryToken,
  onePerFiveGold,
  fourIfTwoUniqueChaliceEggOrIdol,
  twoPerSecretTome,
}

class PointsConditions {
  final int gold;
  final bool hasMonkeyIdol;
  final bool hasDragonEgg;
  final bool hasChalice;
  final int secretTomeCount;
  final bool hasMasteryToken;
  PointsConditions(
      {required this.gold,
      required this.hasDragonEgg,
      required this.hasChalice,
      required this.hasMasteryToken,
      required this.hasMonkeyIdol,
      required this.secretTomeCount});
}

int conditionalPointsFor(CardType type, PointsConditions conditions) {
  switch (type.pointsEffect) {
    case PointsEffect.fourIfTwoUniqueChaliceEggOrIdol:
      int toInt(bool boolean) => boolean ? 1 : 0;
      int uniqueSecretCount = toInt(conditions.hasMonkeyIdol) +
          toInt(conditions.hasChalice) +
          toInt(conditions.hasDragonEgg);
      return uniqueSecretCount >= 2 ? 4 : 0;
    case PointsEffect.onePerFiveGold:
      return conditions.gold ~/ 5;
    case PointsEffect.tenIfMasteryToken:
      return conditions.hasMasteryToken ? 10 : 0;
    case PointsEffect.twoPerSecretTome:
      return conditions.secretTomeCount * 2;
    case PointsEffect.none:
      throw ArgumentError('No need to call conditional points');
  }
}

const List<CardType> baseSetAllCardTypes = [
  // Starter
  CardType(set: CardSet.starter, name: 'Burgle', count: 24, skill: 1),
  CardType(
      set: CardSet.starter, name: 'Scramble', count: 4, skill: 1, boots: 1),
  CardType(set: CardSet.starter, name: 'Sidestep', count: 4, boots: 1),
  CardType(set: CardSet.starter, name: 'Stumble', count: 8, clank: 1),

  // Reserve
  CardType(
    set: CardSet.reserve,
    name: 'Mercenary',
    count: 15,
    skill: 1,
    swords: 2,
    skillCost: 2,
  ),
  CardType(
    set: CardSet.reserve,
    name: 'Explore',
    count: 15,
    skill: 2,
    boots: 1,
    skillCost: 3,
  ),
  CardType(
    set: CardSet.reserve,
    name: 'Secret Tome',
    count: 12,
    points: 7,
    skillCost: 7,
  ),

  // Dungeon Deck
  CardType(
    name: 'Sapphire',
    set: CardSet.dungeon,
    subtype: CardSubType.gem,
    count: 3,
    points: 4,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
    skillCost: 4,
  ),
  CardType(
    name: 'Ruby',
    set: CardSet.dungeon,
    subtype: CardSubType.gem,
    count: 2,
    points: 6,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
    skillCost: 6,
  ),
  CardType(
    name: 'Emerald',
    set: CardSet.dungeon,
    subtype: CardSubType.gem,
    count: 2,
    points: 5,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Bracers of Agility',
    set: CardSet.dungeon,
    points: 2,
    count: 2,
    drawCards: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Pickaxe',
    set: CardSet.dungeon,
    count: 2,
    points: 2,
    swords: 2,
    gainGold: 2,
    skillCost: 4,
  ),
  CardType(
    name: 'Lucky Coin',
    set: CardSet.dungeon,
    count: 2,
    points: 1,
    skill: 1,
    clank: 1,
    drawCards: 1,
    skillCost: 1,
  ),
  CardType(
    name: 'Tunnel Guide',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 2,
    points: 1,
    swords: 1,
    boots: 1,
    skillCost: 1,
  ),
  CardType(
    name: 'Move Silently',
    set: CardSet.dungeon,
    count: 2,
    boots: 2,
    clank: -2,
    skillCost: 3,
  ),
  CardType(
    name: 'Silver Spear',
    set: CardSet.dungeon,
    count: 2,
    points: 2,
    swords: 3,
    acquireSwords: 1,
    skillCost: 3,
  ),
  CardType(
    name: 'Sneak',
    set: CardSet.dungeon,
    count: 2,
    skill: 1,
    boots: 1,
    clank: -2,
    skillCost: 2,
  ),
  CardType(
    name: 'Cleric of the Sun',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 2,
    points: 1,
    skill: 2,
    swords: 1,
    acquireHearts: 1,
    skillCost: 3,
  ),
  CardType(
    name: 'Tattle',
    set: CardSet.dungeon,
    count: 2,
    skill: 2,
    othersClank: 1,
    skillCost: 3,
  ),

  // Unique Cards
  CardType(
    name: 'Brilliance',
    set: CardSet.dungeon,
    count: 1,
    drawCards: 3,
    skillCost: 6,
  ),
  CardType(
    name: 'Elven Boots',
    set: CardSet.dungeon,
    count: 1,
    skill: 1,
    boots: 1,
    points: 2,
    drawCards: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Diamond',
    set: CardSet.dungeon,
    subtype: CardSubType.gem,
    count: 1,
    points: 8,
    drawCards: 1,
    acquireClank: 2,
    skillCost: 8,
  ),
  CardType(
    name: 'Treasure Map',
    set: CardSet.dungeon,
    count: 1,
    gainGold: 5,
    skillCost: 6,
  ),
  CardType(
    name: 'MonkeyBot 3000',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    clank: 3,
    drawCards: 3,
    points: 1,
    dragon: true,
    skillCost: 5,
  ),
  CardType(
    name: 'Scepter of the Ape Lord',
    set: CardSet.dungeon,
    count: 1,
    clank: 3,
    skill: 3,
    points: 3,
    skillCost: 3,
  ),
  CardType(
    name: 'Singing Sword',
    set: CardSet.dungeon,
    count: 1,
    points: 2,
    skill: 3,
    swords: 2,
    clank: 1,
    dragon: true,
    skillCost: 5,
  ),
  CardType(
    name: 'Elven Cloak',
    set: CardSet.dungeon,
    count: 1,
    points: 2,
    skill: 1,
    clank: -2,
    drawCards: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Elven Dagger',
    set: CardSet.dungeon,
    count: 1,
    points: 2,
    skill: 1,
    swords: 1,
    drawCards: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Amulet of Vigor',
    set: CardSet.dungeon,
    count: 1,
    points: 3,
    skill: 4,
    acquireHearts: 1,
    skillCost: 7,
  ),
  CardType(
    name: 'Boots of Swiftness',
    set: CardSet.dungeon,
    count: 1,
    points: 3,
    boots: 3,
    acquireBoots: 1,
    skillCost: 5,
  ),
  CardType(
    name: 'Wizard',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    pointsEffect: PointsEffect.twoPerSecretTome,
    skill: 3,
    skillCost: 6,
  ),
  CardType(
    name: "Dragon's Eye",
    set: CardSet.dungeon,
    count: 1,
    subtype: CardSubType.gem,
    pointsEffect: PointsEffect.tenIfMasteryToken,
    location: Location.deep,
    dragon: true,
    drawCards: 1,
    acquireClank: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'The Duke',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    pointsEffect: PointsEffect.onePerFiveGold,
    skill: 2,
    swords: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Dwarven Peddler',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    pointsEffect: PointsEffect.fourIfTwoUniqueChaliceEggOrIdol,
    boots: 1,
    gainGold: 2,
    skillCost: 4,
  ),

  // Monsters
  CardType(
    name: 'Goblin',
    set: CardSet.reserve,
    subtype: CardSubType.monster,
    count: 1,
    gainGold: 1,
    neverDiscards: true,
    swordsCost: 2,
  ),
  CardType(
    name: 'Cave Troll',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 1,
    location: Location.deep,
    dragon: true,
    gainGold: 3,
    drawCards: 2,
    swordsCost: 4,
  ),
  CardType(
    name: 'Belcher',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 2,
    dragon: true,
    gainGold: 4,
    clank: 2,
    swordsCost: 2,
  ),
  CardType(
    name: 'Animated Door',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 2,
    dragon: true,
    boots: 1,
    swordsCost: 1,
  ),
  CardType(
    name: 'Ogre',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 2,
    dragon: true,
    gainGold: 5,
    swordsCost: 3,
  ),
  CardType(
    name: 'Orc Grunt',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 3,
    dragon: true,
    gainGold: 3,
    swordsCost: 2,
  ),
  CardType(
    name: 'Crystal Golem',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 2,
    location: Location.crystalCave,
    skill: 3,
    swordsCost: 3,
  ),
  CardType(
    name: 'Kobold',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 3,
    dragon: true,
    danger: true,
    skill: 1,
    swordsCost: 1,
  ),
  CardType(
    name: 'Watcher',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 3,
    arriveClank: 1,
    gainGold: 3,
    othersClank: 1,
    swordsCost: 3,
  ),
  CardType(
    name: 'Overlord',
    set: CardSet.dungeon,
    subtype: CardSubType.monster,
    count: 2,
    arriveClank: 1,
    swordsCost: 2,
    drawCards: 2,
  ),

  // Devices
  CardType(
    name: 'Ladder',
    set: CardSet.dungeon,
    subtype: CardSubType.device,
    count: 2,
    boots: 2,
    skillCost: 3,
  ),
  CardType(
    name: 'The Vault',
    set: CardSet.dungeon,
    subtype: CardSubType.device,
    location: Location.deep,
    count: 1,
    dragon: true,
    gainGold: 5,
    clank: 3,
    skillCost: 3,
  ),
];
