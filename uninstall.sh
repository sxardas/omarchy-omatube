#!/bin/bash

# Remove what OmaTube added: running downloads and their unfinished files,
# .omatube.cache, the history, the bar entry and the plugin folder.
# Videos, yt-dlp, ffmpeg and deno stay; a source checkout is left alone.

set -euo pipefail

PLUGIN_ID="io.github.sxardas.omatube"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
STATE_DIR="$HOME/.local/state/omatube"

case "${1:-}" in
  "") ;;
  -h | --help)
    echo "Usage: $0"
    exit 0
    ;;
  *)
    echo "unknown option: $1" >&2
    exit 2
    ;;
esac

shell_running() {
  omarchy-shell shell ping >/dev/null 2>&1
}

download_dir() {
  local dir=""
  if [[ -f $SHELL_CONFIG ]]; then
    dir=$(jq -r --arg id "$PLUGIN_ID" '
      [.bar.layout // {} | .[] | .[]? | select(.id == $id) | .downloadDir // empty] | first // empty
    ' "$SHELL_CONFIG" 2>/dev/null || true)
  fi
  dir=${dir:-~/Videos/OmaTube}
  case $dir in
    "~") dir=$HOME ;;
    "~/"*) dir=$HOME/${dir#"~/"} ;;
    /*) ;;
    *) dir=$HOME/$dir ;;
  esac
  printf '%s\n' "${dir%/}"
}

stop_downloads() {
  if systemctl --user list-units --plain --no-legend 'omatube-*.service' 2>/dev/null | grep -q .; then
    systemctl --user stop 'omatube-*.service'
    echo "Stopped the running downloads"
  fi
}

remove_cache() {
  local cache="$DOWNLOAD_DIR/.omatube.cache"
  if [[ -d $cache ]]; then
    rm -rf -- "$cache"
    echo "Deleted $cache"
  fi
}

remove_history() {
  if [[ -d $STATE_DIR ]]; then
    rm -rf -- "$STATE_DIR"
    echo "Deleted $STATE_DIR"
  fi
}

remove_bar_entry() {
  if shell_running; then
    omarchy-shell shell setPluginEnabled "$PLUGIN_ID" false >/dev/null 2>&1 || true
  fi

  # For a shell that is not running: drop the entry from the file directly.
  [[ -f $SHELL_CONFIG ]] || return 0
  local cleaned
  cleaned=$(jq --arg id "$PLUGIN_ID" '
    if .bar.layout then .bar.layout |= map_values(map(select(.id != $id))) else . end
  ' "$SHELL_CONFIG")
  if [[ $cleaned != "$(jq . "$SHELL_CONFIG")" ]]; then
    printf '%s\n' "$cleaned" >"$SHELL_CONFIG"
  fi
  echo "Removed $PLUGIN_ID from $SHELL_CONFIG"
}

remove_plugin_files() {
  if [[ -e $PLUGIN_DIR || -L $PLUGIN_DIR ]]; then
    rm -rf -- "$PLUGIN_DIR"
    echo "Deleted $PLUGIN_DIR"
  else
    echo "No plugin at $PLUGIN_DIR"
  fi
  if shell_running; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
}

# Read while the bar entry that holds it still exists.
DOWNLOAD_DIR=$(download_dir)

stop_downloads
remove_cache
remove_history
remove_bar_entry
remove_plugin_files

echo "OmaTube is removed; your videos are still in $DOWNLOAD_DIR"
