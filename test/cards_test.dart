import 'package:clank/actions.dart';
import 'package:clank/box.dart';
import 'package:clank/cards.dart';
import 'package:clank/clank.dart';
import 'package:clank/graph.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

void main() {
  Box box = Box();

  ClankGame makeGameWithPlayerCount(int count) {
    return ClankGame(
        planners: List.generate(count, (index) => MockPlanner()), seed: 10);
  }

  CardType cardType(String name) => box.cardTypeByName(name);

  void addAndPlayCard(ClankGame game, String name, {int? orEffectIndex}) {
    var card = game.box.make(name, 1).first;
    game.turn.hand.add(card);
    game.executeAction(PlayCard(card.type, orEffectIndex: orEffectIndex));
  }

  test('conditional points dwarven peddler', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var allLoot = game.box.makeAllLootTokens();

    void addCard(String name) {
      var card = box.make(name, 1).first;
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
    var game = makeGameWithPlayerCount(1);
    var crown =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.loot.isCrown);
    var player = game.activePlayer;
    Turn turn = game.turn;
    addAndPlayCard(game, 'The Mountain King');
    expect(turn.skill, 2);
    expect(turn.boots, 1);
    expect(turn.swords, 1);
    player.loot.add(crown);
    game.executeTriggeredEffects();
    expect(turn.boots, 2);
    expect(turn.swords, 2);
  });

  test('queen of hearts triggered effects', () {
    var game = makeGameWithPlayerCount(1);
    var crown =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.loot.isCrown);
    var player = game.activePlayer;
    var turn = game.turn;
    game.board.takeDamage(player, 2);
    addAndPlayCard(game, 'The Queen of Hearts');
    expect(game.board.damageTakenBy(player), 2);
    expect(turn.skill, 3);
    expect(turn.swords, 1);
    player.loot.add(crown);
    game.executeTriggeredEffects();
    expect(game.board.damageTakenBy(player), 1);
  });

  test('kobold merchant triggered effects', () {
    var game = makeGameWithPlayerCount(1);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    var player = game.activePlayer;
    var turn = game.turn;
    addAndPlayCard(game, 'Kobold Merchant');
    expect(turn.skill, 0);
    expect(player.gold, 2);
    player.loot.add(artifact);
    game.executeTriggeredEffects();
    expect(turn.skill, 2);
  });

  test('rebel triggered effects', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var turn = game.turn;
    addAndPlayCard(game, 'Rebel Miner');
    expect(player.deck.hand.length, 5);
    expect(player.gold, 2);
    game.executeTriggeredEffects();
    expect(player.deck.hand.length, 5);

    addAndPlayCard(game, 'Rebel Soldier');
    expect(player.deck.hand.length, 5);
    expect(turn.swords, 2);
    game.executeTriggeredEffects();
    expect(player.deck.hand.length, 7); // Draw for both rebels.
    expect(player.deck.hand.length, 7); // Triggering again does nothing.

    addAndPlayCard(game, 'Rebel Scout');
    expect(player.deck.hand.length, 7);
    expect(turn.boots, 2);
    game.executeTriggeredEffects();
    expect(player.deck.hand.length, 8); // Draw only for the new rebel.

    addAndPlayCard(game, 'Rebel Captain');
    expect(player.deck.hand.length, 8);
    expect(turn.skill, 2);
    game.executeTriggeredEffects();
    expect(player.deck.hand.length, 9); // Draw only for the new rebel.
  });

  test('wand of recall triggered effects', () {
    var game = makeGameWithPlayerCount(1);
    var artifact =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isArtifact);
    var player = game.activePlayer;
    var turn = game.turn;
    addAndPlayCard(game, 'Wand of Recall');
    expect(turn.skill, 2);
    game.executeTriggeredEffects();
    expect(turn.teleports, 0);
    player.loot.add(artifact);
    game.executeTriggeredEffects();
    expect(turn.teleports, 1);
  });

  test('archaeologist triggered effects', () {
    var game = makeGameWithPlayerCount(1);
    var monkeyIdol =
        game.box.makeAllLootTokens().firstWhere((loot) => loot.isMonkeyIdol);
    var player = game.activePlayer;
    var turn = game.turn;
    expect(player.deck.hand.length, 5);
    addAndPlayCard(game, 'Archaeologist');
    expect(player.deck.hand.length, 6);
    expect(turn.skill, 0);
    game.executeTriggeredEffects();
    expect(turn.skill, 0);
    player.loot.add(monkeyIdol);
    game.executeTriggeredEffects();
    expect(turn.skill, 2);
  });

  test('flying carpet ignores exhaustion and monsters', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;

    var builder = GraphBuilder();
    var from = Space.at(0, 0);
    var to = Space.at(0, 1, isCrystalCave: true);
    builder.connect(from, to, monsters: 1);
    board.graph = Graph(start: Space.start(), allSpaces: [from, to]);
    player.token.moveTo(from);

    var turn = game.turn;
    turn.boots = 5; // plenty
    var generator = ActionGenerator(turn);
    var moves = generator.possibleMoves();
    expect(moves.length, 1); // Move to 'to'
    game.executeAction(moves.first);
    expect(turn.exhausted, isTrue);
    expect(board.damageTakenBy(player), 1); // From monster

    moves = generator.possibleMoves();
    expect(moves.length, 0); // No legal moves, despite having 4 boots.
    expect(turn.boots, 4);

    addAndPlayCard(game, 'Flying Carpet');
    expect(turn.exhausted, isFalse);
    expect(turn.boots, 6);
    moves = generator.possibleMoves();
    expect(moves.length, 1); // No longer exhausted!

    game.executeAction(moves.first);
    expect(turn.boots, 5);
    expect(turn.exhausted, isFalse);
    expect(board.damageTakenBy(player), 1); // no more dmg taken!
  });

  test('treasure hunter', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var turn = game.turn;

    addAndPlayCard(game, 'Treasure Hunter');
    expect(turn.skill, 2);
    expect(turn.swords, 2);
    expect(turn.queuedEffects.length, 1);
    // Cards with complex actions are split into two.
    var possibleActions = ActionGenerator(turn).possibleQueuedEffects();
    expect(possibleActions.length, 6); // One per card (no duplicates);
    game.executeAction(possibleActions.first);
    expect(board.dungeonDiscard.length, 1);
    expect(board.dungeonRow.length, 6);
    expect(board.dragonBag.totalCubes, 24); // No attacks were made.
  });

  test('treasure hunter triggers arrival effects', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var turn = game.turn;
    board.dungeonDeck = game.box.make('Watcher', 1);
    addAndPlayCard(game, 'Treasure Hunter');
    var possibleActions = ActionGenerator(turn).possibleQueuedEffects();
    game.executeAction(possibleActions.first);
    expect(board.clankArea.totalPlayerCubes, 1); // Arrival clank triggers.
  });
  test('Master Burglar', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;
    var turn = game.turn;

    addAndPlayCard(game, 'Master Burglar');
    expect(turn.skill, 2);
    expect(player.deck.cardCount, 11); // Starter + one Master Burglar.
    // Starting with 6 burgles, one will always be in the first hand.
    player.deck.discardPile.addAll(player.deck.hand);
    player.deck.hand = [];
    game.executeEndOfTurn();
    expect(player.deck.cardCount, 10); // One burgle gone.
    expect(player.countOfCards(game.box.cardTypeByName('Burgle')), 5);
  });
  test('Gem Collector', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;
    var turn = game.turn;

    board.dungeonRow = box.make('Emerald', 2);
    var emerald = board.dungeonRow.last.type;
    turn.skill = emerald.skillCost;
    game.executeAction(AcquireCard(cardType: emerald));
    expect(board.clankAreaCountFor(player), 2);
    expect(turn.leftoverClankReduction, 0);
    expect(turn.skill, 0);

    addAndPlayCard(game, 'Gem Collector');
    expect(board.clankAreaCountFor(player), 0);
    expect(turn.leftoverClankReduction, 0);
    expect(turn.skill, 2); // No refunds are issued from the previous purchase.

    turn.skill = emerald.skillCost;
    game.executeAction(AcquireCard(cardType: emerald));
    expect(turn.skill, 2); // Second purchase is 2 skill cheaper!
  });

  test('Underworld Dealing', () {
    var game = makeGameWithPlayerCount(1);
    var player = game.activePlayer;

    var underWorldDealing = cardType('Underworld Dealing');
    addAndPlayCard(game, underWorldDealing.name, orEffectIndex: 0);
    expect(player.gold, 1);

    // Not allowed to play the second effect w/o the gold for it.
    expect(() => addAndPlayCard(game, underWorldDealing.name, orEffectIndex: 1),
        throwsArgumentError);

    player.gold = 7;
    addAndPlayCard(game, underWorldDealing.name, orEffectIndex: 1);
    expect(player.gold, 0);
    expect(player.deck.discardPile.length, 2);
  });

  test('Wand of Wind', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;
    var turn = game.turn;

    var wandOfWind = cardType('Wand of Wind');
    addAndPlayCard(game, wandOfWind.name, orEffectIndex: 0);
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

    addAndPlayCard(game, wandOfWind.name, orEffectIndex: 1);
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

    expect(() => addAndPlayCard(game, wandOfWind.name, orEffectIndex: 1),
        throwsArgumentError);
  }, skip: 'Unimplemented');

  test('Shrine use effects', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var player = game.activePlayer;
    var turn = game.turn;

    var shrine = cardType('Shrine');
    board.dungeonRow = box.make('Shrine', 2);
    turn.skill = 2;
    game.executeAction(UseDevice(cardType: shrine, orEffectIndex: 0));
    expect(player.gold, 1);

    board.takeDamage(player, 2);
    turn.skill = 2;
    game.executeAction(UseDevice(cardType: shrine, orEffectIndex: 1));
    expect(board.damageTakenBy(player), 1);
  });

  test('Mister Whiskers', () {
    var game = makeGameWithPlayerCount(1);
    var board = game.board;
    var turn = game.turn;

    var mrWhiskers = cardType('Mister Whiskers');
    turn.adjustActivePlayerClank(2);
    expect(board.clankArea.totalPlayerCubes, 2);
    expect(board.dragonBag.totalCubes, 24);
    expect(board.cubeCountForNormalDragonAttack(), 3);
    addAndPlayCard(game, mrWhiskers.name, orEffectIndex: 0);
    expect(board.dragonBag.totalCubes, 23); // 24 + 2 - 3 = 23
    expect(board.clankArea.totalPlayerCubes, 0);
    // Might have might have taken damage depending on random.

    expect(turn.leftoverClankReduction, 0);
    addAndPlayCard(game, mrWhiskers.name, orEffectIndex: 1);
    expect(turn.leftoverClankReduction, -2);
  });

  test('Dragon Shrine', () {
    var game = makeGameWithPlayerCount(2);
    var board = game.board;
    var player = game.activePlayer;
    var turn = game.turn;

    var dragonShrine = cardType('Dragon Shrine');
    expect(board.cubeCountForNormalDragonAttack(), 3);
    board.dungeonRow = box.make('Dragon Shrine', 2);
    expect(board.cubeCountForNormalDragonAttack(), 5); // +1 danger from each
    turn.skill = 4;
    game.executeAction(UseDevice(cardType: dragonShrine, orEffectIndex: 0));
    expect(player.gold, 2);
    expect(board.cubeCountForNormalDragonAttack(), 4);
    expect(board.dungeonDiscard.length, 1);

    turn.skill = 4;
    game.executeAction(UseDevice(cardType: dragonShrine, orEffectIndex: 1));
    expect(player.deck.cardCount, 10); // 10 starter cards.
    player.deck.discardPile.addAll(player.deck.hand);
    player.deck.hand = [];
    game.executeEndOfTurn();
    expect(player.deck.cardCount, 9); // One card gone
  }, skip: 'Dragon Shrine unimplemented');

  test('Apothecary', () {
    var game = makeGameWithPlayerCount(2);
    var board = game.board;
    var player = game.activePlayer;
    var turn = game.turn;

    var apothecary = cardType('Apothecary');
    // 1 discard -> 3 swords
    addAndPlayCard(game, apothecary.name, orEffectIndex: 0);
    expect(turn.swords, 3);
    expect(player.deck.hand.length, 4);
    expect(player.deck.discardPile.length, 1);
    // 1 discard -> 2 gold
    addAndPlayCard(game, apothecary.name, orEffectIndex: 1);
    expect(player.gold, 2);
    expect(player.deck.hand.length, 3);
    expect(player.deck.discardPile.length, 2);
    // 1 discard -> 1 heart
    board.takeDamage(player, 2);
    addAndPlayCard(game, apothecary.name, orEffectIndex: 2);
    expect(board.damageTakenBy(player), 9);
    expect(player.deck.hand.length, 2);
    expect(player.deck.discardPile.length, 3);
  }, skip: 'Apothecary unimplemented');
}
