#!/usr/bin/env bash
# Build the test images and run every suite.
#   1. clean Ubuntu — full install + Russian-layout behaviour (root install)
#   2. gpu12-like    — unprivileged user, tmux present, no sudo (no-admin install)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "### suite 1: clean Ubuntu (full behaviour) ###"
docker build -t tmux-ru-test -f test/Dockerfile .
docker run --rm tmux-ru-test

echo
echo "### suite 2: unprivileged / no-sudo (gpu12 regression) ###"
docker build -t tmux-ru-test-noroot -f test/Dockerfile.noroot .
docker run --rm tmux-ru-test-noroot
