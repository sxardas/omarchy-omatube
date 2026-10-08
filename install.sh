#!/bin/bash

# Install the OmaTube bar widget for Omarchy.
#
#   ./install.sh           from a source checkout: install yt-dlp, ffmpeg and
#                          deno, copy the plugin, enable the widget.
#   ./install.sh --setup   install yt-dlp, ffmpeg and deno only; what the
#                          panel's "Finish setup" button runs after
#                          `omarchy plugin add`.

set -euo pipefail

PLUGIN_ID="io.github.sxardas.omatube"
SOURCE_DIR="$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
PACKAGES=(yt-dlp ffmpeg deno)

install_packages() {
  if omarchy pkg present "${PACKAGES[@]}"; then
    echo "yt-dlp, ffmpeg and deno are already installed"
  else
    echo "Installing ${PACKAGES[*]} (needs sudo)"
    omarchy pkg add "${PACKAGES[@]}"
  fi
}

copy_plugin() {
  if [[ $SOURCE_DIR == "$(readlink -f -- "$PLUGIN_DIR" 2>/dev/null)" ]]; then
    echo "Running from $PLUGIN_DIR; nothing to copy"
    return
  fi
  if [[ -d $PLUGIN_DIR/.git ]]; then
    echo "$PLUGIN_DIR is a git checkout managed by 'omarchy plugin'; leaving it alone" >&2
    return
  fi
  # Start clean; settings and history live elsewhere.
  rm -rf -- "$PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
  cp -r "$SOURCE_DIR"/{manifest.json,src,bin,assets,install.sh,uninstall.sh,README.md,LICENSE} "$PLUGIN_DIR"/
  echo "Copied plugin to $PLUGIN_DIR"
}

case "${1:-}" in
  --setup)
    install_packages
    echo "Setup done. Reopen the OmaTube panel to pick it up."
    read -rsn1 -p "Press any key to close" || true
    exit 0
    ;;
  "") ;;
  -h | --help)
    sed -n '3,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "unknown option: $1" >&2
    exit 2
    ;;
esac

install_packages
copy_plugin

if omarchy-shell shell ping >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null
  sleep 1
  if ! grep -q "\"$PLUGIN_ID\"" "$HOME/.config/omarchy/shell.json" 2>/dev/null; then
    omarchy plugin enable "$PLUGIN_ID"
  fi
  # Hot reload keeps the old QML cached, so restart the shell (ends downloads).
  omarchy restart shell >/dev/null 2>&1
  echo "Enabled $PLUGIN_ID in the bar and restarted the shell"
else
  echo "omarchy-shell is not running; enable later with: omarchy plugin enable $PLUGIN_ID"
fi
