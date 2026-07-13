#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "Starting WF Sober CCG relay on port 8765..."
python3 relay_server.py --host 0.0.0.0 --port 8765
