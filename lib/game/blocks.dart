import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'road.dart';
import 'tesla_fleet.dart';

class Pile {
  Pile(this.minX, this.maxX, this.top);
  final double minX;
  final double maxX;
  final double top;
}

class Block {
  Block(this.node, this.start, this.end, this.piles);
  final Node node;
  final double start;
  final double end;
  final List<Pile> piles;
}

class BlockBuilder {
  BlockBuilder(this.fleet);

  final TeslaFleet fleet;
  final _random = math.Random();
  static const halfRoad = roadHalfWidth - 0.05;
  static final _sideways = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2);
  static final _sidewaysFlipped = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -math.pi / 2);

  Block build(double start, int level) {
    final node = Node(name: 'block');
    final rows = 1 + _random.nextInt(math.min(level, 3));
    final maxLayers = math.min(1 + level ~/ 2, 4);
    final columns = [-halfRoad / 2, halfRoad / 2];
    final layers = [for (final _ in columns) 1 + _random.nextInt(maxLayers)];
    final tops = [0.0, 0.0];

    var z = start;
    for (var row = 0; row < rows; row++) {
      var rowDepth = 0.0;
      for (var c = 0; c < columns.length; c++) {
        var y = 0.0;
        for (var layer = 0; layer < layers[c]; layer++) {
          final model = fleet.models[_random.nextInt(fleet.models.length)];
          final scale = math.min(1.0, (halfRoad - 0.1) / model.length);
          final car = Node(mesh: model.mesh(_random.nextInt(TeslaModel.colorCount)))
            ..position = vm.Vector3(columns[c], y, z + model.width * scale / 2)
            ..rotation = _random.nextBool() ? _sideways : _sidewaysFlipped
            ..scale = vm.Vector3.all(scale);
          node.add(car);
          y += model.height * scale * 0.94;
          rowDepth = math.max(rowDepth, model.width * scale);
        }
        tops[c] = math.max(tops[c], y + 0.06);
      }
      z += rowDepth + 0.15;
    }

    final piles = [Pile(-halfRoad, 0, tops[0]), Pile(0, halfRoad, tops[1])];
    return Block(node, start, z, piles);
  }
}
