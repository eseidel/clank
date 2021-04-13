import 'package:clank/planner.dart';
import 'package:clank/clank.dart';

void main() async {
  ClankGame game = ClankGame(planners: [RandomPlanner(), RandomPlanner()]);
  int turnCount = 0;
  while (!game.isComplete) {
    await game.takeTurn();
    turnCount++;
  }
  for (var player in game.players) {
    print('$player got ${game.pointsForPlayer(player)} ${player.status}');
  }
  print('Game complete in ($turnCount turns)!');
}
