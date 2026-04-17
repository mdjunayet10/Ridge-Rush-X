#!/usr/bin/env sh
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -x ".venv/bin/python" ]; then
	./.venv/bin/python app.py
elif command -v python3 >/dev/null 2>&1; then
	python3 app.py
else
	python app.py
fi
