import 'package:clank/actions.dart';
import 'package:clank/box.dart';
import 'package:clank/cards.dart';
import 'package:clank/clank.dart';
import 'package:clank/planner.dart';
import 'package:test/test.dart';

Box box = Box();

ClankGame makeGameWithPlayerCount(int count) {
  var game = ClankGame(
      planners: List.generate(count, (index) => MockPlanner()), seed: 10);
  // Return any clank from initial deck arrival.
  for (var player in game.players) {
    int clank = game.board.clankAreaCountFor(player);
    if (clank > 0) {
      game.board.adjustClank(player, -clank);
    }
  }
  return game;
}

CardType cardType(String name) => box.cardTypeByName(name);

void addAndPlayCard(ClankGame game, String name) {
  var card = game.box.make(name, 1).first;
  game.turn.hand.add(card);
  game.executeAction(PlayCard(card.type));
}

void executeChoice(ClankGame game, int index,
    {required int expectedChoiceCount}) {
  Turn turn = game.turn;
  expect(turn.pendingActions.length, 1);
  var possibleActions =
      ActionGenerator(turn).possibleActionsFromPendingActions().toList();
  expect(possibleActions.length, expectedChoiceCount);
  game.executeAction(possibleActions[index]);
}

List<Card> fiveUniqueCards() {
  return ['Burgle', 'Stumble', 'Scramble', 'Sidestep', 'Explore']
      .map(box.makeOne)
      .toList();
}
