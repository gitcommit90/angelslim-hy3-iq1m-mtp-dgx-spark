#!/usr/bin/env bash
set -euo pipefail
if pgrep -f "llama-server.*Hy3-IQ1_M-mtp" >/dev/null 2>&1; then
  pkill -TERM -f "llama-server.*Hy3-IQ1_M-mtp" || true
  for i in $(seq 1 40); do
    pgrep -f "llama-server.*Hy3-IQ1_M-mtp" >/dev/null 2>&1 || break
    sleep 1
  done
  pkill -KILL -f "llama-server.*Hy3-IQ1_M-mtp" 2>/dev/null || true
  echo "Stopped"
else
  echo "Not running"
fi
