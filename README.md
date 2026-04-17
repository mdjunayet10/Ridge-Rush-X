# Ridge Rush X

Ridge Rush X is a cross-platform, full-stack racing web game with account login, profile progression, garage upgrades, and leaderboard tracking.

## Main Features

- Account system with register, login, logout, and persistent session cookies.
- Backend profile storage (SQLite) for coins, level, XP, upgrades, and run history.
- Garage upgrade system:
   - Engine
   - Fuel Tank
   - Grip
   - Turbo
- Daily reward claim flow.
- Leaderboard API and UI panel.
- Mission board with progress tracking.
- Physics-based bike with separate frame and wheels.
- Procedural terrain with pickups and hazards.
- Gameplay systems:
   - Fuel + boost + health
   - Checkpoints
   - Stunt rewards
   - Rival pace meter
   - Weather variation

## Controls

- `Up` / `W`: Higher jump
- `Down` / `S`: Push vehicle downward
- `Left` / `A`: Reverse
- `Right` / `D`: Accelerate

Touch controls are also available in-game.

## Platform Policy

- Frontend uses HTML, CSS, and JavaScript and runs in the browser.
- Backend uses Python Flask APIs.
- No OS-specific application bundles or binaries are used (`.app`, `.exe`, etc.).
- Run via localhost in any operating system browser.

## Run The Project

1. Install dependencies:
   - `pip install -r requirements.txt`
2. Start the server:
   - `python3 app.py`
   - or `./run.sh` on Unix-like shells
3. Open the localhost URL printed in the terminal (for example `http://127.0.0.1:8000`).

## Project Structure

- `app.py`: Flask API backend + static file server + SQLite persistence.
- `index.html`: Frontend shell and UI layout.
- `game.js`: UI controller, API integration, and Phaser game logic.
- `requirements.txt`: Python backend dependencies.

## Storage

- Database file: `ridge_rush.db` (auto-created).
- Tables: `users`, `sessions`, `runs`.
