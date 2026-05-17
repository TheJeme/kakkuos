#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"
OUTPUT_DIR="${KAKKU_LOCAL_REPO_DIR:-$REPO_ROOT/packaging/repo}"

packages=(
  kakku-niri-settings
  kakku-desktop
)

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --output DIR       Local repository output directory.
  --repo-name NAME   Pacman repository database name. Default: kakku-local.
  -h, --help         Show this help.

Environment:
  KAKKU_LOCAL_REPO_DIR
  KAKKU_REPO_NAME
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --repo-name)
      REPO_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
}

build_package() {
  local package_name="$1"
  local package_dir="$SCRIPT_DIR/$package_name"

  if [[ ! -d "$package_dir" ]]; then
    echo "Missing package directory: $package_dir" >&2
    exit 1
  fi

  (
    cd "$package_dir"
    makepkg -Csf --needed --noconfirm
  )
  find "$package_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -exec cp -f {} "$OUTPUT_DIR/" \;
}

require_command makepkg
require_command repo-add

mkdir -p "$OUTPUT_DIR"

for package_name in "${packages[@]}"; do
  build_package "$package_name"
done

(
  cd "$OUTPUT_DIR"
  rm -f "$REPO_NAME.db" "$REPO_NAME.files"
  repo-add "$REPO_NAME.db.tar.gz" ./*.pkg.tar.*
)

echo "Local KakkuOS package repo built:"
echo "  $OUTPUT_DIR"
echo
echo "Pacman repository stanza:"
cat <<EOF
[$REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$OUTPUT_DIR
EOF
