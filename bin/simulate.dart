import 'package:clank/ai.dart';
import 'package:clank/clank.dart';

void main() {
  // MVP
  // Deal out starting hands.
  // Have a short graph with one artifact.
  ClankGame game = ClankGame(planners: [
    RandomPlanner(),
  ]);
  while (!game.isComplete) {
    // Should this produce a record of the turn for storing?
    game.takeTurn();
  }
}
