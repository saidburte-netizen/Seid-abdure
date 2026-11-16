#!/usr/bin/env bash
# Format the Dart sources locally before pushing.
#
# CI never runs this: it only verifies formatting with
# `dart format --output=none --set-exit-if-changed lib test` and never commits
# or pushes a rewrite. Run this script yourself to apply the same formatting.
set -euo pipefail
cd "$(dirname "$0")/.."
dart format lib test
dart format --output=none --set-exit-if-changed lib test
