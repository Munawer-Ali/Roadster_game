import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

class _Puff {
  _Puff(this.node, this.material);
  final Node node;
  final UnlitMaterial material;
  vm.Vector3 velocity = vm.Vector3.zero();
  double age = 1;
  double life = 1;
  double size = 1;
}

class Smoke {
  Smoke(Scene scene, {int count = 260}) {
    final shape = IcosphereGeometry(radius: 0.5, subdivisions: 1);
    for (var i = 0; i < count; i++) {
      final material = UnlitMaterial()
        ..alphaMode = AlphaMode.blend
        ..baseColorFactor = vm.Vector4(0.9, 0.92, 0.95, 0);
      final node = Node(mesh: Mesh(shape, material))
        ..visible = false
        ..shadowCastingMode = ShadowCastingMode.off;
      scene.add(node);
      _puffs.add(_Puff(node, material));
    }
  }

  final List<_Puff> _puffs = [];
  final _random = math.Random();
  int _next = 0;

  void emit(vm.Vector3 position, vm.Vector3 velocity, double size) {
    final puff = _puffs[_next];
    _next = (_next + 1) % _puffs.length;
    final jitter = vm.Vector3(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5, _random.nextDouble() - 0.5);
    puff
      ..age = 0
      ..life = 0.7 + _random.nextDouble() * 0.5
      ..size = size * (0.8 + _random.nextDouble() * 0.4)
      ..velocity = velocity + jitter * 1.5;
    puff.node
      ..position = position.clone()
      ..visible = true;
  }

  void tick(double dt) {
    for (final puff in _puffs) {
      if (puff.age >= puff.life) continue;
      puff.age += dt;
      final t = puff.age / puff.life;
      if (t >= 1) {
        puff.node.visible = false;
        continue;
      }
      puff.velocity.scale(math.max(0, 1 - dt * 3));
      puff.velocity.y += dt * 1.2;
      puff.node.position = puff.node.position + puff.velocity * dt;
      puff.node.scale = vm.Vector3.all(puff.size * (0.4 + t * 1.8));
      final shade = 0.95 - t * 0.25;
      puff.material.baseColorFactor = vm.Vector4(shade, shade, shade + 0.03, 0.55 * (1 - t) * (1 - t));
    }
  }

  void clear() {
    for (final puff in _puffs) {
      puff.age = puff.life;
      puff.node.visible = false;
    }
  }
}
