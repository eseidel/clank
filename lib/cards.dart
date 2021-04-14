// This should not need to import clank.dart.

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

enum SpecialEffect {
  none,
  gemTwoSkillDiscount,
}

class CardType {
  final String name;
  final CardSet set;
  final int skill;
  final int boots;
  final int swords;
  // No card provides more than one teleport credit, but since you can
  // accumulate more than one per turn, we use an int here.
  final int teleports;

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

  final bool ignoreExhaustion;
  final bool ignoreMonsters;

  final SpecialEffect specialEffect;
  final QueuedEffect? queuedEffect;
  final EndOfTurn? endOfTurn;
  final ConditionalPoints? pointsCondition;
  final TriggerEffects? triggers;
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
    this.teleports = 0,
    this.ignoreExhaustion = false,
    this.ignoreMonsters = false,
    this.specialEffect = SpecialEffect.none,
    this.queuedEffect,
    this.endOfTurn,
    this.pointsCondition,
    this.triggers,
    this.subtype = CardSubType.none,
    this.neverDiscards = false,
  })  : assert(skill >= 0),
        assert(boots >= 0),
        assert(swords >= 0),
        assert(skillCost >= 0),
        assert(swordsCost >= 0),
        assert(points >= 0),
        assert(arriveClank >= 0),
        assert(acquireBoots >= 0),
        assert(acquireClank >= 0),
        assert(acquireHearts >= 0),
        assert(acquireSwords >= 0),
        assert(drawCards >= 0),
        assert(gainGold >= 0),
        assert(teleports >= 0);

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

enum QueuedEffect {
  replaceCardInDungeonRow,
}

enum EndOfTurn {
  // trashPlayedCardNow,
  trashPlayedBurgle,
  // discardToDrawTwo, // Not actually delayed?
}

// Maybe this should be shared with Loot and CardType somehow?
class Effect {
  final bool triggered;
  final int swords;
  final int skill;
  final int boots;
  final int drawCards;
  final int gold;
  final int hearts;
  final int teleports;
  Effect({
    required this.triggered,
    this.boots = 0,
    this.drawCards = 0,
    this.gold = 0,
    this.hearts = 0,
    this.skill = 0,
    this.swords = 0,
    this.teleports = 0,
  });
}

typedef TriggerEffects = Effect Function(EffectTriggers triggers);

class EffectTriggers {
  final bool haveCrown;
  // Card text is "if you have another companion in play area"
  // But since these companions are unique 2+ companions should be equivalent.
  final bool twoCompanionsInPlayArea;
  final bool haveArtifact;
  final bool haveMonkeyIdol;

  EffectTriggers({
    required this.haveCrown,
    required this.twoCompanionsInPlayArea,
    required this.haveArtifact,
    required this.haveMonkeyIdol,
  });

  static Effect theMountainKing(EffectTriggers triggers) =>
      Effect(triggered: triggers.haveCrown, swords: 1, boots: 1);

  static Effect queenOfHearts(EffectTriggers triggers) =>
      Effect(triggered: triggers.haveCrown, hearts: 1);

  static Effect ifTwoCompanionInPlayAreaDrawCard(EffectTriggers triggers) =>
      Effect(triggered: triggers.twoCompanionsInPlayArea, drawCards: 1);

  static Effect koboldMerchant(EffectTriggers triggers) =>
      Effect(triggered: triggers.haveArtifact, skill: 2);

  static Effect wandOfRecall(EffectTriggers triggers) =>
      Effect(triggered: triggers.haveArtifact, teleports: 1);

  static Effect archaeologist(EffectTriggers triggers) =>
      Effect(triggered: triggers.haveMonkeyIdol, skill: 2);
}

typedef ConditionalPoints = int Function(PointsConditions conditions);

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

  // These cannot just be lambdas on the CardType since function literals are
  // not const yet: https://github.com/dart-lang/language/issues/1048
  static int dwarvenPeddler(PointsConditions conditions) {
    int toInt(bool boolean) => boolean ? 1 : 0;
    int uniqueSecretCount = toInt(conditions.hasMonkeyIdol) +
        toInt(conditions.hasChalice) +
        toInt(conditions.hasDragonEgg);
    return uniqueSecretCount >= 2 ? 4 : 0;
  }

  static int theDuke(PointsConditions conditions) => conditions.gold ~/ 5;
  static int dragonsEye(PointsConditions conditions) =>
      conditions.hasMasteryToken ? 10 : 0;
  static int wizard(PointsConditions conditions) =>
      conditions.secretTomeCount * 2;
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
  CardType(
    name: 'Wand of Recall',
    set: CardSet.dungeon,
    count: 2,
    points: 1,
    skill: 2,
    triggers: EffectTriggers.wandOfRecall,
    skillCost: 5,
  ),
  CardType(
    name: 'Archaeologist',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 2,
    points: 1,
    drawCards: 1,
    triggers: EffectTriggers.archaeologist,
    skillCost: 2,
  ),
  CardType(
    name: 'Dead Run',
    set: CardSet.dungeon,
    count: 2,
    clank: 2,
    boots: 2,
    ignoreExhaustion: true,
    skillCost: 3,
  ),
  CardType(
    name: 'Treasure Hunter',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    points: 1,
    count: 2,
    skill: 2,
    swords: 2,
    queuedEffect: QueuedEffect.replaceCardInDungeonRow,
    skillCost: 3,
  ),
  CardType(
    name: 'Master Burglar',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    points: 2,
    count: 2,
    skill: 2,
    endOfTurn: EndOfTurn.trashPlayedBurgle,
    skillCost: 3,
  ),

  // Singletons
  CardType(
    name: 'Flying Carpet',
    set: CardSet.dungeon,
    count: 1,
    points: 2,
    boots: 2,
    ignoreExhaustion: true,
    ignoreMonsters: true,
    skillCost: 6,
  ),
  CardType(
    name: 'Gem Collector',
    set: CardSet.dungeon,
    count: 1,
    points: 2,
    skill: 2,
    clank: -2,
    specialEffect: SpecialEffect.gemTwoSkillDiscount,
    skillCost: 4,
  ),
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
    pointsCondition: PointsConditions.wizard,
    skill: 3,
    skillCost: 6,
  ),
  CardType(
    name: "Dragon's Eye",
    set: CardSet.dungeon,
    count: 1,
    subtype: CardSubType.gem,
    pointsCondition: PointsConditions.dragonsEye,
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
    pointsCondition: PointsConditions.theDuke,
    skill: 2,
    swords: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Dwarven Peddler',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    pointsCondition: PointsConditions.dwarvenPeddler,
    boots: 1,
    gainGold: 2,
    skillCost: 4,
  ),
  CardType(
    name: 'Invoker of the Ancients',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    clank: 1,
    teleports: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Kobold Merchant',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    gainGold: 2,
    triggers: EffectTriggers.koboldMerchant,
    skillCost: 3,
  ),
  CardType(
    name: 'The Mountain King',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 3,
    skill: 2,
    swords: 1,
    boots: 1,
    triggers: EffectTriggers.theMountainKing,
    skillCost: 6,
  ),
  CardType(
    name: 'The Queen of Hearts',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 3,
    skill: 3,
    swords: 1,
    triggers: EffectTriggers.queenOfHearts,
    skillCost: 6,
  ),
  CardType(
    name: 'Rebel Miner',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    gainGold: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 2,
  ),
  CardType(
    name: 'Rebel Soldier',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    swords: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 2,
  ),
  CardType(
    name: 'Rebel Scout',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    boots: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 3,
  ),
  CardType(
    name: 'Rebel Captain',
    set: CardSet.dungeon,
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    skill: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 3,
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
  CardType(
    name: 'Teleporter',
    set: CardSet.dungeon,
    subtype: CardSubType.device,
    count: 2,
    teleports: 1,
    skillCost: 4,
  ),
];
