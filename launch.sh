#!/usr/bin/env bash
# OpenClaude Portable - Linux launcher.
# Usage: ./launch.sh [openclaude args]      ./launch.sh --portable-update
# If the drive is mounted without exec permission or is exFAT, use:  bash launch.sh
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$ROOT/profile"
APP="$ROOT/app/linux"
NODE_DIR="$ROOT/runtime/linux/node"
RG_DIR="$ROOT/runtime/linux/rg"

mkdir -p "$P/home" "$P/config" "$P/data" "$P/openclaude" \
         "$ROOT/cache/npm" "$ROOT/temp" "$ROOT/workspace" "$APP"

# --- Redirect everything the app might write onto the drive (this process tree only) ---
export HOME="$P/home"
export XDG_CONFIG_HOME="$P/config"
export XDG_DATA_HOME="$P/data"
export XDG_CACHE_HOME="$ROOT/cache"
export TMPDIR="$ROOT/temp"
export npm_config_cache="$ROOT/cache/npm"
export npm_config_userconfig="$P/home/.npmrc"
export npm_config_update_notifier=false
export OPENCLAUDE_CONFIG_DIR="$P/openclaude"
export CLAUDE_CONFIG_DIR="$P/openclaude"

# --- No auto-update / telemetry (an auto-update could install outside the drive) ---
export DISABLE_AUTOUPDATER=1
export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

export PATH="$NODE_DIR/bin:$RG_DIR:$PATH"

cleanup() { cd "$ROOT" && rm -rf "$ROOT/temp" && mkdir -p "$ROOT/temp"; }
trap cleanup EXIT

UPDATE=0
if [ "${1:-}" = "--portable-update" ]; then UPDATE=1; shift; fi

if [ "$UPDATE" = 1 ] || [ ! -f "$APP/entry.txt" ]; then
  bash "$ROOT/scripts/setup.sh"
fi
if [ "$UPDATE" = 1 ]; then echo "Update complete."; exit 0; fi

ENTRY="$(cat "$APP/entry.txt")"
cd "$ROOT/workspace"
"$NODE_DIR/bin/node" "$APP/$ENTRY" "$@"
