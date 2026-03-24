#!/bin/sh
# Shell launcher for usecomputer — runs the native Zig binary when available,
# falls back to the Node.js CLI otherwise.

set -e

# Resolve the real directory where this script lives (follows symlinks)
SCRIPT="$0"
while [ -L "$SCRIPT" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"
  SCRIPT="$(readlink "$SCRIPT")"
  # Handle relative symlink targets
  case "$SCRIPT" in
    /*) ;;
    *) SCRIPT="$SCRIPT_DIR/$SCRIPT" ;;
  esac
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT")" && pwd)"

# Detect platform and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) PLATFORM="darwin" ;;
  Linux)  PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="win32" ;;
  *) PLATFORM="" ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH_NAME="arm64" ;;
  x86_64|amd64)  ARCH_NAME="x64" ;;
  *) ARCH_NAME="" ;;
esac

if [ -n "$PLATFORM" ] && [ -n "$ARCH_NAME" ]; then
  TARGET="${PLATFORM}-${ARCH_NAME}"
  NATIVE_BIN="${SCRIPT_DIR}/dist/${TARGET}/usecomputer"

  if [ "$PLATFORM" = "win32" ]; then
    NATIVE_BIN="${NATIVE_BIN}.exe"
  fi

  if [ -x "$NATIVE_BIN" ]; then
    exec "$NATIVE_BIN" "$@"
  fi
fi

# Fallback: run the Node.js CLI
exec node "${SCRIPT_DIR}/dist/cli.js" "$@"
