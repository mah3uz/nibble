#!/usr/bin/env bash
# Install Nibble: get the nibble command if this computer hasn't got it, then start a site with `nibble new`.
# Usage: curl -fsSL nibble.ink/install.sh | bash [-s folder] [options for bin/rails nibble:install, e.g. --defaults]
set -euo pipefail

# Nothing runs until the whole script has arrived, so a download cut short can't run half of it.
main() {
  CLI_REPOSITORY="${NIBBLE_CLI_REPOSITORY:-mah3uz/nibble-cli}"

  red() { printf '\033[31m%s\033[0m\n' "$1"; }
  dim() { printf '\033[2m%s\033[0m\n' "$1"; }

  printf '\n  Nibble\n'
  nibble="$(command -v nibble 2>/dev/null || true)"
  if [ -z "$nibble" ] && [ -x "$HOME/.local/bin/nibble" ]; then
    nibble="$HOME/.local/bin/nibble"
  fi
  if [ -z "$nibble" ]; then
    command -v curl >/dev/null 2>&1 || { red "  curl is needed to download the nibble command"; exit 1; }
    dim "  Installing the nibble command from github.com/$CLI_REPOSITORY"
    # The installer checks the build it downloads against the checksum published with it.
    curl -fsSL "https://github.com/$CLI_REPOSITORY/releases/latest/download/nibble-cli-installer.sh" | sh
    nibble="$HOME/.local/bin/nibble"
  fi
  case "$("$nibble" --version 2>/dev/null || true)" in
    "nibble "*) ;;
    *) red "  $nibble isn't Nibble's command; move it aside or install ours from github.com/$CLI_REPOSITORY"; exit 1 ;;
  esac

  # `bash -s my-site --defaults`: the folder, then options for the installer, which nibble new takes after --.
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    folder="$1"
    shift
    set -- "$folder" -- "$@"
  else
    set -- -- "$@"
  fi

  # Piped into bash, this script's input is the script itself; nibble new asks questions next, so they read the terminal.
  if [ ! -t 0 ] && (: < /dev/tty) 2>/dev/null; then
    exec "$nibble" new "$@" < /dev/tty
  fi
  exec "$nibble" new "$@"
}

main "$@"
