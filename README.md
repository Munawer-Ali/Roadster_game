# Roadster Hop

A 3D Flutter remake of **F1 Race**, the game on old MTK keypad phones with the button that made your car fly over traffic. This time you fly the new 2026 Tesla Roadster over piles of parked Teslas.

https://github.com/user-attachments/assets/77dc9c41-3e7e-4d54-9d60-11c884220c74


## How to play

| Action | Touch | Keyboard |
| --- | --- | --- |
| Fly up (uses air) | Hold **FLY** | Hold **Space** |
| Steer, and aim your landing | Joystick | Arrows / **WASD** |
| Barrel roll and side dash | **FLIP** | **F** or **Shift** |

- The ring under the car shows where you will land: **green** is road, **red** is cars.
- Touching a parked car ends the run.
- Air refills only while you drive on the road.
- A flip that finishes in the air is worth **+25**.
- Every 500 m the level goes up: the car drives faster, and the stacks get taller and closer together.

## How it works

- **Rendering:** [flutter_scene](https://pub.dev/packages/flutter_scene) on Flutter GPU, with real-time shadows, fog and a gradient sky.
- **Flight:** gravity plus thrust from the jets under the car, limited by the air tank. In the air, steering has momentum, and side jets fire whenever the car speeds up or slows down sideways.
- **Flip:** modelled like a real reaction-control system (`lib/game/flip_motion.dart`).
  1. **Spin up:** a down-firing jet on one side and an up-firing jet on the other side twist the car. A side jet kicks it sideways at the same time.
  2. **Coast:** all jets switch off, and the car keeps spinning on its own momentum.
  3. **Brake:** the opposite pair of jets fires, and the spin stops after exactly one full turn.
- **Thrust follows the car's tilt:** if you thrust while upside down, the car is pushed down.
- **Smoke:** every active jet puffs see-through smoke in the direction it points (`lib/game/smoke.dart`).
- **Sound:** all sound effects are generated in code by `tool/make_sounds.py` and played with `audioplayers`.
- **Cars:**
  - The Roadster is an AI-generated mesh (Hunyuan3D-2mv, made from launch photos), scaled and painted by `tool/paint_model.py`.
  - The parked Model 3 / S / Y / X and Cybertruck are built by `tool/build_fleet.py`.

## Run it

```bash
flutter pub get
flutter run -d chrome         # web
flutter run -d <android-id>   # Android
```

- **Requirements:** Flutter 3.47 (stable) or newer.
- **Android:** Flutter GPU must be on. The `EnableFlutterGPU` meta-data is already in `android/app/src/main/AndroidManifest.xml`.
- **Web:** works as is. Sound starts after the first tap or key press, because browsers block audio until then.

### Autopilot demo

Open the web build with `?demo` in the URL (for example `http://localhost:8642/?demo`), and the game plays itself. The demo is still being tuned and can crash early.

## Tests

```bash
flutter test
```

The tests cover the flip physics:
- the car ends exactly level after one full turn
- the roll moves smoothly between frames and never goes backwards
- the jets follow the push, coast and brake phases
- the spin speed matches the jet timing
- flipping left mirrors flipping right

The rest of the game needs a GPU to render, so `flutter test` can't run it.

## Project layout

```
lib/
  main.dart             UI: HUD, joystick, FLY / FLIP buttons, overlays
  game/
    roadster_game.dart  game loop, flight physics, crashes, camera, autopilot
    flip_motion.dart    barrel-roll physics (pure Dart, tested)
    car_builder.dart    thrusters, jets and lights on the car
    smoke.dart          pooled translucent smoke puffs
    sounds.dart         engine loops and one-shot effects
    blocks.dart         stacks of parked cars
    road.dart           endless road
    tesla_fleet.dart    loads the parked-car meshes
tool/                   Python scripts that build the models and sounds
test/                   unit tests
```

## Credits

- Inspired by **F1 Race** on MTK keypad phones, and by the 2026 Tesla Roadster unveil.
- Built with Flutter, flutter_scene and [Claude](https://claude.com/claude-code).
- This is a non-commercial fan project. It is not affiliated with or endorsed by Tesla.
