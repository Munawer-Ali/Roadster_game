import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'car_builder.dart';

const laneWidth = 3.0;
const roadHalfWidth = 4.8;
const segmentLength = 40.0;
const segmentCount = 7;

class Road {
  Road(Scene scene) {
    final asphalt = paint(vm.Vector4(0.12, 0.12, 0.13, 1), roughness: 0.85);
    final grass = paint(vm.Vector4(0.16, 0.42, 0.14, 1), roughness: 1);
    final white = paint(vm.Vector4(0.9, 0.9, 0.9, 1), roughness: 0.7)..depthLayer = 1;
    final pole = paint(vm.Vector4(0.6, 0.6, 0.62, 1), metallic: 0.8, roughness: 0.4);
    final lamp = glow(vm.Vector4(1, 0.85, 0.6, 1), 4);

    final roadPlane = PlaneGeometry(width: roadHalfWidth * 2, depth: segmentLength);
    final grassPlane = PlaneGeometry(width: 60, depth: segmentLength);
    final dash = PlaneGeometry(width: 0.16, depth: 3);
    final edge = PlaneGeometry(width: 0.18, depth: segmentLength);
    final post = CylinderGeometry(bottomRadius: 0.08, topRadius: 0.06, height: 5, radialSegments: 10);
    final arm = CuboidGeometry(vm.Vector3(1.4, 0.1, 0.1));
    final bulb = CuboidGeometry(vm.Vector3(0.5, 0.08, 0.25));

    for (var i = 0; i < segmentCount; i++) {
      final segment = Node(name: 'segment$i');
      segment.add(part(roadPlane, asphalt, vm.Vector3(0, 0, 0)));
      segment.add(part(grassPlane, grass, vm.Vector3(-roadHalfWidth - 30, 0, 0)));
      segment.add(part(grassPlane, grass, vm.Vector3(roadHalfWidth + 30, 0, 0)));
      for (final x in [-roadHalfWidth + 0.3, roadHalfWidth - 0.3]) {
        segment.add(part(edge, white, vm.Vector3(x, 0, 0)));
      }
      for (final x in [-laneWidth / 2, laneWidth / 2]) {
        for (var z = -segmentLength / 2 + 2.5; z < segmentLength / 2; z += 8) {
          segment.add(part(dash, white, vm.Vector3(x, 0, z)));
        }
      }
      for (final side in [-1.0, 1.0]) {
        final x = side * (roadHalfWidth + 0.8);
        segment.add(part(post, pole, vm.Vector3(x, 2.5, 0)));
        segment.add(part(arm, pole, vm.Vector3(x - side * 0.6, 5, 0)));
        segment.add(part(bulb, lamp, vm.Vector3(x - side * 1.1, 4.92, 0)));
      }
      segment.position = vm.Vector3(0, 0, i * segmentLength);
      scene.add(segment);
      _segments.add(segment);
    }
  }

  final List<Node> _segments = [];

  void reset() {
    for (var i = 0; i < _segments.length; i++) {
      _segments[i].position = vm.Vector3(0, 0, i * segmentLength);
    }
  }

  void follow(double playerZ) {
    for (final segment in _segments) {
      final z = segment.position.z;
      if (z + segmentLength / 2 < playerZ - 20) {
        segment.position = vm.Vector3(0, 0, z + segmentLength * segmentCount);
      }
    }
  }
}
