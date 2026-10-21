import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

PhysicallyBasedMaterial paint(vm.Vector4 color, {double metallic = 0.0, double roughness = 0.6}) {
  return PhysicallyBasedMaterial()
    ..baseColorFactor = color
    ..metallicFactor = metallic
    ..roughnessFactor = roughness;
}

PhysicallyBasedMaterial glow(vm.Vector4 color, double strength) {
  return PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0, 0, 0, 1)
    ..metallicFactor = 0
    ..roughnessFactor = 1
    ..emissiveFactor = color
    ..emissiveStrength = strength;
}

final _glass = paint(vm.Vector4(0.03, 0.04, 0.06, 1), metallic: 0.2, roughness: 0.1);
final _tyre = paint(vm.Vector4(0.04, 0.04, 0.04, 1), roughness: 0.9);
final _rim = paint(vm.Vector4(0.15, 0.15, 0.16, 1), metallic: 1, roughness: 0.3);
final _headlight = glow(vm.Vector4(1, 0.95, 0.85, 1), 3);
final _taillight = glow(vm.Vector4(1, 0.02, 0.02, 1), 2);

Node part(Geometry geometry, Material material, vm.Vector3 position) {
  return Node(mesh: Mesh(geometry, material))..position = position;
}

class Station {
  const Station(this.z, this.bottom, this.top, this.width, this.topWidth);
  final double z;
  final double bottom;
  final double top;
  final double width;
  final double topWidth;
}

double _spline(double a, double b, double c, double d, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
}

List<Station> smooth(List<Station> keys, int steps) {
  final out = <Station>[];
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[math.max(i - 1, 0)];
    final b = keys[i];
    final c = keys[i + 1];
    final d = keys[math.min(i + 2, keys.length - 1)];
    for (var s = 0; s < steps; s++) {
      final t = s / steps;
      out.add(
        Station(
          _spline(a.z, b.z, c.z, d.z, t),
          _spline(a.bottom, b.bottom, c.bottom, d.bottom, t),
          _spline(a.top, b.top, c.top, d.top, t),
          _spline(a.width, b.width, c.width, d.width, t),
          _spline(a.topWidth, b.topWidth, c.topWidth, d.topWidth, t),
        ),
      );
    }
  }
  out.add(keys.last);
  return out;
}

List<vm.Vector3> _ring(Station s) {
  final mid = s.bottom + (s.top - s.bottom) * 0.55;
  final low = s.bottom + (s.top - s.bottom) * 0.12;
  final points = [
    vm.Vector2(s.width * 0.86, s.bottom),
    vm.Vector2(s.width, low),
    vm.Vector2(s.width, mid),
    vm.Vector2(s.topWidth, s.top - (s.top - mid) * 0.25),
    vm.Vector2(s.topWidth * 0.55, s.top),
    vm.Vector2(-s.topWidth * 0.55, s.top),
    vm.Vector2(-s.topWidth, s.top - (s.top - mid) * 0.25),
    vm.Vector2(-s.width, mid),
    vm.Vector2(-s.width, low),
    vm.Vector2(-s.width * 0.86, s.bottom),
  ];
  return [for (final p in points) vm.Vector3(p.x, p.y, s.z)];
}

void _face(GeometryBuilder builder, vm.Vector3 a, vm.Vector3 b, vm.Vector3 c, vm.Vector3 outward) {
  final normal = (b - a).cross(c - a);
  if (normal.dot(outward) < 0) {
    final t = b;
    b = c;
    c = t;
  }
  builder.addTriangle(builder.addVertex(a), builder.addVertex(b), builder.addVertex(c));
}

MeshGeometry loft(List<Station> stations) {
  final builder = GeometryBuilder();
  final rings = [for (final s in stations) _ring(s)];
  for (var i = 0; i < rings.length - 1; i++) {
    final r0 = rings[i];
    final r1 = rings[i + 1];
    final n = r0.length;
    final center = vm.Vector3(0, (stations[i].bottom + stations[i].top) / 2, (stations[i].z + stations[i + 1].z) / 2);
    for (var j = 0; j < n; j++) {
      final k = (j + 1) % n;
      final mid = (r0[j] + r0[k] + r1[j] + r1[k]) * 0.25;
      final outward = mid - center;
      _face(builder, r0[j], r0[k], r1[k], outward);
      _face(builder, r0[j], r1[k], r1[j], outward);
    }
  }
  for (final end in [0, rings.length - 1]) {
    final ring = rings[end];
    final z = stations[end].z;
    final center = vm.Vector3(0, (stations[end].bottom + stations[end].top) / 2, z);
    final outward = vm.Vector3(0, 0, end == 0 ? 1 : -1);
    for (var j = 0; j < ring.length; j++) {
      _face(builder, center, ring[j], ring[(j + 1) % ring.length], outward);
    }
  }
  return builder.build();
}

final _bodyShape = loft(
  smooth(const [
    Station(2.2, 0.24, 0.5, 0.62, 0.5),
    Station(2.0, 0.22, 0.6, 0.86, 0.72),
    Station(1.4, 0.2, 0.72, 0.97, 0.8),
    Station(0.7, 0.2, 0.76, 0.95, 0.8),
    Station(-0.3, 0.2, 0.8, 0.94, 0.8),
    Station(-1.3, 0.2, 0.84, 1.0, 0.84),
    Station(-1.95, 0.24, 0.8, 0.94, 0.8),
    Station(-2.2, 0.32, 0.7, 0.8, 0.68),
  ], 4),
);

final _cabinShape = loft(
  smooth(const [
    Station(0.95, 0.7, 0.71, 0.78, 0.76),
    Station(0.35, 0.7, 1.0, 0.8, 0.6),
    Station(-0.25, 0.72, 1.14, 0.82, 0.56),
    Station(-0.9, 0.74, 1.1, 0.82, 0.56),
    Station(-1.55, 0.78, 0.9, 0.8, 0.6),
    Station(-1.95, 0.78, 0.8, 0.74, 0.62),
  ], 4),
);

Node buildCar(vm.Vector4 color) {
  final body = paint(color, metallic: 0.7, roughness: 0.22);
  final car = Node(name: 'car');

  car.add(part(_bodyShape, body, vm.Vector3.zero()));
  car.add(part(_cabinShape, _glass, vm.Vector3.zero()));

  for (final x in [-0.58, 0.58]) {
    car.add(part(CuboidGeometry(vm.Vector3(0.38, 0.06, 0.18)), _headlight, vm.Vector3(x, 0.6, 1.97)));
  }
  car.add(part(CuboidGeometry(vm.Vector3(1.5, 0.06, 0.06)), _taillight, vm.Vector3(0, 0.66, -2.2)));

  final tyre = CylinderGeometry(bottomRadius: 0.36, topRadius: 0.36, height: 0.28, radialSegments: 24);
  final rim = CylinderGeometry(bottomRadius: 0.24, topRadius: 0.24, height: 0.3, radialSegments: 18);
  final sideways = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2);
  for (final x in [-0.84, 0.84]) {
    for (final z in [-1.35, 1.4]) {
      car.add(part(tyre, _tyre, vm.Vector3(x, 0.36, z))..rotation = sideways);
      car.add(part(rim, _rim, vm.Vector3(x, 0.36, z))..rotation = sideways);
    }
  }
  return car;
}

void addLaunchLights(Node car) {
  car.add(
    part(
      CuboidGeometry(vm.Vector3(1.7, 0.05, 0.05)),
      glow(vm.Vector4(1, 0.02, 0.02, 1), 4),
      vm.Vector3(0, 0.82, -2.24),
    ),
  );
  car.add(
    part(CuboidGeometry(vm.Vector3(1.2, 0.03, 0.04)), glow(vm.Vector4(0.9, 0.95, 1, 1), 4), vm.Vector3(0, 0.5, 2.24)),
  );
}

class Jet {
  Jet(this.flame, this.origin, this.direction);
  final Node flame;
  final vm.Vector3 origin;
  final vm.Vector3 direction;
  double power = 0;
}

class Thrusters {
  Thrusters(Node car) {
    final nozzle = CylinderGeometry(bottomRadius: 0.12, topRadius: 0.16, height: 0.12, radialSegments: 12);
    final flame = CylinderGeometry(bottomRadius: 0.0, topRadius: 0.14, height: 1.0, radialSegments: 12);
    final flameColor = glow(vm.Vector4(0.25, 0.6, 1.0, 1), 4);
    for (final x in [-0.55, 0.55]) {
      for (final z in [-1.6, 0.0, 1.6]) {
        car.add(part(nozzle, _rim, vm.Vector3(x, 0.28, z)));
        final node = Node(mesh: Mesh(flame, flameColor))
          ..position = vm.Vector3(x, 0.22, z)
          ..visible = false
          ..shadowCastingMode = ShadowCastingMode.off;
        car.add(node);
        _flames.add(node);
      }
    }

    final jetFlame = CylinderGeometry(bottomRadius: 0.0, topRadius: 0.16, height: 1.0, radialSegments: 12);
    final jetNozzle = CylinderGeometry(bottomRadius: 0.1, topRadius: 0.14, height: 0.1, radialSegments: 12);
    final jetColor = glow(vm.Vector4(0.45, 0.75, 1.0, 1), 5);
    Jet jet(vm.Vector3 origin, vm.Vector3 direction) {
      final facing = _facing(direction);
      car.add(part(jetNozzle, _rim, origin)..rotation = facing);
      final node = Node(mesh: Mesh(jetFlame, jetColor))
        ..rotation = facing
        ..visible = false
        ..shadowCastingMode = ShadowCastingMode.off;
      car.add(node);
      final made = Jet(node, origin, direction);
      jets.add(made);
      return made;
    }

    for (final side in [-1.0, 1.0]) {
      for (final z in [-1.1, 1.1]) {
        (side < 0 ? _left : _right).add(jet(vm.Vector3(side * 1.0, 0.5, z), vm.Vector3(side, 0, 0)));
      }
      for (final z in [-0.6, 0.6]) {
        (side < 0 ? _leftUp : _rightUp).add(jet(vm.Vector3(side * 0.95, 0.84, z), vm.Vector3(0, 1, 0)));
        (side < 0 ? _leftDown : _rightDown).add(jet(vm.Vector3(side * 0.95, 0.16, z), vm.Vector3(0, -1, 0)));
      }
    }
  }

  static vm.Quaternion _facing(vm.Vector3 direction) {
    if (direction.y > 0.99) return vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi);
    return vm.Quaternion.fromTwoVectors(vm.Vector3(0, -1, 0), direction);
  }

  final List<Node> _flames = [];
  final List<Jet> jets = [];
  final List<Jet> _left = [];
  final List<Jet> _right = [];
  final List<Jet> _leftUp = [];
  final List<Jet> _rightUp = [];
  final List<Jet> _leftDown = [];
  final List<Jet> _rightDown = [];

  void set(double power, double push, double torque, double time) {
    final on = power > 0.02;
    for (var i = 0; i < _flames.length; i++) {
      final flame = _flames[i];
      flame.visible = on;
      if (!on) continue;
      final flicker = 0.85 + 0.15 * math.sin(time * 60 + i * 1.7);
      final length = (0.3 + power * 1.1) * flicker;
      flame.scale = vm.Vector3.all(length);
      flame.position = vm.Vector3(flame.position.x, 0.22 - length * 0.5, flame.position.z);
    }
    final lift = math.max(0.0, torque);
    final drop = math.max(0.0, -torque);
    for (final jet in _left) {
      jet.power = math.max(0, push);
    }
    for (final jet in _right) {
      jet.power = math.max(0, -push);
    }
    for (final jet in [..._rightDown, ..._leftUp]) {
      jet.power = lift;
    }
    for (final jet in [..._leftDown, ..._rightUp]) {
      jet.power = drop;
    }
    for (var i = 0; i < jets.length; i++) {
      final jet = jets[i];
      final visible = jet.power > 0.05;
      jet.flame.visible = visible;
      if (!visible) continue;
      final flicker = 0.8 + 0.2 * math.sin(time * 70 + i * 2.3);
      final length = (0.4 + jet.power * 1.5) * flicker;
      jet.flame.scale = vm.Vector3.all(length);
      jet.flame.position = jet.origin + jet.direction * (length * 0.5);
    }
  }
}
