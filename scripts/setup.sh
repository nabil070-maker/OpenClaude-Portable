#!/usr/bin/env bash
# OpenClaude Portable - Linux setup. Run via launch.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${OPENCLAUDE_CONFIG_DIR:-}" ]; then
  echo "Run launch.sh instead; it sets up the portable environment first." >&2
  exit 1
fi

# versions.txt may have Windows line endings; strip them before sourcing.
# shellcheck disable=SC1090
source <(tr -d '\r' < "$ROOT/versions.txt")
: "${NODE_VERSION:?versions.txt is missing NODE_VERSION}"
: "${RG_VERSION:?versions.txt is missing RG_VERSION}"

PKGNAME="${OPENCLAUDE_PACKAGE:-@twigpine/openclaude}"
RT="$ROOT/runtime/linux"
NODE_DIR="$RT/node"
RG_DIR="$RT/rg"
APP="$ROOT/app/linux"
TMP="$ROOT/temp"
mkdir -p "$RT" "$APP" "$TMP"
export PATH="$NODE_DIR/bin:$RG_DIR:$PATH"

case "$(uname -m)" in
  x86_64|amd64)  NARCH=x64;   RARCH=x86_64-unknown-linux-musl;  RSHA="${RG_SHA256_LINUX_X64:-}" ;;
  aarch64|arm64) NARCH=arm64; RARCH=aarch64-unknown-linux-gnu;  RSHA="${RG_SHA256_LINUX_ARM64:-}" ;;
  *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

dl() { # url out
  if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
  else echo "Need curl or wget." >&2; exit 1; fi
}

verify() { # file expected label
  if [ -z "$2" ]; then echo "WARNING: no checksum pinned for $3 (unverified)"; return 0; fi
  local actual
  actual="$(sha256sum "$1" | cut -d' ' -f1)"
  if [ "$actual" != "$2" ]; then
    rm -f "$1"
    echo "Checksum mismatch for $3 (download deleted)" >&2
    exit 1
  fi
}

need() { # dir exe-relative-path version -> returns 0 when (re)install is needed
  if [ -x "$1/$2" ] && [ -f "$1.ver" ] && [ "$(cat "$1.ver")" = "$3" ]; then return 1; fi
  return 0
}

# ---- Node.js ----
if need "$NODE_DIR" bin/node "$NODE_VERSION"; then
  if command -v xz >/dev/null 2>&1; then EXT=tar.xz; TARFLAG=-xJf; else EXT=tar.gz; TARFLAG=-xzf; fi
  NAME="node-v$NODE_VERSION-linux-$NARCH.$EXT"
  echo "Downloading Node.js $NODE_VERSION ..."
  dl "https://nodejs.org/dist/v$NODE_VERSION/$NAME" "$TMP/$NAME"
  dl "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" "$TMP/SHASUMS256.txt"
  EXPECT="$(grep -E "[[:space:]]${NAME}\$" "$TMP/SHASUMS256.txt" | awk '{print $1}' | head -n1 || true)"
  [ -n "$EXPECT" ] || { echo "No checksum listed for $NAME" >&2; exit 1; }
  verify "$TMP/$NAME" "$EXPECT" "Node.js"
  rm -rf "$NODE_DIR"; mkdir -p "$NODE_DIR"
  tar "$TARFLAG" "$TMP/$NAME" -C "$NODE_DIR" --strip-components=1
  rm -f "$TMP/$NAME" "$TMP/SHASUMS256.txt"
  printf '%s' "$NODE_VERSION" > "$NODE_DIR.ver"
fi

# ---- ripgrep ----
if need "$RG_DIR" rg "$RG_VERSION"; then
  NAME="ripgrep-$RG_VERSION-$RARCH.tar.gz"
  echo "Downloading ripgrep $RG_VERSION ..."
  dl "https://github.com/BurntSushi/ripgrep/releases/download/$RG_VERSION/$NAME" "$TMP/$NAME"
  verify "$TMP/$NAME" "$RSHA" "ripgrep"
  rm -rf "$RG_DIR"; mkdir -p "$RG_DIR"
  tar -xzf "$TMP/$NAME" -C "$RG_DIR" --strip-components=1
  rm -f "$TMP/$NAME"
  printf '%s' "$RG_VERSION" > "$RG_DIR.ver"
fi

# ---- OpenClaude ----
echo "Installing OpenClaude (latest) ..."
npm install --prefix "$APP" --no-bin-links --no-audit --no-fund "$PKGNAME@latest"

PKG="$APP/node_modules/$PKGNAME"
# Relative path on purpose: the mount point changes between machines.
node -e 'const p=require(process.argv[1]+"/package.json");const b=typeof p.bin==="string"?p.bin:(p.bin.openclaude||Object.values(p.bin)[0]);console.log(require("path").join("node_modules",process.argv[2],b))' "$PKG" "$PKGNAME" > "$APP/entry.txt"
echo "OpenClaude $(node -p 'require(process.argv[1]+"/package.json").version' "$PKG") is ready."
