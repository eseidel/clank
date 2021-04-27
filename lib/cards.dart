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
  increaseGoldGainByOne,
  gainOneSkillPerClankGain,
}

abstract class EffectSource {}

class CardType implements EffectSource {
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
  final int arriveReturnDragonCubes;

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
  final Effect? queuedEffect;
  final EndOfTurn? endOfTurn;
  final ConditionalPoints? pointsCondition;
  final TriggerEffects? triggers;
  final CardSubType subtype;

  final bool neverDiscards; // Special just for Goblin.

  // Split into subtype specific constructors.
  const CardType({
    required this.name,
    required this.count,
    this.set = CardSet.dungeon,
    this.skill = 0,
    this.boots = 0,
    this.swords = 0,
    this.clank = 0,
    this.skillCost = 0,
    this.points = 0,
    this.dragon = false,
    this.acquireClank = 0,
    this.acquireSwords = 0,
    this.acquireHearts = 0,
    this.acquireBoots = 0,
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
  })  : swordsCost = 0,
        neverDiscards = false,
        danger = false,
        arriveReturnDragonCubes = 0,
        arriveClank = 0,
        assert(skill >= 0),
        assert(boots >= 0),
        assert(swords >= 0),
        assert(skillCost >= 0),
        assert(points >= 0),
        assert(acquireBoots >= 0),
        assert(acquireClank >= 0),
        assert(acquireHearts >= 0),
        assert(acquireSwords >= 0),
        assert(drawCards >= 0),
        assert(gainGold >= 0),
        assert(teleports >= 0);

  const CardType.monster({
    required this.name,
    required this.count,
    required this.swordsCost,
    this.set = CardSet.dungeon,
    this.skill = 0,
    this.boots = 0,
    this.clank = 0,
    this.dragon = false,
    this.arriveClank = 0,
    this.arriveReturnDragonCubes = 0,
    this.danger = false,
    this.location = Location.everywhere,
    this.drawCards = 0,
    this.gainGold = 0,
    this.othersClank = 0,
    this.neverDiscards = false,
  })  : subtype = CardSubType.monster,
        skillCost = 0,
        points = 0,
        swords = 0,
        acquireClank = 0,
        acquireSwords = 0,
        acquireHearts = 0,
        acquireBoots = 0,
        teleports = 0,
        ignoreExhaustion = false,
        ignoreMonsters = false,
        pointsCondition = null,
        specialEffect = SpecialEffect.none,
        endOfTurn = null,
        queuedEffect = null,
        triggers = null,
        assert(skill >= 0),
        assert(boots >= 0),
        assert(swordsCost > 0),
        assert(arriveClank >= 0),
        assert(gainGold >= 0);

  const CardType.gem({
    required this.name,
    required this.count,
    required this.skillCost,
    this.points = 0,
    this.drawCards = 0, // always 1, leaving to be explict for now.
    this.acquireClank = 0, // always 2, leaving to be explicit for now.
    this.dragon = false, // always true, leaving to be explicit for now.
    this.location = Location.everywhere,
    this.pointsCondition,
  })  : subtype = CardSubType.gem,
        set = CardSet.dungeon,
        swordsCost = 0,
        skill = 0,
        swords = 0,
        boots = 0,
        gainGold = 0,
        clank = 0,
        teleports = 0,
        danger = false,
        acquireSwords = 0,
        acquireHearts = 0,
        acquireBoots = 0,
        arriveClank = 0,
        arriveReturnDragonCubes = 0,
        othersClank = 0,
        neverDiscards = false,
        ignoreExhaustion = false,
        ignoreMonsters = false,
        specialEffect = SpecialEffect.none,
        endOfTurn = null,
        triggers = null,
        queuedEffect = null,
        assert(skillCost > 0),
        assert(drawCards == 1), // All known gems draw 1 card.
        assert(acquireClank == 2), // All known gems acquireClank = 2.
        assert(dragon == true), // All known gems dragon == true.
        assert(points > 0 || pointsCondition != null);

  const CardType.device({
    required this.name,
    required this.count,
    required this.skillCost,
    this.boots = 0,
    this.clank = 0,
    this.dragon = false,
    this.danger = false,
    this.arriveReturnDragonCubes = 0,
    this.location = Location.everywhere,
    this.gainGold = 0,
    this.teleports = 0,
    this.queuedEffect,
  })  : subtype = CardSubType.device,
        set = CardSet.dungeon,
        swordsCost = 0,
        skill = 0,
        points = 0,
        swords = 0,
        drawCards = 0,
        acquireClank = 0,
        acquireSwords = 0,
        acquireHearts = 0,
        acquireBoots = 0,
        arriveClank = 0,
        othersClank = 0,
        neverDiscards = false,
        ignoreExhaustion = false,
        ignoreMonsters = false,
        pointsCondition = null,
        specialEffect = SpecialEffect.none,
        endOfTurn = null,
        triggers = null,
        assert(boots >= 0),
        assert(skillCost > 0),
        assert(gainGold >= 0);

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

class Effect {
  final Condition? condition;
  const Effect({this.condition});
}

// Multi-choice effect?
class PendingEffect extends Effect {
  const PendingEffect([Condition? condition]) : super(condition: condition);
}

// No choice effect?
class ImmediateEffect extends Effect {
  const ImmediateEffect([Condition? condition]) : super(condition: condition);
}

enum EndOfTurn {
  trashPlayedBurgle,
}

enum Condition {
  dungeonRowNotEmpty,
  have7Gold,
  adjacentSecretExists,
  handNotEmpty,
}

class EffectConditions {
  final bool dungeonRowNotEmpty;
  final bool have7Gold;
  final bool adjacentSecretExists;
  final bool handNotEmpty;

  EffectConditions(
      {required this.adjacentSecretExists,
      required this.dungeonRowNotEmpty,
      required this.handNotEmpty,
      required this.have7Gold});

  bool conditionMet(Condition condition) {
    switch (condition) {
      case Condition.adjacentSecretExists:
        return adjacentSecretExists;
      case Condition.dungeonRowNotEmpty:
        return dungeonRowNotEmpty;
      case Condition.handNotEmpty:
        return handNotEmpty;
      case Condition.have7Gold:
        return have7Gold;
    }
  }
}

class Choice extends PendingEffect {
  final List<Effect> options;
  const Choice(this.options);
}

class DragonAttack extends ImmediateEffect {
  const DragonAttack();
}

class SpendGoldForSecretTomes extends ImmediateEffect {
  const SpendGoldForSecretTomes() : super(Condition.have7Gold);
}

// This could be a PendingEffect, but there are some benefits with treating
// teleport as a "resource" for Traverse, as then Teleports flow down all the
// same code paths as Traverse ensuring entry effects work, etc.
class Teleport extends Reward {
  const Teleport() : super(teleports: 1);
}

class TrashOneCard extends PendingEffect {
  final CardType? cardType;
  const TrashOneCard([this.cardType]);
}

class DiscardToTrigger extends PendingEffect {
  final Effect effect;
  const DiscardToTrigger(this.effect) : super(Condition.handNotEmpty);
}

class ReplaceCardTypeInDungeonRow extends PendingEffect {
  const ReplaceCardTypeInDungeonRow() : super(Condition.dungeonRowNotEmpty);
}

class TakeSecretFromAdjacentRoom extends PendingEffect {
  const TakeSecretFromAdjacentRoom() : super(Condition.adjacentSecretExists);
}

// Maybe this should be shared with Loot and CardType somehow?
class Reward extends ImmediateEffect {
  final int swords;
  final int skill;
  final int boots;
  final int drawCards;
  final int gold;
  final int hearts;
  final int clank;
  final int teleports;
  const Reward({
    this.boots = 0,
    this.drawCards = 0,
    this.gold = 0,
    this.hearts = 0,
    this.skill = 0,
    this.swords = 0,
    this.clank = 0,
    this.teleports = 0,
  });

  @override
  String toString() {
    return [
      if (boots != 0) 'boots: $boots',
      if (drawCards != 0) 'drawCards: $drawCards',
      if (gold != 0) 'gold: $gold',
      if (hearts != 0) 'hearts: $hearts',
      if (skill != 0) 'skill: $skill',
      if (swords != 0) 'swords: $swords',
      if (clank != 0) 'clank: $clank',
      if (teleports != 0) 'teleports: $teleports',
    ].join(' ');
  }
}

class TriggerResult {
  final bool triggered;
  final Reward effect;
  TriggerResult(
      {required this.triggered,
      int boots = 0,
      int drawCards = 0,
      int gold = 0,
      int hearts = 0,
      int skill = 0,
      int swords = 0,
      int teleports = 0})
      : effect = Reward(
            boots: boots,
            gold: gold,
            hearts: hearts,
            drawCards: drawCards,
            skill: skill,
            swords: swords,
            teleports: teleports);
}

typedef TriggerEffects = TriggerResult Function(EffectTriggers triggers);

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

  static TriggerResult theMountainKing(EffectTriggers triggers) =>
      TriggerResult(triggered: triggers.haveCrown, swords: 1, boots: 1);

  static TriggerResult queenOfHearts(EffectTriggers triggers) =>
      TriggerResult(triggered: triggers.haveCrown, hearts: 1);

  static TriggerResult ifTwoCompanionInPlayAreaDrawCard(
          EffectTriggers triggers) =>
      TriggerResult(triggered: triggers.twoCompanionsInPlayArea, drawCards: 1);

  static TriggerResult koboldMerchant(EffectTriggers triggers) =>
      TriggerResult(triggered: triggers.haveArtifact, skill: 2);

  static TriggerResult wandOfRecall(EffectTriggers triggers) =>
      TriggerResult(triggered: triggers.haveArtifact, teleports: 1);

  static TriggerResult archaeologist(EffectTriggers triggers) =>
      TriggerResult(triggered: triggers.haveMonkeyIdol, skill: 2);
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
  CardType.monster(
    name: 'Goblin',
    set: CardSet.reserve,
    count: 1,
    gainGold: 1,
    neverDiscards: true,
    swordsCost: 2,
  ),

  // Dungeon Deck
  CardType.gem(
    name: 'Sapphire',
    count: 3,
    points: 4,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
    skillCost: 4,
  ),
  CardType.gem(
    name: 'Ruby',
    count: 2,
    points: 6,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
    skillCost: 6,
  ),
  CardType.gem(
    name: 'Emerald',
    count: 2,
    points: 5,
    drawCards: 1,
    dragon: true,
    acquireClank: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Bracers of Agility',
    points: 2,
    count: 2,
    drawCards: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Pickaxe',
    count: 2,
    points: 2,
    swords: 2,
    gainGold: 2,
    skillCost: 4,
  ),
  CardType(
    name: 'Lucky Coin',
    count: 2,
    points: 1,
    skill: 1,
    clank: 1,
    drawCards: 1,
    skillCost: 1,
  ),
  CardType(
    name: 'Tunnel Guide',
    subtype: CardSubType.companion,
    count: 2,
    points: 1,
    swords: 1,
    boots: 1,
    skillCost: 1,
  ),
  CardType(
    name: 'Move Silently',
    count: 2,
    boots: 2,
    clank: -2,
    skillCost: 3,
  ),
  CardType(
    name: 'Silver Spear',
    count: 2,
    points: 2,
    swords: 3,
    acquireSwords: 1,
    skillCost: 3,
  ),
  CardType(
    name: 'Sneak',
    count: 2,
    skill: 1,
    boots: 1,
    clank: -2,
    skillCost: 2,
  ),
  CardType(
    name: 'Cleric of the Sun',
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
    count: 2,
    skill: 2,
    othersClank: 1,
    skillCost: 3,
  ),
  CardType(
    name: 'Wand of Recall',
    count: 2,
    points: 1,
    skill: 2,
    triggers: EffectTriggers.wandOfRecall,
    skillCost: 5,
  ),
  CardType(
    name: 'Archaeologist',
    subtype: CardSubType.companion,
    count: 2,
    points: 1,
    drawCards: 1,
    triggers: EffectTriggers.archaeologist,
    skillCost: 2,
  ),
  CardType(
    name: 'Dead Run',
    count: 2,
    clank: 2,
    boots: 2,
    ignoreExhaustion: true,
    skillCost: 3,
  ),
  CardType(
    name: 'Treasure Hunter',
    subtype: CardSubType.companion,
    points: 1,
    count: 2,
    skill: 2,
    swords: 2,
    queuedEffect: ReplaceCardTypeInDungeonRow(),
    skillCost: 3,
  ),
  CardType(
    name: 'Master Burglar',
    subtype: CardSubType.companion,
    points: 2,
    count: 2,
    skill: 2,
    endOfTurn: EndOfTurn.trashPlayedBurgle,
    skillCost: 3,
  ),
  CardType(
    name: 'Sleight of Hand',
    count: 2,
    queuedEffect: DiscardToTrigger(Reward(drawCards: 2)),
    skillCost: 2,
  ),
  CardType(
    name: 'Search',
    count: 2,
    skill: 2,
    boots: 1,
    specialEffect: SpecialEffect.increaseGoldGainByOne,
    skillCost: 4,
  ),
  CardType(
    name: 'Swagger',
    count: 2,
    boots: 1,
    specialEffect: SpecialEffect.gainOneSkillPerClankGain,
    skillCost: 2,
  ),

  // Singletons
  CardType(
    name: 'Flying Carpet',
    count: 1,
    points: 2,
    boots: 2,
    ignoreExhaustion: true,
    ignoreMonsters: true,
    skillCost: 6,
  ),
  CardType(
    name: 'Gem Collector',
    count: 1,
    points: 2,
    skill: 2,
    clank: -2,
    specialEffect: SpecialEffect.gemTwoSkillDiscount,
    skillCost: 4,
  ),
  CardType(
    name: 'Brilliance',
    count: 1,
    drawCards: 3,
    skillCost: 6,
  ),
  CardType(
    name: 'Elven Boots',
    count: 1,
    skill: 1,
    boots: 1,
    points: 2,
    drawCards: 1,
    skillCost: 4,
  ),
  CardType.gem(
    name: 'Diamond',
    count: 1,
    points: 8,
    dragon: true,
    drawCards: 1,
    acquireClank: 2,
    skillCost: 8,
  ),
  CardType(
    name: 'Treasure Map',
    count: 1,
    gainGold: 5,
    skillCost: 6,
  ),
  CardType(
    name: 'MonkeyBot 3000',
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
    count: 1,
    clank: 3,
    skill: 3,
    points: 3,
    skillCost: 3,
  ),
  CardType(
    name: 'Singing Sword',
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
    count: 1,
    points: 2,
    skill: 1,
    clank: -2,
    drawCards: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Elven Dagger',
    count: 1,
    points: 2,
    skill: 1,
    swords: 1,
    drawCards: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Amulet of Vigor',
    count: 1,
    points: 3,
    skill: 4,
    acquireHearts: 1,
    skillCost: 7,
  ),
  CardType(
    name: 'Boots of Swiftness',
    count: 1,
    points: 3,
    boots: 3,
    acquireBoots: 1,
    skillCost: 5,
  ),
  CardType(
    name: 'Wizard',
    subtype: CardSubType.companion,
    count: 1,
    pointsCondition: PointsConditions.wizard,
    skill: 3,
    skillCost: 6,
  ),
  CardType.gem(
    name: "Dragon's Eye",
    count: 1,
    pointsCondition: PointsConditions.dragonsEye,
    location: Location.deep, // acquire in
    dragon: true,
    drawCards: 1,
    acquireClank: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'The Duke',
    subtype: CardSubType.companion,
    count: 1,
    pointsCondition: PointsConditions.theDuke,
    skill: 2,
    swords: 2,
    skillCost: 5,
  ),
  CardType(
    name: 'Dwarven Peddler',
    subtype: CardSubType.companion,
    count: 1,
    pointsCondition: PointsConditions.dwarvenPeddler,
    boots: 1,
    gainGold: 2,
    skillCost: 4,
  ),
  CardType(
    name: 'Invoker of the Ancients',
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    clank: 1,
    teleports: 1,
    skillCost: 4,
  ),
  CardType(
    name: 'Kobold Merchant',
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    gainGold: 2,
    triggers: EffectTriggers.koboldMerchant,
    skillCost: 3,
  ),
  CardType(
    name: 'The Mountain King',
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
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    gainGold: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 2,
  ),
  CardType(
    name: 'Rebel Soldier',
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    swords: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 2,
  ),
  CardType(
    name: 'Rebel Scout',
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    boots: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 3,
  ),
  CardType(
    name: 'Rebel Captain',
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    skill: 2,
    triggers: EffectTriggers.ifTwoCompanionInPlayAreaDrawCard,
    skillCost: 3,
  ),
  CardType(
    name: 'Apothecary',
    subtype: CardSubType.companion,
    count: 1,
    points: 2,
    queuedEffect: DiscardToTrigger(Choice([
      Reward(swords: 3),
      Reward(gold: 2),
      Reward(hearts: 1),
    ])),
    skillCost: 3,
  ),
  CardType(
    name: 'Wand of Wind',
    count: 1,
    points: 3,
    queuedEffect: Choice([Teleport(), TakeSecretFromAdjacentRoom()]),
    skillCost: 6,
  ),
  CardType(
    name: 'Mister Whiskers',
    subtype: CardSubType.companion,
    count: 1,
    points: 1,
    dragon: true,
    queuedEffect: Choice([DragonAttack(), Reward(clank: -2)]),
    skillCost: 1,
  ),
  CardType(
    name: 'Underworld Dealing',
    count: 1,
    queuedEffect: Choice([Reward(gold: 1), SpendGoldForSecretTomes()]),
    skillCost: 1,
  ),

  // Monsters
  CardType.monster(
    name: 'Cave Troll',
    count: 1,
    location: Location.deep, // fight in
    dragon: true,
    gainGold: 3,
    drawCards: 2,
    swordsCost: 4,
  ),
  CardType.monster(
    name: 'Belcher',
    count: 2,
    dragon: true,
    gainGold: 4,
    clank: 2,
    swordsCost: 2,
  ),
  CardType.monster(
    name: 'Animated Door',
    count: 2,
    dragon: true,
    boots: 1,
    swordsCost: 1,
  ),
  CardType.monster(
    name: 'Ogre',
    count: 2,
    dragon: true,
    gainGold: 5,
    swordsCost: 3,
  ),
  CardType.monster(
    name: 'Orc Grunt',
    count: 3,
    dragon: true,
    gainGold: 3,
    swordsCost: 2,
  ),
  CardType.monster(
    name: 'Crystal Golem',
    count: 2,
    location: Location.crystalCave, // Fight in
    skill: 3,
    swordsCost: 3,
  ),
  CardType.monster(
    name: 'Kobold',
    count: 3,
    dragon: true,
    danger: true,
    skill: 1,
    swordsCost: 1,
  ),
  CardType.monster(
    name: 'Watcher',
    count: 3,
    arriveClank: 1,
    gainGold: 3,
    othersClank: 1,
    swordsCost: 3,
  ),
  CardType.monster(
    name: 'Overlord',
    count: 2,
    arriveClank: 1,
    swordsCost: 2,
    drawCards: 2,
  ),

  // Devices
  CardType.device(
    name: 'Ladder',
    count: 2,
    boots: 2,
    skillCost: 3,
  ),
  CardType.device(
    name: 'The Vault',
    location: Location.deep, // use in
    count: 1,
    dragon: true,
    gainGold: 5,
    clank: 3,
    skillCost: 3,
  ),
  CardType.device(
    name: 'Teleporter',
    count: 2,
    teleports: 1,
    skillCost: 4,
  ),
  CardType.device(
    name: 'Dragon Shrine',
    count: 2,
    danger: true,
    queuedEffect: Choice([Reward(gold: 2), TrashOneCard()]),
    skillCost: 4,
  ),
  CardType.device(
    name: 'Shrine',
    count: 3,
    arriveReturnDragonCubes: 3,
    queuedEffect: Choice([Reward(gold: 1), Reward(hearts: 1)]),
    skillCost: 2,
  ),
];
