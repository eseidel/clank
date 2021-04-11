enum CardSet {
  starter,
  reserve,
  dungeon,
}

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
  final bool companion;
  final Location location;

  final int arriveClank;

  final int acquireClank;
  final int acquireSwords;
  final int acquireHearts;
  final int acquireBoots;

  final int count;
  final int drawCards;
  final int gainGold;
  final PlayEffect effect;
  final Interaction interaction;

  final bool neverDiscards; // Special just for Goblin.

  const CardType({
    required this.name,
    required this.set,
    bool isDevice = false,
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
    this.companion = false,
    this.location = Location.everywhere,
    this.drawCards = 0,
    this.gainGold = 0,
    this.othersClank = 0,
    this.effect = PlayEffect.none,
    required this.count,
    this.neverDiscards = false,
  }) : interaction = (isDevice)
            ? Interaction.use
            : (swordsCost > 0 ? Interaction.fight : Interaction.buy);

  @override
  String toString() => name;
}

enum PlayEffect {
  none,
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
    count: 3,
    points: 4,
    skillCost: 4,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
  ),
  CardType(
    name: 'Ruby',
    set: CardSet.dungeon,
    count: 2,
    points: 6,
    skillCost: 6,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
  ),
  CardType(
    name: 'Emerald',
    set: CardSet.dungeon,
    count: 2,
    points: 5,
    skillCost: 5,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
  ),
  CardType(
    name: 'Bracers of Agility',
    set: CardSet.dungeon,
    points: 2,
    count: 2,
    skillCost: 5,
    drawCards: 2,
  ),
  CardType(
    name: 'Pickaxe',
    set: CardSet.dungeon,
    count: 2,
    points: 2,
    swords: 2,
    skillCost: 4,
    gainGold: 2,
  ),
  CardType(
    name: 'Lucky Coin',
    set: CardSet.dungeon,
    count: 2,
    points: 1,
    skill: 1,
    skillCost: 1,
    clank: 1,
    drawCards: 1,
  ),
  CardType(
    name: 'Tunnel Guide',
    set: CardSet.dungeon,
    count: 2,
    points: 1,
    swords: 1,
    boots: 1,
    skillCost: 1,
    companion: true,
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
    skillCost: 3,
    acquireSwords: 1,
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
    companion: true,
    count: 2,
    points: 1,
    skill: 2,
    swords: 1,
    acquireHearts: 1,
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
    count: 1,
    clank: 3,
    drawCards: 3,
    points: 1,
    skillCost: 5,
    companion: true,
    dragon: true,
  ),
  CardType(
    name: 'Scepter of the Ape Lord',
    set: CardSet.dungeon,
    count: 1,
    clank: 3,
    skill: 3,
    skillCost: 3,
    points: 3,
  ),
  CardType(
    name: 'Singing Sword',
    set: CardSet.dungeon,
    count: 1,
    points: 2,
    skill: 3,
    swords: 2,
    clank: 1,
    skillCost: 5,
    dragon: true,
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

  // Monsters
  CardType(
    name: 'Goblin',
    set: CardSet.reserve,
    count: 1,
    swordsCost: 2,
    gainGold: 1,
    neverDiscards: true,
  ),
  CardType(
    name: 'Cave Troll',
    set: CardSet.dungeon,
    count: 1,
    location: Location.deep,
    dragon: true,
    swordsCost: 4,
    gainGold: 3,
    drawCards: 2,
  ),
  CardType(
    name: 'Belcher',
    set: CardSet.dungeon,
    count: 2,
    dragon: true,
    swordsCost: 2,
    gainGold: 4,
    clank: 2,
  ),
  CardType(
    name: 'Animated Door',
    set: CardSet.dungeon,
    count: 2,
    dragon: true,
    swordsCost: 1,
    boots: 1,
  ),
  CardType(
    name: 'Ogre',
    set: CardSet.dungeon,
    count: 2,
    dragon: true,
    swordsCost: 3,
    gainGold: 5,
  ),
  CardType(
    name: 'Orc Grunt',
    set: CardSet.dungeon,
    count: 3,
    dragon: true,
    swordsCost: 2,
    gainGold: 3,
  ),
  CardType(
    name: 'Crystal Golem',
    set: CardSet.dungeon,
    count: 2,
    location: Location.crystalCave,
    swordsCost: 3,
    skill: 3,
  ),
  CardType(
    name: 'Kobold',
    set: CardSet.dungeon,
    count: 3,
    dragon: true,
    danger: true,
    swordsCost: 1,
    skill: 1,
  ),
  CardType(
    name: 'Watcher',
    set: CardSet.dungeon,
    count: 3,
    arriveClank: 1,
    swordsCost: 3,
    gainGold: 3,
    othersClank: 1,
  ),
  CardType(
    name: 'Overlord',
    set: CardSet.dungeon,
    count: 2,
    arriveClank: 1,
    swordsCost: 2,
    drawCards: 2,
  ),
];
