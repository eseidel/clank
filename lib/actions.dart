import 'dart:math';

import 'box.dart';
import 'cards.dart';
import 'clank.dart';
import 'graph.dart';

class Action {}

class PlayCard extends Action {
  final CardType cardType;
  PlayCard(this.cardType) {
    if (cardType.interaction != Interaction.buy) {
      throw ArgumentError('Only buyable cards can be played.');
    }
  }
}

class Traverse extends Action {
  final Edge edge;
  final bool takeItem;
  final int spendHealth;
  final bool useTeleport;
  Traverse(
      {required this.edge,
      required this.takeItem,
      this.spendHealth = 0,
      this.useTeleport = false}) {
    assert(spendHealth >= 0);
    assert(spendHealth <= edge.swordsCost);
    assert(!takeItem || edge.end.loot.isNotEmpty);
    assert(!useTeleport || spendHealth == 0);
  }
}

class AcquireCard extends Action {
  final CardType cardType;
  AcquireCard({required this.cardType}) {
    if (cardType.interaction != Interaction.buy) {
      throw ArgumentError('Only buyable cards can be acquired.');
    }
    assert(cardType.skillCost > 0);
    assert(cardType.swordsCost == 0);
  }
}

class UseItem extends Action {
  final Loot item;
  UseItem({required this.item});
}

class BuyFromMarket extends Action {
  final Loot item;
  BuyFromMarket({required this.item});
}

class Fight extends Action {
  final CardType cardType;
  Fight({required this.cardType}) {
    if (cardType.interaction != Interaction.fight) {
      throw ArgumentError('Only monster cards can be fought.');
    }
    assert(cardType.skillCost == 0);
    assert(cardType.swordsCost > 0);
  }
}

class UseDevice extends Action {
  final CardType cardType;

  UseDevice({required this.cardType}) {
    assert(cardType.skillCost > 0);
    assert(cardType.swordsCost == 0);
    if (cardType.interaction != Interaction.use) {
      throw ArgumentError('Only device cards can be used.');
    }
  }
}

class Response extends Action {
  EffectSource trigger;
  Response({required this.trigger});
}

class ReplaceCardInDungeonRow extends Response {
  final CardType cardType;
  ReplaceCardInDungeonRow(
      {required EffectSource trigger, required this.cardType})
      : super(trigger: trigger) {
    assert(cardType.set == CardSet.dungeon);
  }
}

class TakeEffect extends Response {
  final ImmediateEffect effect;
  TakeEffect({required EffectSource trigger, required this.effect})
      : super(trigger: trigger);
}

class ChooseFrom extends Response {
  final List<Action> options;
  ChooseFrom({required EffectSource trigger, required this.options})
      : super(trigger: trigger);
}

class DiscardCard extends Response {
  final CardType cardType;
  final Effect effect;
  DiscardCard(
      {required EffectSource trigger,
      required this.cardType,
      required this.effect})
      : super(trigger: trigger);
}

class TrashACard extends Response {
  final CardType cardType;
  TrashACard({required EffectSource trigger, required this.cardType})
      : super(trigger: trigger);
}

class TakeAdjacentSecret extends Response {
  final Space from;
  TakeAdjacentSecret({required EffectSource trigger, required this.from})
      : super(trigger: trigger);
}

class EndTurn extends Action {}

class ActionGenerator {
  final Turn turn;

  ActionGenerator(this.turn);

  Iterable<PlayCard> possibleCardPlays() sync* {
    Set<CardType> seenTypes = {};
    for (var card in turn.hand) {
      var cardType = card.type;
      // Avoid producing the same type of plays multiple times.
      if (seenTypes.contains(cardType)) continue;
      seenTypes.add(cardType);
      yield PlayCard(cardType);
    }
  }

  Iterable<Traverse> possibleMoves() sync* {
    int hpAvailableForTraversal = turn.hpAvailableForMonsterTraversals();
    bool haveResourcesFor(Edge edge, {required bool useTeleport}) {
      if (edge.requiresArtifact && !turn.player.hasArtifact) return false;
      if (useTeleport) return true;
      if (edge.requiresTeleporter && !useTeleport) return false;
      assert(!useTeleport || turn.teleports > 0);
      if (turn.exhausted) return false;
      if (edge.requiresKey && !turn.player.hasMasterKey) return false;
      if (edge.bootsCost > turn.boots) return false;
      if (!turn.ignoreMonsters &&
          edge.swordsCost > (turn.swords + hpAvailableForTraversal)) {
        return false;
      }
      return true;
    }

    bool canTakeItemIn(Space end) {
      bool hasItem = end.loot.isNotEmpty;
      return hasItem &&
          (end.special != Special.artifact || turn.player.canTakeArtifact);
    }

    Space current = turn.player.token.location!;
    for (var edge in current.edges) {
      bool haveTeleports = turn.teleports > 0;
      if (haveTeleports && haveResourcesFor(edge, useTeleport: haveTeleports)) {
        yield Traverse(
            edge: edge, takeItem: canTakeItemIn(edge.end), useTeleport: true);
      }

      if (haveResourcesFor(edge, useTeleport: false)) {
        int swordsCost = edge.swordsCost;
        if (turn.ignoreMonsters) swordsCost = 0;
        // Yield one per possible distribution of health vs. swords spend.
        // For paths with zero swords this executes once with hpSpend = 0.
        int maxHpSpend = min(hpAvailableForTraversal, swordsCost);
        int minHpSpend = max(swordsCost - turn.swords, 0);
        for (int hpSpend = minHpSpend; hpSpend <= maxHpSpend; hpSpend++) {
          assert(hpSpend + turn.swords >= swordsCost);
          yield Traverse(
              edge: edge,
              takeItem: canTakeItemIn(edge.end),
              spendHealth: hpSpend);
        }
      }
    }
  }

  Iterable<Action> possibleCardAcquisitions() sync* {
    bool canAffordAcquireCard(CardType cardType) {
      if (cardType.interaction != Interaction.buy) return false;
      if (turn.skillCostForCard(cardType) > turn.skill) return false;
      return true;
    }

    bool canDefeat(CardType cardType) {
      if (cardType.interaction != Interaction.fight) return false;
      if (cardType.swordsCost > turn.swords) return false;
      return true;
    }

    bool canAffordDevice(CardType cardType) {
      if (cardType.interaction != Interaction.use) return false;
      if (cardType.skillCost > turn.skill) return false;
      return true;
    }

    for (var cardType in turn.board.availableCardTypes) {
      if (!cardUsableAtLocation(cardType, turn.player.location)) {
        continue;
      }
      if (canAffordAcquireCard(cardType)) {
        yield AcquireCard(cardType: cardType);
      }
      if (canDefeat(cardType)) {
        yield Fight(cardType: cardType);
      }
      if (canAffordDevice(cardType)) {
        yield UseDevice(cardType: cardType);
      }
    }
  }

  Iterable<Action> possibleItemUses() sync* {
    // Similar to possibleCardPlays this walks all items instead of item types
    // so it will yield duplicate UseItems when it shouldn't.
    for (var item in turn.player.usableItems) {
      yield UseItem(item: item.loot);
    }
  }

  Iterable<Action> possibleMarketBuys() sync* {
    // If player is in the market
    // if market has things available
    // iterate over possible purchases.
    for (var item in turn.board.availableMarketItemTypes) {
      if (turn.player.gold >= Board.marketGoldCost) {
        yield BuyFromMarket(item: item);
      }
    }
  }

  Iterable<Action> actionsFromEffect(
      {required EffectSource trigger, required Effect effect}) sync* {
    if (effect is ImmediateEffect) {
      Condition? condition = effect.condition;
      if (condition == null || turn.effectConditions.conditionMet(condition)) {
        yield TakeEffect(trigger: trigger, effect: effect);
      }
    } else if (effect is ReplaceCardTypeInDungeonRow) {
      for (var cardType in turn.cardTypesInDungeonRow) {
        yield ReplaceCardInDungeonRow(trigger: trigger, cardType: cardType);
      }
    } else if (effect is DiscardToTrigger) {
      for (var cardType in turn.cardTypesInHand) {
        yield DiscardCard(
            trigger: trigger, cardType: cardType, effect: effect.effect);
      }
    } else if (effect is Choice) {
      // This could also just yield a Choice result with different indicies?
      for (var option in effect.options) {
        yield* actionsFromEffect(trigger: trigger, effect: option);
      }
    } else if (effect is TakeSecretFromAdjacentRoom) {
      for (var space
          in turn.board.adjacentRoomsWithSecrets(turn.player.location)) {
        yield TakeAdjacentSecret(trigger: trigger, from: space);
      }
    } else if (effect is TrashOneCard) {
      for (var cardType in turn.cardTypesInDiscardAndPlayArea) {
        yield TrashACard(trigger: trigger, cardType: cardType);
      }
    } else {
      throw UnimplementedError('${effect.runtimeType} not handled');
    }
  }

  Iterable<Action> possibleActionsFromPendingActions() sync* {
    for (PendingAction pending in turn.pendingActions) {
      yield* actionsFromEffect(
          trigger: pending.trigger, effect: pending.effect);
    }
  }
}
