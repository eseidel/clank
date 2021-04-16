import 'dart:math';

import 'package:clank/cards.dart';
import 'package:clank/clank.dart';
import 'package:clank/graph.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

void main() {
  Library library = Library();

  // Does this belong on Turn?
  int stashClankCount(Board board, Player player) =>
      board.playerCubeStashes.countFor(player.color);

  int areaClankCount(Board board, Player player) =>
      board.clankArea.countFor(player.color);

  // int bagClankCount(Board board, Player player) =>
  //     board.dragonBag.countFor(player.color);

  CardType cardType(String name) => library.cardTypeByName(name);

  void addAndPlayCard(ClankGame game, Turn turn, String name,
      {int? orEffectIndex}) {
    var card = library.make(name, 1).first;
    turn.player.deck.hand.add(card);
    game.executeAction(turn, PlayCard(card.type, orEffectIndex: orEffectIndex));
  }

  test('conditional points dwarven peddler', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();

    void addCard(String name) {
      var card = library.make(name, 1).first;
      player.deck.hand.add(card);
    }

    void addLoot(String name) {
      var newLoot = allLoot.firstWhere((loot) => loot.loot.name == name);
      player.loot.add(newLoot);
    }

    expect(game.pointsForPlayer(player), 0);
    addCard('Dwarven Peddler');
    addLoot('Chalice');
    expect(game.pointsForPlayer(player), 7);
    addLoot('Dragon Egg');
    expect(game.pointsForPlayer(player), 14);

    player.loot = [];
    expect(game.pointsForPlayer(player), 0);
    addLoot('Dragon Egg');
    expect(game.pointsForPlayer(player), 3);
    addLoot('Monkey Idol');
    expect(game.pointsForPlayer(player), 12);

    player.loot = [];
    expect(game.pointsForPlayer(player), 0);
    addLoot('Chalice');
    expect(game.pointsForPlayer(player), 7);
    addLoot('Monkey Idol');
    expect(game.pointsForPlayer(player), 16);
  });

  test('mountain king triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var crown =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.loot.isCrown);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'The Mountain King');
    expect(turn.skill, 2);
    expect(turn.boots, 1);
    expect(turn.swords, 1);
    player.loot.add(crown);
    game.executeTriggeredEffects(turn);
    expect(turn.boots, 2);
    expect(turn.swords, 2);
  });

  test('queen of hearts triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var crown =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.loot.isCrown);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    game.board.takeDamage(player.color, 2);
    addAndPlayCard(game, turn, 'The Queen of Hearts');
    expect(game.board.damageTakenByPlayer(player.color), 2);
    expect(turn.skill, 3);
    expect(turn.swords, 1);
    player.loot.add(crown);
    game.executeTriggeredEffects(turn);
    expect(game.board.damageTakenByPlayer(player.color), 1);
  });

  test('kobold merchant triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Kobold Merchant');
    expect(turn.skill, 0);
    expect(player.gold, 2);
    player.loot.add(artifact);
    game.executeTriggeredEffects(turn);
    expect(turn.skill, 2);
  });

  test('rebel triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Rebel Miner');
    expect(player.deck.hand.length, 5);
    expect(player.gold, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 5);

    addAndPlayCard(game, turn, 'Rebel Soldier');
    expect(player.deck.hand.length, 5);
    expect(turn.swords, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 7); // Draw for both rebels.
    expect(player.deck.hand.length, 7); // Triggering again does nothing.

    addAndPlayCard(game, turn, 'Rebel Scout');
    expect(player.deck.hand.length, 7);
    expect(turn.boots, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 8); // Draw only for the new rebel.

    addAndPlayCard(game, turn, 'Rebel Captain');
    expect(player.deck.hand.length, 8);
    expect(turn.skill, 2);
    game.executeTriggeredEffects(turn);
    expect(player.deck.hand.length, 9); // Draw only for the new rebel.
  });

  test('wand of recall triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    addAndPlayCard(game, turn, 'Wand of Recall');
    expect(turn.skill, 2);
    game.executeTriggeredEffects(turn);
    expect(turn.teleports, 0);
    player.loot.add(artifact);
    game.executeTriggeredEffects(turn);
    expect(turn.teleports, 1);
  });

  test('archaeologist triggered effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var monkeyIdol =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isMonkeyIdol);
    var player = game.activePlayer;
    Turn turn = Turn(player: player);
    expect(player.deck.hand.length, 5);
    addAndPlayCard(game, turn, 'Archaeologist');
    expect(player.deck.hand.length, 6);
    expect(turn.skill, 0);
    game.executeTriggeredEffects(turn);
    expect(turn.skill, 0);
    player.loot.add(monkeyIdol);
    game.executeTriggeredEffects(turn);
    expect(turn.skill, 2);
  });

  test('flying carpet ignores exhaustion and monsters', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, isCrystalCave: true);
    builder.connect(from, to, monsters: 1);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = Turn(player: player);
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn, board);
    var moves = generator.possibleMoves();
    expect(moves.length, 1); // Move to 'to'
    game.executeAction(turn, moves.first);
    expect(turn.exhausted, isTrue);
    expect(board.damageTakenByPlayer(player.color), 1); // From monster

    moves = generator.possibleMoves();
    expect(moves.length, 0); // No legal moves, despite having 4 boots.
    expect(turn.boots, 4);

    addAndPlayCard(game, turn, 'Flying Carpet');
    expect(turn.exhausted, isFalse);
    expect(turn.boots, 6);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // No longer exhausted!

    game.executeAction(turn, moves.first);
    expect(turn.boots, 5);
    expect(turn.exhausted, isFalse);
    expect(board.damageTakenByPlayer(player.color), 1); // no more dmg taken!
  });

  test('treasure hunter', () {
    // Seed is important to ensure dungeonRow doesn't have duplicates.
    var game = ClankGame(planners: [MockPlanner()], seed: 0);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    addAndPlayCard(game, turn, 'Treasure Hunter');
    expect(turn.skill, 2);
    expect(turn.swords, 2);
    expect(turn.queuedEffects.length, 1);
    // Cards with complex actions are split into two.
    var possibleActions = ActionGenerator(turn, board).possibleQueuedEffects();
    expect(possibleActions.length, 6); // One per card (no duplicates);
    game.executeAction(turn, possibleActions.first);
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 6);
    expect(board.dragonBag.totalCubes, 24); // No attacks were made.
  });

  test('treasure hunter triggers arrival effects', () {
    var game = ClankGame(planners: [MockPlanner()], seed: 10);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);
    board.dungeonDeck = game.library.make('Watcher', 1);
    addAndPlayCard(game, turn, 'Treasure Hunter');
    var possibleActions = ActionGenerator(turn, board).possibleQueuedEffects();
    game.executeAction(turn, possibleActions.first);
    expect(board.clankArea.totalPlayerCubes, 1); // Arrival clank triggers.
  });
  test('Master Burglar', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var turn = Turn(player: player);

    addAndPlayCard(game, turn, 'Master Burglar');
    expect(turn.skill, 2);
    expect(player.deck.cardCount, 11); // Starter + one Master Burglar.
    // Starting with 6 burgles, one will always be in the first hand.
    player.deck.discardPile.addAll(player.deck.hand);
    player.deck.hand = [];
    game.executeEndOfTurn(turn);
    expect(player.deck.cardCount, 10); // One burgle gone.
    expect(player.countOfCards(game.library.cardTypeByName('Burgle')), 5);
  });
  test('Gem Collector', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    board.dungeonRow = library.make('Emerald', 2);
    var emerald = board.dungeonRow.last.type;
    turn.skill = emerald.skillCost;
    game.executeAction(turn, AcquireCard(cardType: emerald));
    expect(board.clankArea.countFor(player.color), 2);
    expect(turn.leftoverClankReduction, 0);
    expect(turn.skill, 0);

    addAndPlayCard(game, turn, 'Gem Collector');
    expect(board.clankArea.countFor(player.color), 0);
    expect(turn.leftoverClankReduction, 0);
    expect(turn.skill, 2); // No refunds are issued from the previous purchase.

    turn.skill = emerald.skillCost;
    game.executeAction(turn, AcquireCard(cardType: emerald));
    expect(turn.skill, 2); // Second purchase is 2 skill cheaper!
  });

  test('Underworld Dealing', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var underWorldDealing = cardType('Underworld Dealing');
    addAndPlayCard(game, turn, underWorldDealing.name, orEffectIndex: 0);
    expect(player.gold, 1);

    // Not allowed to play the second effect w/o the gold for it.
    expect(
        () => addAndPlayCard(game, turn, underWorldDealing.name,
            orEffectIndex: 1),
        throwsArgumentError);

    player.gold = 7;
    addAndPlayCard(game, turn, underWorldDealing.name, orEffectIndex: 1);
    expect(player.gold, 0);
    expect(player.deck.discardPile.length, 2);
  });

  test('Wand of Wind', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var wandOfWind = cardType('Wand of Wind');
    addAndPlayCard(game, turn, wandOfWind.name, orEffectIndex: 0);
    expect(turn.teleports, 1);

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, special: Special.majorSecret);
    var secret =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isMajorSecret);
    to.tokens.add(secret);
    builder.connect(from, to, monsters: 2);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    addAndPlayCard(game, turn, wandOfWind.name, orEffectIndex: 1);
    expect(player.loot.length, 1);

    // Artifacts are not secrets and can't be grabbed.
    from = Space.at(0, 0);
    to = Space.at(0, 1, special: Special.majorSecret);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    to.tokens.add(artifact);
    builder.connect(from, to, monsters: 2);
    board.graph = Graph(start: from, allSpaces: [from, to]);
    player.token.moveTo(from);

    expect(() => addAndPlayCard(game, turn, wandOfWind.name, orEffectIndex: 1),
        throwsArgumentError);
  }, skip: 'Unimplemented');

  test('Shrine use effects', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var shrine = cardType('Shrine');
    board.dungeonRow = library.make('Shrine', 2);
    turn.skill = 2;
    game.executeAction(turn, UseDevice(cardType: shrine, orEffectIndex: 0));
    expect(player.gold, 1);

    board.takeDamage(player.color, 2);
    turn.skill = 2;
    game.executeAction(turn, UseDevice(cardType: shrine, orEffectIndex: 1));
    expect(board.damageTakenByPlayer(player.color), 1);
  });

  test('Mister Whiskers', () {
    var game = ClankGame(planners: [MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var mrWhiskers = cardType('Mister Whiskers');
    turn.adjustClank(board, 2);
    expect(board.clankArea.totalPlayerCubes, 2);
    expect(board.dragonBag.totalCubes, 24);
    expect(board.cubeCountForNormalDragonAttack(), 3);
    addAndPlayCard(game, turn, mrWhiskers.name, orEffectIndex: 0);
    expect(board.dragonBag.totalCubes, 23); // 24 + 2 - 3 = 23
    expect(board.clankArea.totalPlayerCubes, 0);
    // Might have might have taken damage depending on random.

    expect(turn.leftoverClankReduction, 0);
    addAndPlayCard(game, turn, mrWhiskers.name, orEffectIndex: 1);
    expect(turn.leftoverClankReduction, -2);
  });

  test('Dragon Shrine', () {
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var dragonShrine = cardType('Dragon Shrine');
    expect(board.cubeCountForNormalDragonAttack(), 3);
    board.dungeonRow = library.make('Dragon Shrine', 2);
    expect(board.cubeCountForNormalDragonAttack(), 5); // +1 danger from each
    turn.skill = 4;
    game.executeAction(
        turn, UseDevice(cardType: dragonShrine, orEffectIndex: 0));
    expect(player.gold, 2);
    expect(board.cubeCountForNormalDragonAttack(), 4);
    expect(board.dungeonDiscard.length, 1);

    turn.skill = 4;
    game.executeAction(
        turn, UseDevice(cardType: dragonShrine, orEffectIndex: 1));
    expect(player.deck.cardCount, 10); // 10 starter cards.
    player.deck.discardPile.addAll(player.deck.hand);
    player.deck.hand = [];
    game.executeEndOfTurn(turn);
    expect(player.deck.cardCount, 9); // One card gone
  }, skip: 'Dragon Shrine unimplemented');

  test('Apothecary', () {
    var game = ClankGame(planners: [MockPlanner(), MockPlanner()]);
    var board = game.board;
    var player = game.activePlayer;
    var turn = Turn(player: player);

    var apothecary = cardType('Apothecary');
    // 1 discard -> 3 swords
    addAndPlayCard(game, turn, apothecary.name, orEffectIndex: 0);
    expect(turn.swords, 3);
    expect(player.deck.hand.length, 4);
    expect(player.deck.discardPile.length, 1);
    // 1 discard -> 2 gold
    addAndPlayCard(game, turn, apothecary.name, orEffectIndex: 1);
    expect(player.gold, 2);
    expect(player.deck.hand.length, 3);
    expect(player.deck.discardPile.length, 2);
    // 1 discard -> 1 heart
    board.takeDamage(player.color, 2);
    addAndPlayCard(game, turn, apothecary.name, orEffectIndex: 2);
    expect(board.damageTakenByPlayer(player.color), 9);
    expect(player.deck.hand.length, 2);
    expect(player.deck.discardPile.length, 3);
  }, skip: 'Apothecary unimplemented');
}