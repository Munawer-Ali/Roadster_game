import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'blocks.dart';
import 'car_builder.dart';
import 'flip_motion.dart';
import 'road.dart';
import 'smoke.dart';
import 'sounds.dart';
import 'tesla_fleet.dart';

enum GameState { ready, playing, crashed }

class RoadsterGame {
  final Scene scene = Scene();
  final PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 58 * vm.degrees2Radians,
    position: vm.Vector3(0, 4.5, -11),
    target: vm.Vector3(0, 1.4, 10),
  );

  final state = ValueNotifier(GameState.ready);
  final score = ValueNotifier(0);
  final level = ValueNotifier(1);
  final air = ValueNotifier(1.0);
  final flipBonus = ValueNotifier(0);
  final sounds = Sounds();
  final flying = ValueNotifier(false);
  final flipping = ValueNotifier(false);
  final stick = ValueNotifier(vm.Vector2.zero());
  bool demo = false;
  double _demoTime = 0;
  double _lastFlip = 0;
  double _crashedAt = -1;
  int best = 0;

  static const gravity = 16.0;
  static const thrustPower = 34.0;
  static const maxRise = 9.0;
  static const drain = 0.36;
  static const refill = 0.32;
  static const halfWidth = 1.0;
  static const halfLength = 2.25;
  static const sideLimit = roadHalfWidth - halfWidth - 0.1;
  static const sideSpeed = 7.5;
  static const sideJetPower = 55.0;
  static const flipPoints = 25;

  late final Road _road;
  late final Node _player;
  late final Thrusters _thrusters;
  late final Smoke _smoke;
  late final BlockBuilder _builder;
  late final Node _marker;
  late final Material _safe;
  late final Material _danger;
  final List<Block> _blocks = [];
  final _random = math.Random();

  double _x = 0;
  double _vx = 0;
  double _push = 0;
  double _speed = 0;
  double _puffClock = 0;
  double _flip = -1;
  double _flipDir = 1;
  double _roll = 0;
  double _torque = 0;
  int _bonus = 0;
  double _y = 0;
  double _vy = 0;
  double _z = 0;
  double _time = 0;
  double _nextBlock = 70;
  double _flame = 0;
  double _shake = 0;
  bool _thrusting = false;
  vm.Vector2 _stick = vm.Vector2.zero();

  bool get airborne => _y > 0.001 || _vy > 0;

  void build({Node? playerModel, required TeslaFleet fleet}) {
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: vm.Vector3(0.12, 0.32, 0.75),
        horizonColor: vm.Vector3(0.75, 0.82, 0.92),
        sunDirection: vm.Vector3(0.3, 0.35, -0.9),
      ),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.35, -1, 0.45),
      intensity: 3,
      castsShadow: true,
      shadowMaxDistance: 70,
      shadowCascadeCount: 2,
    );
    scene.fog
      ..enabled = true
      ..mode = FogMode.linear
      ..start = 70
      ..end = 210
      ..color = vm.Vector3(0.75, 0.82, 0.92);

    _road = Road(scene);
    _builder = BlockBuilder(fleet);

    _player = Node(name: 'player');
    if (playerModel != null) {
      _player.add(playerModel);
      addLaunchLights(_player);
    } else {
      _player.add(buildCar(vm.Vector4(0.9, 0.9, 0.92, 1)));
    }
    _thrusters = Thrusters(_player);
    scene.add(_player);
    _smoke = Smoke(scene);

    _safe = UnlitMaterial()
      ..baseColorFactor = vm.Vector4(0.2, 1, 0.45, 1)
      ..depthLayer = 2;
    _danger = UnlitMaterial()
      ..baseColorFactor = vm.Vector4(1, 0.15, 0.15, 1)
      ..depthLayer = 2;
    _marker = Node(mesh: Mesh(RingGeometry(innerRadius: 0.9, outerRadius: 1.15, segments: 40), _safe))
      ..visible = false
      ..shadowCastingMode = ShadowCastingMode.off;
    scene.add(_marker);
  }

  void setStick(vm.Vector2 value) => stick.value = _stick = value;

  void thrust(bool on) {
    if (on && state.value == GameState.ready) start();
    _thrusting = on && state.value == GameState.playing;
  }

  void flip() {
    if (state.value != GameState.playing || _flip >= 0) return;
    _flipDir = _stick.x.abs() > 0.2 ? _stick.x.sign : (_x > 0 ? -1 : 1);
    _flip = 0;
    if (!airborne) _vy = 8;
    sounds.flip();
  }

  void start() {
    for (final block in _blocks) {
      scene.remove(block.node);
    }
    _blocks.clear();
    _x = 0;
    _vx = 0;
    _push = 0;
    _flip = -1;
    _roll = 0;
    _torque = 0;
    _smoke.clear();
    _bonus = 0;
    _y = 0;
    _vy = 0;
    _z = 0;
    _time = 0;
    _nextBlock = 70;
    _flame = 0;
    _shake = 0;
    _thrusting = false;
    _demoTime = 0;
    _lastFlip = 0;
    _crashedAt = -1;
    air.value = 1;
    score.value = 0;
    level.value = 1;
    _road.reset();
    state.value = GameState.playing;
  }

  void tick(double dt) {
    dt = math.min(dt, 1 / 20);
    _time += dt;
    if (demo) _autopilot(dt);
    if (state.value == GameState.playing) {
      _fly(dt);
      _spawn();
      _checkCrash();
    }
    _shake = math.max(0, _shake - dt * 2);
    _flame += ((_thrusting ? 1.0 : (airborne ? 0.12 : 0.0)) - _flame) * math.min(1, dt * 12);
    _thrusters.set(_flame, _push, _torque, _time);
    _smoke.tick(dt);
    flying.value = _thrusting;
    flipping.value = _flip >= 0;
    final live = state.value == GameState.playing;
    sounds.loops(thrust: live ? _flame : 0, side: live ? math.max(_push.abs(), _torque.abs()) : 0);
    _placePlayer();
    _puff(dt);
    _placeMarker();
    _placeCamera(dt);
  }

  void _fly(double dt) {
    level.value = 1 + (_z / 500).floor();
    final speed = _speed = math.min(18 + (level.value - 1) * 1.6, 34.0);

    final wasAirborne = airborne;
    _flipStep(dt);
    final across = math.cos(_roll);
    final tilt = math.sin(_roll);
    if (_thrusting && air.value > 0) {
      _vy += thrustPower * across * dt;
      _vx -= thrustPower * tilt * dt;
      air.value = math.max(0, air.value - drain * dt);
    }
    _vy = math.min(_vy - gravity * dt, maxRise);
    _y += _vy * dt;
    if (_y <= 0) {
      if (wasAirborne && _vy < -6) _shake = 0.5;
      if (wasAirborne) sounds.land();
      _y = 0;
      _vy = 0;
    }
    if (!airborne && !_thrusting) {
      air.value = math.min(1, air.value + refill * dt);
    }

    final reach = airborne ? 1 - _stick.y * 0.35 : 1.0;
    _z += speed * reach * dt;
    if (_flip < 0) {
      final target = _stick.x * sideSpeed;
      final grip = airborne ? 3.5 : 14.0;
      final change = (target - _vx) * math.min(1, dt * grip);
      _vx += change;
      final steer = airborne ? (change / dt / 25).clamp(-1.0, 1.0) : 0.0;
      _push += (steer - _push) * math.min(1, dt * 10);
    } else {
      final kick = FlipMotion.kick(_flip, _flipDir);
      _push += (kick - _push) * math.min(1, dt * 30);
      _vx += _push / FlipMotion.kickPower * sideJetPower * across * dt;
      _vy += _push / FlipMotion.kickPower * sideJetPower * tilt * dt;
      _vx *= 1 - math.min(1, dt * 0.4);
    }
    _x += _vx * dt;
    if (_x.abs() > sideLimit) {
      _x = _x.clamp(-sideLimit, sideLimit);
      _vx = 0;
    }

    score.value = (_z / 5).floor() + _bonus;
    _road.follow(_z);
  }

  void _spawn() {
    while (_nextBlock < _z + 190) {
      final block = _builder.build(_nextBlock, level.value);
      scene.add(block.node);
      _blocks.add(block);
      final gap = math.max(24.0, 46 - level.value * 2.5);
      _nextBlock = block.end + gap + _random.nextDouble() * 12;
    }
    while (_blocks.isNotEmpty && _blocks.first.end < _z - 20) {
      scene.remove(_blocks.removeAt(0).node);
    }
  }

  double _surfaceAt(double x, double z) {
    var top = 0.0;
    for (final block in _blocks) {
      if (z + halfLength < block.start || z - halfLength > block.end) continue;
      for (final pile in block.piles) {
        if (x + halfWidth < pile.minX || x - halfWidth > pile.maxX) continue;
        top = math.max(top, pile.top);
      }
    }
    return top;
  }

  void _checkCrash() {
    if (_y < _surfaceAt(_x, _z) - 0.05) {
      state.value = GameState.crashed;
      _thrusting = false;
      _shake = 1;
      _flip = -1;
      _roll = 0;
      _torque = 0;
      _push = 0;
      _crashedAt = _time;
      sounds.crash();
      best = math.max(best, score.value);
    }
  }

  void _placePlayer() {
    final bank = _flip < 0 ? -(_vx / sideSpeed).clamp(-1.0, 1.0) * 0.22 : 0.0;
    final roll = bank + _roll;
    final pitch = airborne ? -_vy * 0.02 : 0.0;
    final rotation =
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), pitch) * vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), roll);
    final pivot = vm.Vector3(0, 0.6, 0);
    _player.position = vm.Vector3(_x, _y, _z) + pivot - rotation.rotated(pivot);
    _player.rotation = rotation;
  }

  void _flipStep(double dt) {
    if (_flip < 0) return;
    _flip += dt;
    if (_flip < FlipMotion.duration) {
      final pose = FlipMotion.at(_flip, -_flipDir);
      _roll = pose.roll;
      _torque = pose.torque;
    } else {
      _flip = -1;
      _roll = 0;
      _torque = 0;
      if (airborne) {
        _bonus += flipPoints;
        flipBonus.value++;
        sounds.bonus();
      }
    }
  }

  void _puff(double dt) {
    if (state.value != GameState.playing) return;
    final rotation = _player.rotation;
    final carry = vm.Vector3(_vx * 0.5, _vy * 0.3, _speed * 0.25);
    if (!_thrusters.jets.any((jet) => jet.power >= 0.1)) {
      _puffClock = 0;
      return;
    }
    _puffClock += dt * 28;
    while (_puffClock >= 1) {
      _puffClock -= 1;
      for (final jet in _thrusters.jets) {
        if (jet.power < 0.1) continue;
        final out = rotation.rotated(jet.direction);
        final tip = jet.origin + jet.direction * (0.5 + jet.power * 0.7);
        final position = _player.position + rotation.rotated(tip);
        _smoke.emit(position, out * (5 + jet.power * 6) + carry, 0.3 + jet.power * 0.3);
      }
    }
  }

  bool _willHit(double lookahead) {
    var y = _y;
    var vy = _vy;
    var z = _z;
    const step = 1 / 30;
    for (var t = 0.0; t < lookahead; t += step) {
      vy -= gravity * step;
      y += vy * step;
      z += _speed * step;
      if (y < _surfaceAt(_x, z) + 0.9) return true;
      if (y <= 0) return false;
    }
    return false;
  }

  void _autopilot(double dt) {
    if (state.value == GameState.ready) {
      _demoTime += dt;
      if (_demoTime > 2.2) start();
      return;
    }
    if (state.value != GameState.playing) return;
    _demoTime += dt;

    Block? next;
    for (final block in _blocks) {
      if (block.end > _z - halfLength) {
        next = block;
        break;
      }
    }
    var aim = 0.0;
    if (next != null) {
      final low = next.piles[0].top <= next.piles[1].top ? next.piles[0] : next.piles[1];
      aim = (low.minX + low.maxX) / 2;
    }
    aim += math.sin(_demoTime * 1.3) * 0.6;
    final steer = ((aim - _x) * 0.6).clamp(-1.0, 1.0);

    final ending = _demoTime > 27;
    final danger = !ending && _willHit(1.4);
    final over = _surfaceAt(_x, _z);
    final high = _y - over;
    final canFlip =
        !ending && airborne && _flip < 0 && high > 2.2 && _vy > -1 && _demoTime - _lastFlip > 2.6 && !_willHit(1.1);

    setStick(vm.Vector2(steer, 0));
    if (canFlip) {
      _lastFlip = _demoTime;
      setStick(vm.Vector2(_x > 0 ? -1 : 1, 0));
      flip();
    }
    final wantThrust = _flip < 0 && danger && air.value > 0;
    if (wantThrust != _thrusting) thrust(wantThrust);
  }

  bool get demoDone => _crashedAt >= 0 && _time - _crashedAt > 3;

  void _placeMarker() {
    final show = airborne && state.value == GameState.playing;
    _marker.visible = show;
    if (!show) return;
    final top = _surfaceAt(_x, _z);
    _marker.mesh!.primitives.first.material = top > 0 ? _danger : _safe;
    _marker.position = vm.Vector3(_x, top + 0.03, _z);
  }

  void _placeCamera(double dt) {
    final shakeX = math.sin(_time * 47) * _shake * 0.12;
    final shakeY = math.cos(_time * 53) * _shake * 0.1;
    final clearance = math.max(_surfaceAt(_x * 0.5, _z - 11), _surfaceAt(_x * 0.5, _z - 6)) + 2.5;
    final height = math.max(4.5 + _y * 0.75, clearance);
    final desired = vm.Vector3(_x * 0.5 + shakeX, height + shakeY, _z - 11);
    final follow = math.min(1.0, dt * 5);
    final eased = camera.position + (desired - camera.position) * follow;
    camera.position = vm.Vector3(eased.x, eased.y, desired.z);
    camera.target = vm.Vector3(_x * 0.7, 1.4 + _y * 0.7, _z + 10);
  }
}
