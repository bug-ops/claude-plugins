#!/usr/bin/env bash
# Starts rust-analyzer over stdio; stdout carries only LSP messages.
# A rust-toolchain.toml without the rust-analyzer component makes the rustup proxy exit 1,
# so fall back to the default toolchain's rust-analyzer.
set -euo pipefail

cd "${CLAUDE_PROJECT_DIR:-$PWD}"

if command -v rustup >/dev/null 2>&1 && ! rustup which rust-analyzer >/dev/null 2>&1; then
  default=$(rustup default 2>/dev/null | cut -d' ' -f1)
  if [[ -n "$default" ]] && ra=$(rustup which --toolchain "$default" rust-analyzer 2>/dev/null); then
    echo "dev-agents: project toolchain lacks rust-analyzer, using $default; add \"rust-analyzer\" to rust-toolchain.toml components" >&2
    exec "$ra"
  fi
  echo "dev-agents: rust-analyzer not installed; run: rustup component add rust-analyzer" >&2
fi

exec rust-analyzer
