#!/usr/bin/env python3
import datetime as dt
import hashlib
import hmac
import os
import re
import secrets
import socket
import sqlite3
import sys
import threading
import time
import webbrowser

from flask import Flask, abort, jsonify, make_response, request, send_from_directory

PORT = 8000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(DIRECTORY, "ridge_rush.db")
MAX_PORT_TRIES = 30
MAX_UPGRADE_LEVEL = 8
SESSION_COOKIE_NAME = "ridge_session"
SESSION_TTL_SECONDS = 60 * 60 * 24 * 14
USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{3,16}$")

UPGRADE_COLUMNS = {
    "engine": "engine_level",
    "fuelTank": "fuel_tank_level",
    "grip": "grip_level",
    "boost": "boost_level"
}

STATIC_WEB_FILES = {"index.html", "game.js"}
STATIC_CACHE_CONTROL = "no-store, no-cache, must-revalidate, max-age=0"

app = Flask(__name__)


def clamp_int(value, minimum, maximum):
    return max(minimum, min(maximum, int(value)))


def hash_password(password):
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 120000)
    return salt.hex() + ":" + digest.hex()


def verify_password(password, encoded):
    try:
        salt_hex, hash_hex = encoded.split(":", 1)
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(hash_hex)
    except (ValueError, TypeError):
        return False

    actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 120000)
    return hmac.compare_digest(actual, expected)


def create_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def level_threshold(level):
    return 180 + level * 120


def upgrade_cost(level):
    return 160 + int(level * level * 105)


def row_to_profile(row):
    return {
        "username": row["username"],
        "coins": row["coins"],
        "bestDistance": row["best_distance"],
        "level": row["level"],
        "xp": row["xp"],
        "totalRuns": row["total_runs"],
        "totalCoins": row["total_coins"],
        "totalStunts": row["total_stunts"],
        "lastDailyClaim": row["last_daily_claim"],
        "upgrades": {
            "engine": row["engine_level"],
            "fuelTank": row["fuel_tank_level"],
            "grip": row["grip_level"],
            "boost": row["boost_level"]
        }
    }


def parse_json_body():
    if not request.data:
        return {}

    payload = request.get_json(silent=True)
    if payload is None or not isinstance(payload, dict):
        raise ValueError("Invalid JSON body")

    return payload


def cleanup_expired_sessions(conn):
    conn.execute("DELETE FROM sessions WHERE expires_at <= ?", (int(time.time()),))
    conn.commit()


def get_user_id_from_request(conn):
    token = request.cookies.get(SESSION_COOKIE_NAME)
    if not token:
        return None

    now = int(time.time())
    row = conn.execute(
        "SELECT user_id, expires_at FROM sessions WHERE token = ?",
        (token,)
    ).fetchone()

    if not row:
        return None

    if row["expires_at"] <= now:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()
        return None

    return row["user_id"]


def create_session(conn, user_id):
    token = secrets.token_urlsafe(36)
    expires_at = int(time.time()) + SESSION_TTL_SECONDS
    conn.execute(
        "INSERT INTO sessions(token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)",
        (token, user_id, expires_at, dt.datetime.utcnow().isoformat())
    )
    conn.commit()
    return token


def clear_session(conn):
    token = request.cookies.get(SESSION_COOKIE_NAME)
    if token:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()


def get_profile_by_user_id(conn, user_id):
    row = conn.execute(
        """
        SELECT
            id, username, coins, best_distance, level, xp,
            engine_level, fuel_tank_level, grip_level, boost_level,
            total_runs, total_coins, total_stunts, last_daily_claim
        FROM users
        WHERE id = ?
        """,
        (user_id,)
    ).fetchone()
    return row


def make_json_response(payload, status_code=200):
    response = make_response(jsonify(payload), status_code)
    response.headers["Cache-Control"] = "no-store"
    return response


def set_session_cookie(response, token, max_age):
    response.set_cookie(
        SESSION_COOKIE_NAME,
        token,
        max_age=max_age,
        path="/",
        httponly=True,
        samesite="Lax"
    )


def init_db():
    conn = create_db_connection()
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            coins INTEGER NOT NULL DEFAULT 300,
            best_distance INTEGER NOT NULL DEFAULT 0,
            level INTEGER NOT NULL DEFAULT 1,
            xp INTEGER NOT NULL DEFAULT 0,
            engine_level INTEGER NOT NULL DEFAULT 1,
            fuel_tank_level INTEGER NOT NULL DEFAULT 1,
            grip_level INTEGER NOT NULL DEFAULT 1,
            boost_level INTEGER NOT NULL DEFAULT 1,
            total_runs INTEGER NOT NULL DEFAULT 0,
            total_coins INTEGER NOT NULL DEFAULT 0,
            total_stunts INTEGER NOT NULL DEFAULT 0,
            last_daily_claim TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            distance INTEGER NOT NULL,
            coins INTEGER NOT NULL,
            stunts INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
        );
        """
    )
    conn.commit()
    conn.close()


def find_available_port(start_port, attempts):
    for port in range(start_port, start_port + attempts):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                sock.bind(("127.0.0.1", port))
            except OSError:
                continue
        return port
    return None


def schedule_browser_open(url):
    # Set RIDGE_RUSH_NO_BROWSER=1 to disable auto-open behavior.
    no_browser = os.environ.get("RIDGE_RUSH_NO_BROWSER", "").strip().lower()
    if no_browser in {"1", "true", "yes", "on"}:
        return

    def open_browser():
        try:
            opened = webbrowser.open(url, new=2)
            if not opened:
                print("Could not auto-open browser. Please open the URL manually.", file=sys.stderr)
        except Exception as exc:
            print(f"Browser auto-open failed: {exc}", file=sys.stderr)

    # Delay slightly so the server is ready by the time the browser requests the page.
    timer = threading.Timer(0.8, open_browser)
    timer.daemon = True
    timer.start()


def send_web_file(filename):
    response = make_response(send_from_directory(DIRECTORY, filename))
    response.headers["Cache-Control"] = STATIC_CACHE_CONTROL
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response


@app.route("/")
def index_page():
    return send_web_file("index.html")


@app.route("/<path:filename>")
def static_files(filename):
    if filename not in STATIC_WEB_FILES:
        abort(404)
    return send_web_file(filename)


@app.get("/api/session")
def api_session():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        user_id = get_user_id_from_request(conn)
        if not user_id:
            return make_json_response({"ok": True, "authenticated": False})

        row = get_profile_by_user_id(conn, user_id)
        if not row:
            return make_json_response({"ok": True, "authenticated": False})

        return make_json_response({
            "ok": True,
            "authenticated": True,
            "profile": row_to_profile(row)
        })
    finally:
        conn.close()


@app.get("/api/profile")
def api_profile():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        user_id = get_user_id_from_request(conn)
        if not user_id:
            return make_json_response({"ok": False, "error": "Authentication required"}, 401)

        row = get_profile_by_user_id(conn, user_id)
        return make_json_response({"ok": True, "profile": row_to_profile(row)})
    finally:
        conn.close()


@app.get("/api/leaderboard")
def api_leaderboard():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        rows = conn.execute(
            """
            SELECT username, best_distance, level, total_runs
            FROM users
            WHERE best_distance > 0
            ORDER BY best_distance DESC, level DESC, total_runs DESC
            LIMIT 30
            """
        ).fetchall()

        leaderboard = []
        for idx, row in enumerate(rows, start=1):
            leaderboard.append({
                "rank": idx,
                "username": row["username"],
                "bestDistance": row["best_distance"],
                "level": row["level"],
                "totalRuns": row["total_runs"]
            })

        return make_json_response({"ok": True, "leaderboard": leaderboard})
    finally:
        conn.close()


@app.post("/api/register")
def api_register():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        try:
            payload = parse_json_body()
        except ValueError:
            return make_json_response({"ok": False, "error": "Invalid JSON body"}, 400)

        username = str(payload.get("username", "")).strip()
        password = str(payload.get("password", ""))

        if not USERNAME_RE.match(username):
            return make_json_response({
                "ok": False,
                "error": "Username must be 3-16 chars, letters, numbers, or underscore"
            }, 400)

        if len(password) < 6 or len(password) > 64:
            return make_json_response({"ok": False, "error": "Password must be 6-64 characters"}, 400)

        now = dt.datetime.utcnow().isoformat()
        try:
            cur = conn.execute(
                """
                INSERT INTO users(username, password_hash, created_at, updated_at)
                VALUES (?, ?, ?, ?)
                """,
                (username, hash_password(password), now, now)
            )
            conn.commit()
            user_id = cur.lastrowid
        except sqlite3.IntegrityError:
            return make_json_response({"ok": False, "error": "Username already exists"}, 409)

        token = create_session(conn, user_id)
        row = get_profile_by_user_id(conn, user_id)
        response = make_json_response({
            "ok": True,
            "profile": row_to_profile(row),
            "message": "Account created"
        })
        set_session_cookie(response, token, SESSION_TTL_SECONDS)
        return response
    finally:
        conn.close()


@app.post("/api/login")
def api_login():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        try:
            payload = parse_json_body()
        except ValueError:
            return make_json_response({"ok": False, "error": "Invalid JSON body"}, 400)

        username = str(payload.get("username", "")).strip()
        password = str(payload.get("password", ""))

        row = conn.execute(
            "SELECT id, password_hash FROM users WHERE username = ?",
            (username,)
        ).fetchone()

        if not row or not verify_password(password, row["password_hash"]):
            return make_json_response({"ok": False, "error": "Invalid username or password"}, 401)

        token = create_session(conn, row["id"])
        profile_row = get_profile_by_user_id(conn, row["id"])
        response = make_json_response({
            "ok": True,
            "profile": row_to_profile(profile_row),
            "message": "Welcome back"
        })
        set_session_cookie(response, token, SESSION_TTL_SECONDS)
        return response
    finally:
        conn.close()


@app.post("/api/logout")
def api_logout():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        clear_session(conn)

        response = make_json_response({"ok": True, "message": "Logged out"})
        set_session_cookie(response, "", 0)
        return response
    finally:
        conn.close()


@app.post("/api/run")
def api_run():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        try:
            payload = parse_json_body()
        except ValueError:
            return make_json_response({"ok": False, "error": "Invalid JSON body"}, 400)

        user_id = get_user_id_from_request(conn)
        if not user_id:
            return make_json_response({"ok": False, "error": "Authentication required"}, 401)

        distance = clamp_int(payload.get("distance", 0), 0, 200000)
        coins = clamp_int(payload.get("coins", 0), 0, 20000)
        stunts = clamp_int(payload.get("stunts", 0), 0, 10000)

        user_row = get_profile_by_user_id(conn, user_id)
        level = user_row["level"]
        xp_gain = int(distance * 0.16 + coins * 0.42 + stunts * 8)
        xp_pool = user_row["xp"] + xp_gain

        while xp_pool >= level_threshold(level):
            xp_pool -= level_threshold(level)
            level += 1

        best_distance = max(user_row["best_distance"], distance)
        now = dt.datetime.utcnow().isoformat()

        conn.execute(
            """
            UPDATE users
            SET
                coins = coins + ?,
                best_distance = ?,
                level = ?,
                xp = ?,
                total_runs = total_runs + 1,
                total_coins = total_coins + ?,
                total_stunts = total_stunts + ?,
                updated_at = ?
            WHERE id = ?
            """,
            (coins, best_distance, level, xp_pool, coins, stunts, now, user_id)
        )

        conn.execute(
            "INSERT INTO runs(user_id, distance, coins, stunts, created_at) VALUES (?, ?, ?, ?, ?)",
            (user_id, distance, coins, stunts, now)
        )
        conn.commit()

        profile_row = get_profile_by_user_id(conn, user_id)
        return make_json_response({
            "ok": True,
            "profile": row_to_profile(profile_row),
            "rewards": {
                "coins": coins,
                "xp": xp_gain,
                "distance": distance
            }
        })
    finally:
        conn.close()


@app.post("/api/upgrade")
def api_upgrade():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        try:
            payload = parse_json_body()
        except ValueError:
            return make_json_response({"ok": False, "error": "Invalid JSON body"}, 400)

        user_id = get_user_id_from_request(conn)
        if not user_id:
            return make_json_response({"ok": False, "error": "Authentication required"}, 401)

        upgrade_type = str(payload.get("type", ""))
        column = UPGRADE_COLUMNS.get(upgrade_type)
        if not column:
            return make_json_response({"ok": False, "error": "Invalid upgrade type"}, 400)

        row = get_profile_by_user_id(conn, user_id)
        current_level = row[column]
        if current_level >= MAX_UPGRADE_LEVEL:
            return make_json_response({"ok": False, "error": "Upgrade already maxed"}, 409)

        price = upgrade_cost(current_level)
        if row["coins"] < price:
            return make_json_response({"ok": False, "error": "Not enough coins", "required": price}, 409)

        now = dt.datetime.utcnow().isoformat()
        conn.execute(
            f"UPDATE users SET {column} = {column} + 1, coins = coins - ?, updated_at = ? WHERE id = ?",
            (price, now, user_id)
        )
        conn.commit()

        profile_row = get_profile_by_user_id(conn, user_id)
        return make_json_response({
            "ok": True,
            "profile": row_to_profile(profile_row),
            "cost": price,
            "type": upgrade_type
        })
    finally:
        conn.close()


@app.post("/api/claim-daily")
def api_claim_daily():
    conn = create_db_connection()
    try:
        cleanup_expired_sessions(conn)
        user_id = get_user_id_from_request(conn)
        if not user_id:
            return make_json_response({"ok": False, "error": "Authentication required"}, 401)

        row = get_profile_by_user_id(conn, user_id)
        today = dt.date.today().isoformat()

        if row["last_daily_claim"] == today:
            return make_json_response({"ok": False, "error": "Daily reward already claimed today"}, 409)

        reward = 130 + row["level"] * 15
        now = dt.datetime.utcnow().isoformat()
        conn.execute(
            """
            UPDATE users
            SET
                coins = coins + ?,
                total_coins = total_coins + ?,
                last_daily_claim = ?,
                updated_at = ?
            WHERE id = ?
            """,
            (reward, reward, today, now, user_id)
        )
        conn.commit()

        profile_row = get_profile_by_user_id(conn, user_id)
        return make_json_response({
            "ok": True,
            "profile": row_to_profile(profile_row),
            "reward": reward
        })
    finally:
        conn.close()


@app.route("/api/<path:subpath>", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
def api_not_found(subpath):
    return make_json_response({"ok": False, "error": "API route not found"}, 404)


if __name__ == "__main__":
    init_db()

    selected_port = find_available_port(PORT, MAX_PORT_TRIES)
    if selected_port is None:
        print(
            f"Error: no available port in range {PORT}-{PORT + MAX_PORT_TRIES - 1}",
            file=sys.stderr
        )
        sys.exit(1)

    url = f"http://127.0.0.1:{selected_port}"
    print(f"Server started at {url}", file=sys.stderr)
    print("Attempting to open the browser automatically...", file=sys.stderr)
    print("Set RIDGE_RUSH_NO_BROWSER=1 to disable auto-open.", file=sys.stderr)
    sys.stderr.flush()

    schedule_browser_open(url)

    app.run(host="127.0.0.1", port=selected_port, debug=False)
