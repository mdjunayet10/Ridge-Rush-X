# Hill Rider

Hill Rider is an original golden mountain hill-racing game built with Flutter and Flame. The current direction is **Golden Mountain Day Ride**: warm readable peaks, dusty cartoon terrain, fair fuel stops, gold coins, selectable stages, and simple side-view vehicles with visible drivers and riders.

## Features

- Custom arcade car physics with grounded and airborne behavior
- Front and rear wheel terrain contact sampling
- Procedural mountain stages with ramps, dips, rough shelves, climbs, and reward routes
- Fuel cells, coins, gems, crash/game-over flow, stage stars, and best-distance saving
- Garage upgrades for Engine Core, Grip Tires, Shock System, and Fuel Cell
- Original eight-vehicle roster with buggies, trucks, a motorbike, an ATV, stats, and unlock costs
- Selectable stage cards with coin unlocks, distinct palettes, and saved star progress
- Clean HUD with coins, distance, fuel, home, and pedal controls
- Premium responsive menus, HUD, garage showroom, player settings, and run results
- Touch controls built around two large pedals: BRAKE on the left and GAS on the right
- Short sound effects for buttons, engine ticks, skid, coins, fuel, crash, jump, and landing

## Audio Rule

Hill Rider intentionally does not include background music, menu music, theme music, looping music, or any musical soundtrack. Only short original sound effects are allowed.

## Run

```sh
flutter clean
flutter pub get
flutter run -d chrome
flutter run -d chrome --release
```

## Development Checks

```sh
dart format .
flutter analyze
flutter test
```

## Targets

The primary target is Flutter Web. Android/mobile is a secondary target. The code is platform-independent and does not rely on macOS-only APIs.
