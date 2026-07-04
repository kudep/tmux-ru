#!/usr/bin/env bash
# Build the clean-Ubuntu image and run the full test suite in it.
set -euo pipefail
cd "$(dirname "$0")/.."
docker build -t tmux-ru-test -f test/Dockerfile .
docker run --rm tmux-ru-test
