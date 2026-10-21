import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class Sounds {
  final _thrust = AudioPlayer();
  final _side = AudioPlayer();
  final _thrustLevel = _Fader();
  final _sideLevel = _Fader();
  bool _unlocked = false;
  bool log = false;

  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    for (final (player, file) in [(_thrust, 'thrust.wav'), (_side, 'side_jet.wav')]) {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0);
      await player.play(AssetSource('sfx/$file'));
    }
  }

  void loops({required double thrust, required double side}) {
    if (log) debugPrint('LOOP ${thrust.toStringAsFixed(2)} ${side.toStringAsFixed(2)}');
    if (!_unlocked) return;
    _thrustLevel.set(_thrust, thrust * 0.7);
    _sideLevel.set(_side, side * 0.45);
  }

  void flip() => _shot('flip.wav', 0.8);
  void land() => _shot('land.wav', 0.7);
  void crash() => _shot('crash.wav', 0.9);
  void bonus() => _shot('bonus.wav', 0.5);

  void _shot(String file, double volume) {
    if (log) debugPrint('SFX $file $volume');
    if (!_unlocked) return;
    final player = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    player.play(AssetSource('sfx/$file'), volume: volume);
    player.onPlayerComplete.first.then((_) => player.dispose());
  }
}

class _Fader {
  double _sent = -1;

  void set(AudioPlayer player, double volume) {
    if ((volume - _sent).abs() < 0.03) return;
    _sent = volume;
    player.setVolume(volume);
  }
}
