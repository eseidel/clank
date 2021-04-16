import 'dart:math';

import 'box.dart';
import 'cards.dart';
import 'clank.dart';
import 'graph.dart';

class Action {}

class PlayCard extends Action {
  final CardType cardType;
  late final OrEffect? orEffect;
  PlayCard(this.cardType, {int? orEffectIndex})
      : orEffect =
            orEffectIndex != null ? cardType.orEffects[orEffectIndex] : null {
    if (cardType.interaction != Interaction.buy) {
      throw ArgumentError('Only buyable cards can be played.');
    }
    if (cardType.orEffects.isNotEmpty && orEffect == null) {
      throw ArgumentError('OrEffect required for cardTypes with orEffects');
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
  final OrEffect? orEffect;

  UseDevice({required this.cardType, int? orEffectIndex})
      : orEffect =
            orEffectIndex != null ? cardType.orEffects[orEffectIndex] : null {
    assert(cardType.skillCost > 0);
    assert(cardType.swordsCost == 0);
    if (cardType.interaction != Interaction.use) {
      throw ArgumentError('Only device cards can be used.');
    }
    if (cardType.orEffects.isNotEmpty && orEffect == null) {
      throw ArgumentError('OrEffect required for cardTypes with orEffects');
    }
  }
}

class ReplaceCardInDungeonRow extends Action {
  final CardType cardType;
  ReplaceCardInDungeonRow(this.cardType) {
    assert(cardType.set == CardSet.dungeon);
  }
}

class EndTurn extends Action {}

class ActionGenerator {
  final Turn turn;
  final Board board;

  ActionGenerator(this.turn, this.board);

  Iterable<PlayCard> possibleCardPlays() sync* {
    Set<CardType> seenTypes = {};
    for (var card in turn.hand) {
      var cardType = card.type;
      // Avoid producing the same type of plays multiple times.
      if (seenTypes.contains(cardType)) continue;
      seenTypes.add(cardType);
      if (cardType.orEffects.isNotEmpty) {
        for (int i = 0; i < cardType.orEffects.length; i++) {
          // Need to check the orEffect is possible!
          yield PlayCard(cardType, orEffectIndex: i);
        }
      } else {
        yield PlayCard(cardType);
      }
    }
  }

  Iterable<Traverse> possibleMoves() sync* {
    int hpAvailableForTraversal = turn.hpAvailableForMonsterTraversals(board);
    bool haveResourcesFor(Edge edge, {required bool useTeleport}) {
      if (edge.requiresArtifact && !turn.player.hasArtifact) return false;
      if (useTeleport) return true;
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

    for (var cardType in board.availableCardTypes) {
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

  Iterable<Action> possibleQueuedEffects() sync* {
    for (var action in turn.queuedEffects) {
      switch (action) {
        case QueuedEffect.replaceCardInDungeonRow:
          for (var cardType
              in uniqueValues(board.dungeonRow.map((card) => card.type))) {
            yield ReplaceCardInDungeonRow(cardType);
          }
          break;
      }
    }
  }
}
