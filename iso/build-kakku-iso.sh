#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KAKKU_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHYOS_LIVE_ISO_REPO="${CACHYOS_LIVE_ISO_REPO:-https://github.com/CachyOS/CachyOS-Live-ISO.git}"
CACHYOS_LIVE_ISO_REF="${CACHYOS_LIVE_ISO_REF:-master}"
CACHYOS_LIVE_ISO_DIR="${CACHYOS_LIVE_ISO_DIR:-$SCRIPT_DIR/.cache/cachyos-live-iso}"
CACHYOS_BUILD_PROFILE="${CACHYOS_BUILD_PROFILE:-desktop}"
KAKKU_REPO_NAME="${KAKKU_REPO_NAME:-kakku-local}"
KAKKU_LOCAL_REPO_DIR="${KAKKU_LOCAL_REPO_DIR:-$KAKKU_ROOT/packaging/repo}"
KAKKU_CLI_INSTALLER_PACKAGE="${KAKKU_CLI_INSTALLER_PACKAGE:-cachyos-cli-installer-new}"
KAKKU_CLI_INSTALLER_BIN="${KAKKU_CLI_INSTALLER_BIN:-cachyos-installer}"

prepare_only=0
clean=0
skip_local_repo=0

usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --prepare-only       Clone/update CachyOS-Live-ISO and stage KakkuOS without building.
  --clean              Remove the cached CachyOS-Live-ISO checkout before preparing.
  --repo URL           CachyOS-Live-ISO git URL.
  --ref REF            CachyOS-Live-ISO branch, tag, or commit. Default: master.
  --dir PATH           CachyOS-Live-ISO checkout path. Default: iso/.cache/cachyos-live-iso.
  --skip-local-repo    Do not build/inject the local KakkuOS package repo.
  -h, --help           Show this help.

Environment:
  CACHYOS_LIVE_ISO_REPO
  CACHYOS_LIVE_ISO_REF
  CACHYOS_LIVE_ISO_DIR
  CACHYOS_BUILD_PROFILE
  KAKKU_LOCAL_REPO_DIR
  KAKKU_REPO_NAME
  KAKKU_CLI_INSTALLER_PACKAGE
  KAKKU_CLI_INSTALLER_BIN
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare-only)
      prepare_only=1
      shift
      ;;
    --clean)
      clean=1
      shift
      ;;
    --repo)
      CACHYOS_LIVE_ISO_REPO="$2"
      shift 2
      ;;
    --ref)
      CACHYOS_LIVE_ISO_REF="$2"
      shift 2
      ;;
    --dir)
      CACHYOS_LIVE_ISO_DIR="$2"
      shift 2
      ;;
    --skip-local-repo)
      skip_local_repo=1
      shift
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

read_package_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    sed -E '/^[[:space:]]*#/d;/^[[:space:]]*$/d;s/[[:space:]]+$//g' "$file"
  fi
}

read_kakku_repo_packages() {
  read_package_file "$KAKKU_ROOT/packages/pacman.txt"

  if [[ -d "$KAKKU_ROOT/packages/profiles" ]]; then
    for package_file in "$KAKKU_ROOT"/packages/profiles/*.txt; do
      [[ -f "$package_file" ]] || continue
      read_package_file "$package_file"
    done
  fi
}

build_local_repo() {
  if (( skip_local_repo )); then
    return
  fi

  "$KAKKU_ROOT/packaging/build-local-repo.sh" \
    --output "$KAKKU_LOCAL_REPO_DIR" \
    --repo-name "$KAKKU_REPO_NAME"
}

clone_or_update_cachyos_live_iso() {
  if (( clean )) && [[ -d "$CACHYOS_LIVE_ISO_DIR" ]]; then
    rm -rf "$CACHYOS_LIVE_ISO_DIR"
  fi

  if [[ -d "$CACHYOS_LIVE_ISO_DIR/.git" ]]; then
    git -C "$CACHYOS_LIVE_ISO_DIR" fetch --prune origin
  else
    mkdir -p "$(dirname "$CACHYOS_LIVE_ISO_DIR")"
    git clone "$CACHYOS_LIVE_ISO_REPO" "$CACHYOS_LIVE_ISO_DIR"
  fi

  git -C "$CACHYOS_LIVE_ISO_DIR" checkout "$CACHYOS_LIVE_ISO_REF"
}

append_unique_packages() {
  local target="$1"
  shift
  local tmp

  tmp="$(mktemp)"
  {
    read_package_file "$target"
    printf '%s\n' "$@"
  } | awk '!seen[$0]++' > "$tmp"
  mv "$tmp" "$target"
}

remove_gui_installer_packages() {
  local target="$1"
  local tmp

  tmp="$(mktemp)"
  read_package_file "$target" |
    grep -Ev '^(calamares|cachyos-calamares.*|cachyos-hello)$' > "$tmp"
  mv "$tmp" "$target"
}

install_cli_installer_entrypoint() {
  local airootfs="$1"

  install -dm755 "$airootfs/usr/local/bin"
  cat > "$airootfs/usr/local/bin/kakku-install" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
  exec $KAKKU_CLI_INSTALLER_BIN "\$@"
fi

exec sudo $KAKKU_CLI_INSTALLER_BIN "\$@"
EOF
  chmod 755 "$airootfs/usr/local/bin/kakku-install"

  install -dm755 "$airootfs/etc/profile.d"
  cat > "$airootfs/etc/profile.d/kakku-installer.sh" <<'EOF'
if [ -z "${KAKKU_INSTALLER_HINT_SHOWN:-}" ] && [ -t 1 ]; then
  export KAKKU_INSTALLER_HINT_SHOWN=1
  printf '\nKakkuOS installer: run %s to start the CLI installer.\n\n' "kakku-install"
fi
EOF
  chmod 644 "$airootfs/etc/profile.d/kakku-installer.sh"
}

inject_local_repo() {
  local archiso_dir="$1"
  local airootfs="$2"
  local repo_target="$airootfs/opt/kakkuos/repo"
  local pacman_conf="$archiso_dir/pacman.conf"

  if (( skip_local_repo )); then
    echo "Skipping local KakkuOS package repo injection."
    return
  fi

  if [[ ! -d "$KAKKU_LOCAL_REPO_DIR" ]]; then
    echo "Missing local KakkuOS package repo: $KAKKU_LOCAL_REPO_DIR" >&2
    echo "Run packaging/build-local-repo.sh first, or rerun without --skip-local-repo." >&2
    exit 1
  fi

  mkdir -p "$repo_target"
  rsync -a --delete "$KAKKU_LOCAL_REPO_DIR/" "$repo_target/"

  if ! grep -q "^\[$KAKKU_REPO_NAME\]$" "$pacman_conf"; then
    cat <<EOF >> "$pacman_conf"

[$KAKKU_REPO_NAME]
SigLevel = Optional TrustAll
Server = file:///opt/kakkuos/repo
EOF
  fi
}

stage_kakkuos() {
  local archiso_dir="$CACHYOS_LIVE_ISO_DIR/archiso"
  local airootfs="$archiso_dir/airootfs"
  local packages_file="$archiso_dir/packages_desktop.x86_64"
  local staged_source="$airootfs/opt/kakkuos"

  if [[ ! -d "$archiso_dir" || ! -f "$packages_file" ]]; then
    echo "Unexpected CachyOS-Live-ISO layout at $CACHYOS_LIVE_ISO_DIR" >&2
    exit 1
  fi

  mkdir -p "$staged_source"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.agents' \
    --exclude '.codex' \
    --exclude 'iso/.cache' \
    --exclude 'iso/out' \
    "$KAKKU_ROOT/" "$staged_source/"

  install -Dm644 "$KAKKU_ROOT/branding/wallpaper.png" "$airootfs/usr/share/backgrounds/kakku/wallpaper.png"
  install -Dm644 "$KAKKU_ROOT/branding/logo.png" "$airootfs/usr/share/pixmaps/kakku-logo.png"
  install -Dm644 "$KAKKU_ROOT/system/os-release" "$airootfs/usr/share/kakku/os-release"

  inject_local_repo "$archiso_dir" "$airootfs"
  remove_gui_installer_packages "$packages_file"
  append_unique_packages "$packages_file" kakku-desktop "$KAKKU_CLI_INSTALLER_PACKAGE"
  install_cli_installer_entrypoint "$airootfs"

  echo "Prepared CachyOS-Live-ISO checkout:"
  echo "  $CACHYOS_LIVE_ISO_DIR"
  echo
  echo "Staged KakkuOS source:"
  echo "  $staged_source"
  echo
  echo "Updated package list:"
  echo "  $packages_file"
  echo
  echo "CLI installer entrypoint:"
  echo "  $airootfs/usr/local/bin/kakku-install"
  if (( ! skip_local_repo )); then
    echo
    echo "Injected local KakkuOS package repo:"
    echo "  $airootfs/opt/kakkuos/repo"
  fi
}

build_iso() {
  cd "$CACHYOS_LIVE_ISO_DIR"
  sudo ./buildiso.sh -p "$CACHYOS_BUILD_PROFILE" -v -w
}

require_command git
require_command rsync
require_command sed
require_command awk

build_local_repo
clone_or_update_cachyos_live_iso
stage_kakkuos

if (( prepare_only )); then
  echo
  echo "Prepare-only mode complete. Review the staged CachyOS tree before building."
  exit 0
fi

build_iso
