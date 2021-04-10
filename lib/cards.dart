class CardType {
  final String name;
  final int skill;
  final int boots;
  final int swords;

  final int clank;
  final int points;

  final int skillCost;
  final int swordsCost;

  final bool dragon;

  final int acquireClank;

  final int count;

  const CardType({
    this.name = '',
    this.skill = 0,
    this.boots = 0,
    this.swords = 0,
    this.clank = 0,
    this.skillCost = 0,
    this.swordsCost = 0,
    this.points = 0,
    this.dragon = false,
    this.acquireClank = 0,
    this.count = 1,
  });

  @override
  String toString() => name;
}

const List<CardType> baseSetAllCardTypes = [
  // Starter
  CardType(name: 'Burgle', count: 24, skill: 1),
  CardType(name: 'Scramble', count: 4, skill: 1, boots: 1),
  CardType(name: 'Sidestep', count: 4, boots: 1),
  CardType(name: 'Stumble', count: 8, clank: 1),

  // Reserve
  CardType(name: 'Mercenary', count: 15, skill: 1, swords: 2, skillCost: 2),
  CardType(name: 'Explore', count: 15, skill: 2, boots: 1, skillCost: 3),
  CardType(name: 'Secret Tome', count: 12, points: 7, skillCost: 7),

  // Dungeon Deck
  CardType(
      name: 'Sapphire', points: 4, skillCost: 4, dragon: true, acquireClank: 2),
];
