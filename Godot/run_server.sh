#!/bin/bash
#
# run_server.sh
# Starts a dedicated headless multiplayer server.
#
# Usage: ./run_server.sh [godot_path]
#   godot_path: Optional path to Godot executable (default: godot)
#
# The server runs Level.swift in headless mode, which automatically
# starts hosting when DisplayServer.getName() == "headless".

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${1:-godot}"

echo "=========================================="
echo "  SwiftGodot Multiplayer - Headless Server"
echo "=========================================="
echo ""
echo "Server Configuration:"
echo "  Port: 8080"
echo "  Max Players: 10"
echo "  Godot: $GODOT"
echo ""
echo "Starting server..."
echo ""

"$GODOT" --headless --path "$SCRIPT_DIR"

echo ""
echo "Server stopped."
