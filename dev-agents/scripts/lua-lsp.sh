#!/usr/bin/env bash
# Starts the language server for .luau/.lua files over stdio; stdout carries only LSP messages.
# Usage: lua-lsp.sh luau|lua
#   luau-lsp for Luau projects (Roblox definitions added for Rojo/Wally projects),
#   lua-language-server for .lua files in projects without Luau markers.
set -euo pipefail

DEFS_URL="https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau"
root=${CLAUDE_PROJECT_DIR:-$PWD}

has_any() {
  local f
  for f in "$@"; do
    if [[ -f "$root/$f" ]]; then return 0; fi
  done
  return 1
}

if [[ "${1:-luau}" == lua ]] && ! has_any default.project.json wally.toml pesde.toml .luaurc .config.luau; then
  exec lua-language-server
fi

args=(lsp)
if has_any default.project.json wally.toml; then
  defs=${LUAU_LSP_DEFINITIONS:-}
  if [[ -z "$defs" ]]; then
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/dev-agents"
    defs="$cache/globalTypes.d.luau"
    # Refresh weekly; a failed download keeps the previous copy.
    if [[ ! -s "$defs" || -n "$(find "$defs" -mtime +7 2>/dev/null)" ]]; then
      mkdir -p "$cache"
      if curl -fsSL --max-time 20 -o "$defs.tmp" "$DEFS_URL" >&2; then mv "$defs.tmp" "$defs"; else rm -f "$defs.tmp"; fi
    fi
  fi
  if [[ -s "$defs" ]]; then args+=("--definitions:@roblox=$defs"); fi
fi

exec luau-lsp "${args[@]}"
