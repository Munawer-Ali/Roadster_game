import 'dart:math' as math;

class FlipPose {
  const FlipPose(this.roll, this.torque);
  final double roll;
  final double torque;
}

class FlipMotion {
  static const spinUp = 0.18;
  static const coast = 0.36;
  static const duration = spinUp * 2 + coast;
  static const spinRate = 2 * math.pi / (spinUp * spinUp + spinUp * coast);
  static const kickPower = 1.4;

  static FlipPose at(double t, double turn) {
    if (t < 0 || t >= duration) return const FlipPose(0, 0);
    if (t < spinUp) return FlipPose(turn * 0.5 * spinRate * t * t, turn);
    if (t < spinUp + coast) {
      return FlipPose(turn * (0.5 * spinRate * spinUp * spinUp + spinRate * spinUp * (t - spinUp)), 0);
    }
    final left = duration - t;
    return FlipPose(turn * (2 * math.pi - 0.5 * spinRate * left * left), -turn);
  }

  static double kick(double t, double direction) => t >= 0 && t < spinUp ? direction * kickPower : 0;
}
