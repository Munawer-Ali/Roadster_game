import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/kit.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game/roadster_game.dart';
import 'game/tesla_fleet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RoadsterApp());
}

class RoadsterApp extends StatelessWidget {
  const RoadsterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roadster Hop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final game = RoadsterGame();
  final focus = FocusNode();
  final keys = <LogicalKeyboardKey>{};
  bool ready = false;
  bool demoEnded = false;

  @override
  void initState() {
    super.initState();
    game.demo = Uri.base.queryParameters.containsKey('demo');
    game.sounds.log = game.demo;
    Scene.initializeStaticResources().then((_) async {
      Node? model;
      try {
        final loaded = await loadScene('assets/roadster.glb');
        model = Node()..add(loaded);
      } catch (error) {
        debugPrint('roadster model failed to load: $error');
      }
      game.build(playerModel: model, fleet: await TeslaFleet.load());
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  bool held(List<LogicalKeyboardKey> options) => options.any(keys.contains);

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    final down = event is KeyDownEvent;
    final key = event.logicalKey;
    game.sounds.unlock();
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) {
      if (down) game.flip();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      if (down && game.state.value == GameState.crashed) {
        game.start();
      } else {
        game.thrust(down);
      }
      return KeyEventResult.handled;
    }
    down ? keys.add(key) : keys.remove(key);
    final x =
        (held([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD]) ? 1.0 : 0.0) -
        (held([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA]) ? 1.0 : 0.0);
    final y =
        (held([LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS]) ? 1.0 : 0.0) -
        (held([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW]) ? 1.0 : 0.0);
    game.setStick(vm.Vector2(x, y));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: onKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: SceneView(
                game.scene,
                camera: game.camera,
                onTick: (_, dt) {
                  game.tick(dt);
                  if (game.demo && game.demoDone && !demoEnded) {
                    demoEnded = true;
                    debugPrint('DEMO END');
                  }
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: Hud(game: game)),
            ),
            Positioned(
              left: 28,
              bottom: 36,
              child: SafeArea(
                child: game.demo
                    ? DemoStick(game: game)
                    : VirtualJoystick(radius: 64, knobRadius: 26, deadzone: 0.08, onChanged: game.setStick),
              ),
            ),
            Positioned(
              right: 28,
              bottom: 44,
              child: SafeArea(child: FlyButton(game: game)),
            ),
            Positioned(
              right: 43,
              bottom: 160,
              child: SafeArea(child: FlipButton(game: game)),
            ),
            Positioned.fill(
              child: IgnorePointer(child: FlipPopup(game: game)),
            ),
            Positioned.fill(child: GameOverlay(game: game)),
          ],
        ),
      ),
    );
  }
}

class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});
  final RoadsterGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder(
            valueListenable: game.score,
            builder: (_, value, _) => Stat(label: 'SCORE', value: '$value'),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder(
            valueListenable: game.level,
            builder: (_, value, _) => Stat(label: 'LEVEL', value: '$value'),
          ),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: game.air,
            builder: (_, value, _) => AirTank(value: value),
          ),
        ],
      ),
    );
  }
}

const hudText = TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, letterSpacing: 1.5);

class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: hudText.copyWith(fontSize: 10, color: const Color(0xFFFFD54F))),
          Text(value, style: hudText.copyWith(fontSize: 20, color: Colors.white)),
        ],
      ),
    );
  }
}

class AirTank extends StatelessWidget {
  const AirTank({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value < 0.25 ? const Color(0xFFFF5252) : const Color(0xFF40C4FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF80D8FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('AIR', style: hudText.copyWith(fontSize: 10, color: const Color(0xFF80D8FF))),
          const SizedBox(height: 6),
          Container(
            width: 90,
            height: 12,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: Colors.white12),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FlyButton extends StatefulWidget {
  const FlyButton({super.key, required this.game});
  final RoadsterGame game;

  @override
  State<FlyButton> createState() => _FlyButtonState();
}

class _FlyButtonState extends State<FlyButton> {
  bool pressed = false;

  void press(bool value) {
    if (value) widget.game.sounds.unlock();
    if (value && widget.game.state.value == GameState.crashed) return;
    setState(() => pressed = value);
    widget.game.thrust(value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => press(true),
      onPointerUp: (_) => press(false),
      onPointerCancel: (_) => press(false),
      child: ValueListenableBuilder(
        valueListenable: widget.game.flying,
        builder: (_, flying, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF40C4FF).withValues(alpha: pressed || flying ? 0.7 : 0.3),
            border: Border.all(color: const Color(0xFF80D8FF), width: 3),
          ),
          alignment: Alignment.center,
          child: Text('FLY', style: hudText.copyWith(fontSize: 18, color: Colors.white)),
        ),
      ),
    );
  }
}

class FlipButton extends StatefulWidget {
  const FlipButton({super.key, required this.game});
  final RoadsterGame game;

  @override
  State<FlipButton> createState() => _FlipButtonState();
}

class _FlipButtonState extends State<FlipButton> {
  bool pressed = false;

  void press(bool value) {
    setState(() => pressed = value);
    if (!value) return;
    widget.game.sounds.unlock();
    widget.game.flip();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => press(true),
      onPointerUp: (_) => press(false),
      onPointerCancel: (_) => press(false),
      child: ValueListenableBuilder(
        valueListenable: widget.game.flipping,
        builder: (_, flipping, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFD54F).withValues(alpha: pressed || flipping ? 0.7 : 0.25),
            border: Border.all(color: const Color(0xFFFFE082), width: 3),
          ),
          alignment: Alignment.center,
          child: Text('FLIP', style: hudText.copyWith(fontSize: 14, color: Colors.white)),
        ),
      ),
    );
  }
}

class DemoStick extends StatelessWidget {
  const DemoStick({super.key, required this.game});
  final RoadsterGame game;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: ValueListenableBuilder(
        valueListenable: game.stick,
        builder: (_, value, _) => Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white38, width: 2),
              ),
            ),
            Align(
              alignment: Alignment(value.x * 0.6, value.y * 0.6),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FlipPopup extends StatefulWidget {
  const FlipPopup({super.key, required this.game});
  final RoadsterGame game;

  @override
  State<FlipPopup> createState() => _FlipPopupState();
}

class _FlipPopupState extends State<FlipPopup> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    widget.game.flipBonus.addListener(controller.forward0);
  }

  @override
  void dispose() {
    widget.game.flipBonus.removeListener(controller.forward0);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = controller.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        return Align(
          alignment: Alignment(0, -0.35 - t * 0.2),
          child: Opacity(
            opacity: 1 - t,
            child: Text(
              'FLIP +${RoadsterGame.flipPoints}',
              style: hudText.copyWith(fontSize: 30, color: const Color(0xFFFFD54F)),
            ),
          ),
        );
      },
    );
  }
}

extension on AnimationController {
  void forward0() => forward(from: 0);
}

class GameOverlay extends StatelessWidget {
  const GameOverlay({super.key, required this.game});
  final RoadsterGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: game.state,
      builder: (_, state, _) {
        if (state == GameState.playing) return const SizedBox.shrink();
        final crashed = state == GameState.crashed;
        return GestureDetector(
          onTap: () {
            game.sounds.unlock();
            game.start();
          },
          child: Container(
            color: Colors.black.withValues(alpha: crashed ? 0.55 : 0.35),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  crashed ? 'CRASH!' : 'ROADSTER HOP',
                  textAlign: TextAlign.center,
                  style: hudText.copyWith(fontSize: 40, color: crashed ? const Color(0xFFFF5252) : Colors.white),
                ),
                const SizedBox(height: 12),
                if (crashed)
                  Text(
                    'SCORE ${game.score.value}   BEST ${game.best}',
                    style: hudText.copyWith(fontSize: 18, color: const Color(0xFFFFD54F)),
                  ),
                if (!crashed)
                  Text(
                    'Hold FLY / Space to rise\nJoystick: steer & aim your landing\nFLIP / F: barrel roll dodge (+25 in air)\nGreen ring = road, red ring = cars\nNever land on the Teslas!',
                    textAlign: TextAlign.center,
                    style: hudText.copyWith(fontSize: 14, color: Colors.white70, height: 1.6),
                  ),
                const SizedBox(height: 28),
                Text(
                  crashed ? 'TAP TO RETRY' : 'TAP TO START',
                  style: hudText.copyWith(fontSize: 18, color: const Color(0xFF80D8FF)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
