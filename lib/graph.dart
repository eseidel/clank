import 'box.dart';

class Edge {
  final Space start;
  final Space end;
  final int extraBootsCost;
  final int swordsCost;
  final bool requiresKey;
  final bool oneway; // Right way on a one way.
  final bool requiresTeleporter; // Wrong way on a one-way.
  final bool requiresArtifact; // To get back to the start square.

  Edge({
    required this.start,
    required this.end,
    this.extraBootsCost = 0,
    this.swordsCost = 0,
    this.requiresKey = false,
    this.oneway = false,
    this.requiresTeleporter = false,
    this.requiresArtifact = false,
  }) {
    assert(start != end);
  }

  // Should this be infinite for requiresTeleporter paths?
  int get bootsCost => 1 + extraBootsCost;
}

class Token {
  Space? location;

  void moveTo(Space newLocation) {
    Space? oldLocation = location;
    if (oldLocation != null) {
      oldLocation.tokens.remove(this);
    }
    location = newLocation;
    newLocation.tokens.add(this);
  }

  void removeFromBoard() {
    assert(location != null);
    if (location == null) {
      return;
    }
    location!.tokens.remove(this);
    location = null;
  }
}

// Player always has a location, should override getter to be non-nullable.
class PlayerToken extends Token {}

enum Special {
  none,
  minorSecret,
  majorSecret,
  artifact,
  monkeyShrine,
  heart,
}

class Space {
  final String name;
  List<Edge> edges = [];
  List<Token> tokens = [];
  Special special;
  bool isCrystalCave;
  bool isMarket;
  bool inDepths;
  int expectedArtifactValue; // Only valid if special == Artifact;

  Space.start()
      : name = 'start',
        inDepths = false,
        special = Special.none,
        isCrystalCave = false,
        isMarket = false,
        expectedArtifactValue = -1;

  // Non-depths
  Space.at(
    int column,
    int row, {
    this.special = Special.none,
    this.isCrystalCave = false,
    this.expectedArtifactValue = -1,
  })  : name = '${row}x$column',
        inDepths = false,
        isMarket = false;

  Space.depths(
    int column,
    int row, {
    this.special = Special.none,
    this.isCrystalCave = false,
    this.isMarket = false,
    this.expectedArtifactValue = -1,
  })  : name = '${row}x$column',
        inDepths = true;

  Iterable<LootToken> get loot => tokens.whereType<LootToken>();
  Iterable<LootToken> get secrets => loot.where((loot) => loot.isSecret);

  bool isAdjacentTo(Space other) {
    // Does this need to check both ways?
    return edges.any((edge) => edge.end == other);
  }

  @override
  String toString() => '[$name]';
}

class Graph {
  final Space start;
  List<Space> allSpaces;

  Graph({required this.start, required this.allSpaces});
}

class GraphBuilder {
  Space connect(
    Space from,
    Space to, {
    int extraBoots = 0,
    bool oneway = false,
    bool requiresKey = false,
    int monsters = 0,
  }) {
    // It's not clear these should be stored as separate objects like this?
    from.edges.add(Edge(
      start: from,
      end: to,
      extraBootsCost: extraBoots,
      swordsCost: monsters,
      requiresKey: requiresKey,
      oneway: oneway,
    ));
    to.edges.add(Edge(
      start: to,
      end: from,
      extraBootsCost: extraBoots,
      swordsCost: monsters,
      requiresKey: requiresKey,
      requiresTeleporter: oneway,
    ));
    return to; // Mostly for authoring convience.
  }

  void connectStart(Space start, Space to) {
    start.edges.add(Edge(
      start: start,
      end: to,
    ));
    to.edges.add(Edge(
      start: to,
      end: start,
      requiresArtifact: true,
    ));
  }
}

class FrontGraphBuilder extends GraphBuilder {
  List<Space> buildFirstRow() {
    List<Space> row = [
      Space.at(0, 0),
      Space.at(0, 1),
      Space.at(0, 2, special: Special.minorSecret),
      Space.at(0, 3, special: Special.majorSecret),
      Space.at(0, 4, special: Special.majorSecret),
    ];
    connect(row[0], row[1]);
    connect(row[1], row[2], extraBoots: 1);
    connect(row[2], row[3], extraBoots: 1);
    connect(row[4], row[3], oneway: true);
    return row;
  }

  List<Space> buildSecondRow() {
    List<Space> row = [
      Space.at(1, 0, isCrystalCave: true, special: Special.majorSecret),
      Space.at(1, 1, isCrystalCave: true),
      Space.at(1, 2, special: Special.majorSecret),
      Space.at(1, 3, isCrystalCave: true, special: Special.minorSecret),
      Space.at(1, 4),
    ];
    connect(row[3], row[4], extraBoots: 1);
    return row;
  }

  List<Space> buildThirdRow() {
    List<Space> row = [
      Space.at(2, 0, special: Special.heart),
      Space.at(2, 1, special: Special.minorSecret),
      Space.at(2, 2, isCrystalCave: true),
      Space.at(2, 3),
      Space.at(2, 4, special: Special.minorSecret),
    ];
    connect(row[2], row[3]);
    connect(row[3], row[4]);
    return row;
  }

  List<Space> buildFourthRow() {
    List<Space> row = [
      Space.depths(3, 0),
      Space.depths(3, 1,
          isCrystalCave: true,
          special: Special.artifact,
          expectedArtifactValue: 5),
      Space.depths(3, 2, isMarket: true, special: Special.minorSecret),
      Space.depths(3, 3, isMarket: true, special: Special.minorSecret),
      Space.depths(3, 4, special: Special.artifact, expectedArtifactValue: 7),
      Space.depths(3, 4, isCrystalCave: true, special: Special.minorSecret),
    ];
    connect(row[0], row[1]);
    connect(row[3], row[4]);
    connect(row[4], row[5]);
    connect(row[5], row[0]); // wrap around
    return row;
  }

  List<Space> buildFifthRow() {
    List<Space> row = [
      Space.depths(4, 0, special: Special.monkeyShrine),
      Space.depths(4, 1,
          isCrystalCave: true,
          special: Special.artifact,
          expectedArtifactValue: 15),
      Space.depths(4, 2, special: Special.majorSecret),
      Space.depths(4, 3, isMarket: true),
      Space.depths(4, 4,
          isMarket: true, special: Special.artifact, expectedArtifactValue: 10),
      Space.depths(4, 5, isCrystalCave: true, special: Special.majorSecret),
      Space.depths(4, 6, special: Special.majorSecret),
    ];
    connect(row[0], row[1], oneway: true);
    connect(row[2], row[3], requiresKey: true);
    connect(row[3], row[4]);
    return row;
  }

  List<Space> buildSixthRow() {
    List<Space> row = [
      // Monkey shrine is part of fifth row.
      Space.depths(5, 0, special: Special.minorSecret),
      Space.depths(5, 1, special: Special.artifact, expectedArtifactValue: 20),
      Space.depths(5, 2, isCrystalCave: true, special: Special.minorSecret),
      Space.depths(5, 3, special: Special.artifact, expectedArtifactValue: 25),
      Space.depths(5, 4, special: Special.heart),
      Space.depths(5, 5, special: Special.artifact, expectedArtifactValue: 30),
    ];
    connect(row[0], row[1], monsters: 2);
    connect(row[1], row[2], requiresKey: true);
    connect(row[2], row[3], monsters: 2);
    connect(row[3], row[4], monsters: 1, extraBoots: 1);
    return row;
  }

  List<Space> buildSeventhRow() {
    List<Space> row = [
      Space.depths(6, 0),
      Space.depths(6, 1, special: Special.majorSecret),
      Space.depths(6, 2, special: Special.heart),
      Space.depths(6, 3, special: Special.majorSecret, isCrystalCave: true),
    ];
    connect(row[0], row[1], requiresKey: true);
    connect(row[2], row[3], extraBoots: 1, monsters: 1);
    return row;
  }

  Graph build() {
    var start = Space.start();
    var first = buildFirstRow();
    connectStart(start, first[0]);
    var second = buildSecondRow();
    connect(second[0], first[1], extraBoots: 1, oneway: true);
    connect(first[1], second[1]);
    connect(first[2], second[2], requiresKey: true);
    connect(first[2], second[3]);
    connect(first[3], second[3], monsters: 1);
    connect(first[4], second[4], requiresKey: true);
    var third = buildThirdRow();
    connect(second[0], third[0], monsters: 1);
    connect(second[1], third[1], extraBoots: 1);
    connect(second[1], third[2], monsters: 1);
    connect(second[2], third[2], requiresKey: true);
    connect(second[3], third[3], monsters: 1);
    connect(second[4], third[4]);
    var fourth = buildFourthRow();
    connect(third[0], fourth[0], extraBoots: 1);
    connect(third[1], fourth[0], monsters: 1);
    connect(third[1], fourth[1]);
    connect(third[2], fourth[1], extraBoots: 1);
    connect(third[2], fourth[2], monsters: 2);
    connect(third[3], fourth[4], requiresKey: true);
    connect(third[4], fourth[4]);
    var fifth = buildFifthRow();
    connect(fourth[0], fifth[0], monsters: 1, oneway: true);
    connect(fourth[0], fifth[1]);
    connect(fourth[1], fifth[2], extraBoots: 1, monsters: 1);
    connect(fourth[1], fifth[3]);
    connect(fourth[2], fifth[3]);
    connect(fourth[3], fifth[4]);
    connect(fourth[3], fifth[5], monsters: 1);
    connect(fourth[5], fifth[6], requiresKey: true);
    var sixth = buildSixthRow();
    connect(sixth[0], fifth[0], oneway: true, extraBoots: 1);
    connect(sixth[0], fifth[3], extraBoots: 1);
    connect(sixth[1], fifth[3], monsters: 2);
    connect(sixth[2], fifth[4], requiresKey: true);
    connect(sixth[4], fifth[5], oneway: true);
    connect(sixth[5], fifth[6], monsters: 1);
    var seventh = buildSeventhRow();
    connect(fifth[0], seventh[0], oneway: true);
    connect(seventh[0], sixth[0]);
    connect(seventh[1], sixth[1], monsters: 1);
    connect(seventh[2], sixth[1], extraBoots: 1);
    connect(seventh[2], sixth[3], monsters: 2);
    connect(seventh[3], sixth[3]);

    List<Space> allSpaces = [
      start,
      ...first,
      ...second,
      ...third,
      ...fourth,
      ...fifth,
      ...sixth,
      ...seventh
    ];

    return Graph(start: start, allSpaces: allSpaces);
  }
}
