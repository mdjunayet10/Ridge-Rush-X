# Hill Rider

**Hill Rider** is an original 2D golden mountain hill-racing game built with **Flutter** and **Flame**.

The game focuses on smooth arcade driving, readable terrain, stage progression, vehicle upgrades, collectible rewards, and responsive web-first gameplay. The visual direction is **Golden Mountain Day Ride**, featuring warm mountain backgrounds, dusty cartoon terrain, gold coins, fuel cells, selectable stages, and simple side-view vehicles with visible drivers and riders.

---

## Author

**Md. Junayet Hossain Mohit**

---

## Features

- Original 2D hill-racing gameplay
- Built with Flutter and Flame
- Custom arcade vehicle physics
- Grounded and airborne driving behavior
- Front and rear wheel terrain contact sampling
- Procedural mountain stages with ramps, dips, shelves, bridges, climbs, and reward routes
- Fuel cells, coins, gems, crashes, stage completion, stars, and best-distance saving
- Garage upgrade system for vehicle performance
- Multiple unlockable vehicles including buggies, trucks, a motorbike, and an ATV
- Stage selection with unlock costs, unique palettes, and saved progress
- Clean gameplay HUD with coins, distance, fuel, home button, and pedal controls
- Responsive menus, garage showroom, map screen, settings, and run results
- Touch controls with two large pedals:
  - **BRAKE** on the left
  - **GAS** on the right
- Keyboard controls for desktop and web testing
- Short sound effects for buttons, engine ticks, skid, coins, fuel, crash, jump, and landing

---

## Audio Rule

Hill Rider does **not** include background music, menu music, theme music, looping music, or any musical soundtrack.

Only short original sound effects are used.

---

## Tech Stack

- Flutter
- Dart
- Flame
- Flutter Web

---

## Target Platforms

The primary target is **Flutter Web**.

The project is built with platform-independent Flutter code and can be extended to Android and mobile platforms later.

---

## Run Locally

From the project folder:

```sh
flutter clean
flutter pub get
flutter run -d chrome
```

Run in release mode:

```sh
flutter run -d chrome --release
```

---

## Development Checks

```sh
dart format .
flutter analyze
flutter test
```

---

## Build Web Release

```sh
flutter clean
flutter pub get
flutter build web --release
```

The web build output will be generated in:

```text
build/web
```

---

## Project Structure

```text
lib/
  game/
  screens/
  widgets/
  services/
  models/

assets/
  images/
  audio/
```

---

## Security Notes

Do not upload or commit private files such as:

```text
.env
serviceAccountKey.json
*.jks
*.keystore
```

Generated folders should also be excluded from public uploads when not needed:

```text
build/
.dart_tool/
```

---

## License

This project is licensed under the **MIT License**.

See the [`LICENSE`](LICENSE) file for details.

---

## Project Status

Hill Rider is completed for now and ready for web testing and release preparation.
