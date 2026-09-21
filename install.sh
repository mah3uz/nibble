#!/usr/bin/env bash
# Install Nibble: check this machine has what it needs, fetch the code, then hand over to Ruby.
set -euo pipefail

REPO="${NIBBLE_REPO:-https://github.com/mah3uz/nibble.git}"
DIR="${1:-nibble}"

red()  { printf '\033[31m%s\033[0m\n' "$1"; }
green(){ printf '\033[32m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

missing=()
need() { command -v "$1" >/dev/null 2>&1 || missing+=("$1 — $2"); }

printf '\n  Nibble\n'
dim "  Checking this machine"

need git "version control, and how upgrades arrive"
need ruby "the application"
need node "the asset build and server-side rendering"
need npm "JavaScript dependencies"
need sqlite3 "the database"
need vips "image resizing (package: libvips / libvips-tools)"
need ffmpeg "video thumbnails"

if [ ${#missing[@]} -gt 0 ]; then
  red "  Missing:"
  for item in "${missing[@]}"; do printf '    %s\n' "$item"; done
  case "$(uname -s)" in
    Darwin) dim "  Most of these: brew install git ruby node sqlite vips ffmpeg" ;;
    Linux)  dim "  Debian/Ubuntu: sudo apt install git ruby-full nodejs npm sqlite3 libvips-tools ffmpeg" ;;
  esac
  exit 1
fi
green "  Everything needed is here"

if [ -d "$DIR" ]; then
  red "  $DIR already exists — pass a different directory, e.g. ./install.sh my-site"
  exit 1
fi

dim "  Fetching Nibble into $DIR"
git clone --quiet "$REPO" "$DIR"
cd "$DIR"

dim "  Installing dependencies (this takes a minute)"
bundle install --quiet
npm install --silent

green "  Ready"
exec bin/rails nibble:install
