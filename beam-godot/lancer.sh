#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
python_bin="$project_dir/../.venv/bin/python"
if ! command -v godot >/dev/null 2>&1; then
    echo "Godot est introuvable dans le PATH." >&2
    exit 1
fi
"$python_bin" -c 'from eyeware import beam_eye_tracker'
echo "Laisse Beam ouvert avec le suivi actif sur l'écran calibré."
"$python_bin" "$project_dir/bridge.py" &
bridge_pid=$!
cleanup() {
    kill -TERM "$bridge_pid" 2>/dev/null || true
    wait "$bridge_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
godot --path "$project_dir" "$@"
