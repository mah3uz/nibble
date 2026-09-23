#!/usr/bin/env bash
# Install Nibble: check this machine has what it needs, fetch and verify a release, then hand over to Ruby.
# Usage: curl -fsSL nibble.ink/install.sh | bash [-s folder] [options for bin/rails nibble:install, e.g. --defaults]
set -euo pipefail

# Nothing runs until the whole script has arrived, so a download cut short can't run half of it.
main() {
  REPOSITORY="${NIBBLE_REPOSITORY:-mah3uz/nibble}"
  DIR=""
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    DIR="$1"
    shift
  fi
  VERSION="${NIBBLE_VERSION:-}"
  # A local archive instead of a download, with its SHA256SUMS beside it: for trying a release before it is published.
  ARCHIVE="${NIBBLE_ARCHIVE:-}"

  red()  { printf '\033[31m%s\033[0m\n' "$1"; }
  green(){ printf '\033[32m%s\033[0m\n' "$1"; }
  dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

  missing=()
  need() { command -v "$1" >/dev/null 2>&1 || missing+=("$1 — $2"); }

  printf '\n  Nibble\n'
  dim "  Checking this machine"

  need ruby "the application"
  need bundle "Ruby's gems (comes with Ruby)"
  need node "the asset build and server-side rendering"
  need npm "JavaScript dependencies"
  need sqlite3 "the database"
  need vips "image resizing (package: libvips / libvips-tools)"
  need ffmpeg "video thumbnails"
  need tar "unpacking the release"
  [ -n "$ARCHIVE" ] || need curl "downloading the release"
  command -v sha256sum >/dev/null 2>&1 || need shasum "checking the release is the one published"

  if [ ${#missing[@]} -gt 0 ]; then
    red "  Missing:"
    for item in "${missing[@]}"; do printf '    %s\n' "$item"; done
    case "$(uname -s)" in
      Darwin) dim "  Most of these: brew install ruby node sqlite vips ffmpeg" ;;
      Linux)  dim "  Debian/Ubuntu: sudo apt install ruby-full nodejs npm sqlite3 libvips-tools ffmpeg curl" ;;
    esac
    exit 1
  fi
  green "  Everything needed is here"

  # Asked on the terminal, since piped into bash this script's own input is the script.
  asking=""
  [ -z "$DIR" ] && (: < /dev/tty) 2>/dev/null && asking=1
  while :; do
    if [ -n "$asking" ]; then
      printf '  Name your site; its folder is named after it (nibble): ' > /dev/tty
      IFS= read -r DIR < /dev/tty || DIR=""
    fi
    DIR="$(printf '%s' "${DIR:-nibble}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/-/g')"
    [ -e "$DIR" ] || break
    red "  $DIR already exists — choose another name"
    [ -n "$asking" ] || exit 1
  done

  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT

  if [ -n "$ARCHIVE" ]; then
    dim "  Using $ARCHIVE"
    cp "$ARCHIVE" "$(dirname "$ARCHIVE")/SHA256SUMS" "$work/"
  else
    if [ -z "$VERSION" ]; then
      VERSION="$(curl -fsSL "https://api.github.com/repos/$REPOSITORY/releases/latest" |
        ruby -rjson -e 'print JSON.parse($stdin.read).fetch("tag_name").delete_prefix("v")')"
    fi
    dim "  Fetching Nibble $VERSION"
    base="https://github.com/$REPOSITORY/releases/download/v$VERSION"
    curl -fsSL -o "$work/nibble-$VERSION.tar.gz" "$base/nibble-$VERSION.tar.gz"
    curl -fsSL -o "$work/SHA256SUMS" "$base/SHA256SUMS"
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$work" && sha256sum --quiet -c SHA256SUMS) || { red "  The download doesn't match its checksum; nothing was installed"; exit 1; }
  else
    (cd "$work" && shasum -a 256 --quiet -c SHA256SUMS) || { red "  The download doesn't match its checksum; nothing was installed"; exit 1; }
  fi

  tar -xzf "$work"/nibble-*.tar.gz -C "$work"
  mkdir -p "$DIR/vendor"
  mv "$work"/nibble-*/ "$DIR/vendor/nibble"
  green "  Unpacked Nibble $(sed -n 's/^version: //p' "$DIR/vendor/nibble/VERSION") into $DIR"

  rm -rf "$work"
  cd "$DIR"
  # Piped into bash, this script's input is the script itself; the questions come next, so they read the terminal.
  if [ ! -t 0 ] && (: < /dev/tty) 2>/dev/null; then
    exec ruby vendor/nibble/bin/install "$@" < /dev/tty
  fi
  exec ruby vendor/nibble/bin/install "$@"
}

main "$@"
