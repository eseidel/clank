enum CardSet {
  starter,
  reserve,
  dungeon,
}

class CardType {
  final String name;
  final CardSet set;
  final int skill;
  final int boots;
  final int swords;

  final int clank;
  final int points;

  final int skillCost;
  final int swordsCost;

  final bool dragon; // Not yet implemented!
  final bool danger; // Only used for Dragon Shrine and Kobold?

  final int acquireClank;
  final int acquireSwords;

  final int count;
  final int drawCards;
  final int gainGold;
  final PlayEffect effect;

  const CardType({
    required this.name,
    required this.set,
    this.skill = 0,
    this.boots = 0,
    this.swords = 0,
    this.clank = 0,
    this.skillCost = 0,
    this.swordsCost = 0,
    this.points = 0,
    this.dragon = false,
    this.acquireClank = 0,
    this.acquireSwords = 0,
    this.danger = false,
    this.drawCards = 0,
    this.gainGold = 0,
    this.effect = PlayEffect.none,
    required this.count,
  });

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
      skillCost: 2),
  CardType(
      set: CardSet.reserve,
      name: 'Explore',
      count: 15,
      skill: 2,
      boots: 1,
      skillCost: 3),
  CardType(
      set: CardSet.reserve,
      name: 'Secret Tome',
      count: 12,
      points: 7,
      skillCost: 7),

  // Dungeon Deck
  CardType(
      name: 'Sapphire',
      set: CardSet.dungeon,
      count: 3,
      points: 4,
      skillCost: 4,
      drawCards: 1,
      dragon: true,
      acquireClank: 2),
  CardType(
      name: 'Ruby',
      set: CardSet.dungeon,
      count: 2,
      points: 6,
      skillCost: 6,
      drawCards: 1,
      dragon: true,
      acquireClank: 2),
  CardType(
      name: 'Emerald',
      set: CardSet.dungeon,
      count: 2,
      points: 5,
      skillCost: 5,
      drawCards: 1,
      dragon: true,
      acquireClank: 2),
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
      skillCost: 1),
  CardType(
      name: 'Move Silently',
      set: CardSet.dungeon,
      count: 2,
      boots: 2,
      clank: -2,
      skillCost: 3),
  CardType(
    name: 'Silver Spear',
    set: CardSet.dungeon,
    count: 2,
    points: 2,
    swords: 3,
    skillCost: 3,
    acquireSwords: 1,
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
];
