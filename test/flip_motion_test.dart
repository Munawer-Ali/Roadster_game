import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:roadster_hop/game/flip_motion.dart';

void main() {
  const step = 1 / 600;
  const spinUp = FlipMotion.spinUp;
  const duration = FlipMotion.duration;

  test('starts level and ends exactly one full turn later', () {
    expect(FlipMotion.at(0, 1).roll, 0);
    expect(FlipMotion.at(duration - 1e-9, 1).roll, closeTo(2 * math.pi, 1e-6));
    expect(FlipMotion.at(duration, 1).roll, 0);
  });

  test('roll never jumps between frames', () {
    var previous = FlipMotion.at(0, 1).roll;
    for (var t = step; t < duration; t += step) {
      final roll = FlipMotion.at(t, 1).roll;
      expect((roll - previous).abs(), lessThan(0.05), reason: 'jump at t=$t');
      previous = roll;
    }
  });

  test('roll only moves forward', () {
    var previous = 0.0;
    for (var t = step; t < duration; t += step) {
      final roll = FlipMotion.at(t, 1).roll;
      expect(roll, greaterThanOrEqualTo(previous));
      previous = roll;
    }
  });

  test('jets push, coast, then brake', () {
    expect(FlipMotion.at(spinUp / 2, 1).torque, 1);
    expect(FlipMotion.at(spinUp + FlipMotion.coast / 2, 1).torque, 0);
    expect(FlipMotion.at(duration - spinUp / 2, 1).torque, -1);
  });

  test('spin speed matches the jets: speeds up, stays steady, stops at the end', () {
    double speed(double t) => (FlipMotion.at(t + step, 1).roll - FlipMotion.at(t - step, 1).roll) / (2 * step);
    final peak = FlipMotion.spinRate * spinUp;
    expect(speed(spinUp / 2), closeTo(peak / 2, 0.1));
    expect(speed(spinUp + 0.1), closeTo(peak, 0.1));
    expect(speed(spinUp + 0.3), closeTo(peak, 0.1));
    expect(speed(duration - 2 * step), closeTo(FlipMotion.spinRate * 2 * step, 0.01));
  });

  test('turning the other way mirrors the whole flip', () {
    for (var t = 0.0; t < duration; t += 0.05) {
      final right = FlipMotion.at(t, 1);
      final left = FlipMotion.at(t, -1);
      expect(left.roll, closeTo(-right.roll, 1e-9));
      expect(left.torque, -right.torque);
    }
  });

  test('side kick fires only while spinning up, toward the dash', () {
    expect(FlipMotion.kick(0.05, 1), FlipMotion.kickPower);
    expect(FlipMotion.kick(0.05, -1), -FlipMotion.kickPower);
    expect(FlipMotion.kick(spinUp + 0.01, 1), 0);
    expect(FlipMotion.kick(-0.01, 1), 0);
  });

  test('nothing happens outside the flip', () {
    for (final t in [-1.0, duration, duration + 1]) {
      final pose = FlipMotion.at(t, 1);
      expect(pose.roll, 0);
      expect(pose.torque, 0);
    }
  });
}
