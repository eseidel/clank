import 'package:clank/graph.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

class KlankMapper {
  final Graph graph;
  KlankMapper(this.graph);
  Space spaceForKlankId(int id) {
    int remapped = {23: 24, 24: 23}[id] ?? id;
    return graph.allSpaces[remapped - 1];
  }

  int idForSpace(Space space) {
    int id = graph.allSpaces.indexOf(space) + 1;
    int remapped = {23: 24, 24: 23}[id] ?? id;
    return remapped;
  }

  Set<Edge> collectEdges(Graph graph) {
    Set<Edge> allEdges = {};
    for (var space in graph.allSpaces) {
      allEdges.addAll(space.edges);
    }
    return allEdges;
  }

  Map<String, Edge> uniqueEdges(Graph graph) {
    var edges = collectEdges(graph);
    var namedEdges = <String, Edge>{};
    for (var edge in edges) {
      int startId = idForSpace(edge.start);
      int endId = idForSpace(edge.end);
      if (edge.requiresTeleporter) continue; // wrong way on a one-way.
      if (endId < startId && !edge.oneway) continue;
      var name = '$startId-$endId';
      namedEdges[name] = edge;
    }
    return namedEdges;
  }
}

void main() async {
  // Pull down map.yaml
  var url = 'https://raw.githubusercontent.com/kevinkey/klank/master/map1.yml';
  http.Response response = await http.get(Uri.parse(url));
  var yaml = loadYaml(response.body);

  var graph = FrontGraphBuilder().build();
  var roomCount = graph.allSpaces.length;
  var klankRoomCount = yaml['rooms'].length;

  var mapper = KlankMapper(graph);

  void compareRoom(int id, Map room) {
    void logNotEqual(dynamic a, dynamic b, String name) {
      if (a != b) print('$id $name $a != $b');
    }

    Space space = mapper.spaceForKlankId(id);
    logNotEqual(space.special == Special.minorSecret,
        room.containsKey('minor-secrets'), 'minor secret');
    logNotEqual(space.special == Special.majorSecret,
        room.containsKey('major-secrets'), 'major secret');
    logNotEqual(
        space.special == Special.heart, room.containsKey('heal'), 'heal');
    logNotEqual(space.special == Special.monkeyShrine,
        room.containsKey('monkey-idols'), 'monkey idols');
    logNotEqual(
        space.isCrystalCave, room['crystal-cave'] ?? false, 'crystal cave');
    logNotEqual(
        space.expectedArtifactValue, room['artifact'] ?? -1, 'artifact value');
    logNotEqual(space.isMarket, room['store'] ?? false, 'store');
  }

  print('roomCount $roomCount vs. $klankRoomCount');

  print('checking rooms...');
  for (var entry in yaml['rooms'].entries) {
    var id = entry.key;
    var room = entry.value ?? {};
    compareRoom(id, room);
  }

  void comparePath(String pathName, Map path, Edge edge) {
    void logNotEqual(dynamic a, dynamic b, String name) {
      if (a != b) print('$pathName $name $a != $b');
    }

    logNotEqual(edge.swordsCost, path['attack'] ?? 0, 'swords cost');
    logNotEqual(edge.bootsCost, path['move'] ?? 1, 'boots cost');
    logNotEqual(edge.requiresKey, path['locked'] ?? false, 'requiresKey');
    logNotEqual(edge.oneway, path['one-way'] ?? false, 'oneway');
  }

  var pathCount = yaml['paths'].length;
  var namedEdges = mapper.uniqueEdges(graph);
  print('pathCount: $pathCount, edges: ${namedEdges.length}');
  var seenEdges = [];
  print('checking tunnels...');
  for (var entry in yaml['paths'].entries) {
    var pathName = entry.key;
    var attributes = entry.value ?? {};
    var edge = namedEdges[pathName];
    if (edge == null) {
      print('Missing $pathName!');
      continue;
    }
    seenEdges.add(pathName);
    comparePath(pathName, attributes, edge);
  }
  for (var key in namedEdges.keys) {
    if (!seenEdges.contains(key)) {
      print('Extra edge? $key ${namedEdges[key]}');
    }
  }
}
