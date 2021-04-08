import 'package:clank/planner.dart';
import 'package:clank/clank.dart';

class Simulator {
  Future<void> run() async {
    // MVP
    // Deal out starting hands.
    // Have a short graph with one artifact.
    ClankGame game = ClankGame(playerConnections: [RandomPlanner()]);
    while (!game.isComplete) {
      // Should this produce a record of the turn for storing?
      await game.takeTurn();
    }
  }
}

void main() async {
  Simulator simulator = Simulator();
  await simulator.run();
  print("Game complete!");
}
