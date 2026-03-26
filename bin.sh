#!/bin/sh
# Shell launcher for usecomputer — runs the native Zig binary for the current platform.

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
  *) echo "error: unsupported platform: $OS" >&2; exit 1 ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH_NAME="arm64" ;;
  x86_64|amd64)  ARCH_NAME="x64" ;;
  *) echo "error: unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

TARGET="${PLATFORM}-${ARCH_NAME}"
NATIVE_BIN="${SCRIPT_DIR}/dist/${TARGET}/usecomputer"

if [ "$PLATFORM" = "win32" ]; then
  NATIVE_BIN="${NATIVE_BIN}.exe"
fi

if [ ! -f "$NATIVE_BIN" ]; then
  echo "error: native binary not found at ${NATIVE_BIN}" >&2
  echo "hint: run 'zig build' or install from npm to get prebuilt binaries" >&2
  exit 1
fi

# Ensure the binary is executable (npm tarballs may strip the +x bit)
chmod +x "$NATIVE_BIN" 2>/dev/null || true

exec "$NATIVE_BIN" "$@"
