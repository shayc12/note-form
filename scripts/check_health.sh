#!/bin/bash
set -euo pipefail
base="${1:-http://127.0.0.1:8080}"
for attempt in 1 2 3; do
  curl -fsS "$base/health"
  printf '\n'
done
