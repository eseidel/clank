import 'dart:math';

import 'package:args/args.dart';
import 'package:clank/planner.dart';
import 'package:clank/clank.dart';

Future simulateWithSeed(int seed) async {
  print('Seed: $seed');
  ClankGame game = ClankGame(
      planners: [RandomPlanner(seed: seed), RandomPlanner(seed: seed)],
      seed: seed);
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

void main(List<String> args) async {
  var parser = ArgParser();
  parser.addOption('count', defaultsTo: '1');
  parser.addOption('seed');
  var results = parser.parse(args);

  var loopCount = int.parse(results['count']);

  final randomMaxInt = 10000;
  var random = Random();
  int seed = results['seed'] == null
      ? random.nextInt(randomMaxInt)
      : int.parse(results['seed']);

  for (int i = 0; i < loopCount; i++) {
    await simulateWithSeed(seed);
    seed = random.nextInt(randomMaxInt);
  }
}
