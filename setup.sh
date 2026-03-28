#!/usr/bin/env bash
# shellcheck shell=bash
# ──────────────────────────────────────────────────────────────────────────────
# AstrBot Cross-Platform Installer  |  supports: Arch / Debian / Ubuntu / RHEL / Fedora / openSUSE
#
# Usage:
#   ./setup.sh               Install / Update AstrBot
#   ./setup.sh deps          Step 1: Install dependencies only
#   ./setup.sh setups        Step 2: Setup users / dirs / permissions
#   ./setup.sh files         Step 3: Clone app + install service
#   ./setup.sh help          Show this help
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_ALLGREETING="${SKIP_ALLGREETING:-false}"
SKIP_ALLDEPS="${SKIP_ALLDEPS:-false}"
SKIP_ALLSETUPS="${SKIP_ALLSETUPS:-false}"
SKIP_ALLFILES="${SKIP_ALLFILES:-false}"
FORCE_REINSTALL="${FORCE_REINSTALL:-false}"

## ─── Env defaults ──────────────────────────────────────────────────────────────
: "${ASTRBOT_USER:=astrbot}"
: "${ASTRBOT_GROUP:=astrbot}"
: "${ASTRBOT_HOME_DIR:=/var/lib/astrbot}"
: "${ASTRBOT_APP_DIR:=/opt/astrbot}"
: "${ASTRBOT_DATA_DIR:=/var/lib/astrbot}"
: "${ASTRBOT_CACHE_DIR:=/var/cache/astrbot}"
: "${ASTRBOT_CONFIG_DIR:=/etc/astrbot}"
: "${ASTRBOT_UPSTREAM:=https://github.com/AstrBotDevs/AstrBot.git}"
: "${ASTRBOT_BRANCH:=dev}"

## ─── Style helpers ─────────────────────────────────────────────────────────────
if command -v tput >/dev/null 2>&1 && [[ -n "$(tput colors 2>/dev/null)" ]]; then
  RST="$(tput sgr0)";  BOLD="$(tput bold)"
  DIM="$(tput dim)";   RED="$(tput setaf 1)";  GRN="$(tput setaf 2)"
  YEL="$(tput setaf 3)";CYN="$(tput setaf 6)";  ULN="$(tput smul)"
else
  RST="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
  RED="\033[31m"; GRN="\033[32m"; YEL="\033[33m"; CYN="\033[36m"; ULN="\033[4m"
fi

_log()   { printf '%s[%s]%s %s\n' "${DIM}" "$(date '+%H:%M:%S')" "${RST}" "$*"; }
info()   { printf '%sℹ%s %s\n' "${CYN}" "${RST}" "$*"; }
ok()     { printf '%s✔%s %s\n' "${GRN}" "${RST}" "$*"; }
warn()   { printf '%s⚠%s %s\n' "${YEL}" "${RST}" "$*" >&2; }
err()    { printf '%s✖%s %s\n' "${RED}" "${RST}" "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"; }

## ─── Privilege ────────────────────────────────────────────────────────────────
prevent_root() {
  [[ "${EUID}" -eq 0 ]] && err "Do NOT run as root. The installer asks for sudo when needed."
}
require_root() { sudo -n true 2>/dev/null || err "Root required. Run with sudo or as root."; }

sudo_keepalive() {
  [[ "${EUID}" -eq 0 ]] && return 0
  command -v sudo >/dev/null || err "sudo is required."
  sudo -v 2>/dev/null &
  sudo_pid=$!
}
sudo_release() { [[ -n "${sudo_pid:-}" ]] && kill "${sudo_pid}" 2>/dev/null || true; }
trap sudo_release EXIT INT TERM

## ─── Distro detection ─────────────────────────────────────────────────────────
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DIST_ID="${ID:-unknown}"; DIST_ID_LIKE="${ID_LIKE:-}"; DIST_VER="${VERSION:-}"
  elif [[ -f /etc/redhat-release ]]; then DIST_ID="rhel"; DIST_ID_LIKE="rhel"
  elif [[ -f /etc/debian_version ]]; then DIST_ID="debian"; DIST_ID_LIKE="debian"
  else DIST_ID="unknown"; DIST_ID_LIKE=""
  fi
  case "${DIST_ID_LIKE}" in
    *debian*|"") DIST_FAM="debian" ;;
    *rhel*|*fedora*) DIST_FAM="rhel" ;;
    *arch*) DIST_FAM="arch" ;;
    *suse*) DIST_FAM="suse" ;;
    *) DIST_FAM="${DIST_ID}" ;;
  esac
  _log "Detected: ${DIST_ID} (${DIST_FAM}) ${DIST_VER}"
}

## ─── Package installers ────────────────────────────────────────────────────────
_install_deps_arch() {
  need_cmd pacman
  _log "Installing via pacman..."
  sudo pacman -Sy --needed --noconfirm python python-pip uv git certbot rust cargo
}

_install_deps_debian() {
  need_cmd apt-get
  _log "Installing via apt..."
  local pkgs=(python3 python3-pip python3-venv git certbot curl wget)
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
  if ! command -v rustc >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
}

_install_deps_rhel() {
  _log "Installing via dnf/yum..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3 python3-pip git certbot curl
  else
    sudo yum install -y python3 python3-pip git certbot curl
  fi
  if ! command -v rustc >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
}

_install_deps_suse() {
  need_cmd zypper
  _log "Installing via zypper..."
  sudo zypper install -y python3 python3-pip git certbot curl rust
}

install_deps() {
  detect_distro
  case "${DIST_FAM}" in
    arch)     _install_deps_arch ;;
    debian)   _install_deps_debian ;;
    rhel)     _install_deps_rhel ;;
    suse)     _install_deps_suse ;;
    *)        warn "Unknown distro. Trying Debian approach..."; _install_deps_debian ;;
  esac
  need_cmd git; need_cmd python3
  ok "Dependencies installed."
}

## ─── Setup: users, dirs, permissions ─────────────────────────────────────────
setup_perms() {
  require_root
  _log "Creating user '${ASTRBOT_USER}'..."
  if ! getent passwd "${ASTRBOT_USER}" >/dev/null 2>&1; then
    sudo useradd -r -M -d "${ASTRBOT_HOME_DIR}" -s /usr/bin/nologin \
      -c "AstrBot Service User" "${ASTRBOT_USER}"
    ok "User created."
  else
    info "User already exists."
  fi

  _log "Creating directories..."
  sudo install -dm755 -o "${ASTRBOT_USER}" -g "${ASTRBOT_GROUP}" "${ASTRBOT_DATA_DIR}"
  sudo install -dm755 -o "${ASTRBOT_USER}" -g "${ASTRBOT_GROUP}" "${ASTRBOT_CACHE_DIR}"
  sudo install -dm755 -o "${ASTRBOT_USER}" -g "${ASTRBOT_GROUP}" "${ASTRBOT_CACHE_DIR}/python"
  sudo install -dm755 -o "${ASTRBOT_USER}" -g "${ASTRBOT_GROUP}" "${ASTRBOT_CACHE_DIR}/cargo"
  sudo install -dm755 -o "${ASTRBOT_USER}" -g "${ASTRBOT_GROUP}" "${ASTRBOT_CACHE_DIR}/rustup"
  sudo install -dm755 -o "${ASTRBOT_USER}" -g "${ASTRBOT_GROUP}" "${ASTRBOT_CACHE_DIR}/cargo_target"
  sudo install -dm755 -o root    -g root    "${ASTRBOT_CONFIG_DIR}"
  sudo install -dm755 -o root    -g root    "${ASTRBOT_APP_DIR}"
  ok "Directories created."

  _log "Setting ownership..."
  sudo chown -R "${ASTRBOT_USER}:${ASTRBOT_GROUP}" "${ASTRBOT_DATA_DIR}" "${ASTRBOT_CACHE_DIR}" 2>/dev/null || true
  git config --global --add safe.directory "${ASTRBOT_APP_DIR}" 2>/dev/null || true
  ok "Permissions set."
}

## ─── Files: clone app + install service ───────────────────────────────────────
install_files() {
  require_root
  _log "Cloning AstrBot (${ASTRBOT_BRANCH}) → ${ASTRBOT_APP_DIR}..."

  if mount | grep -q " ${ASTRBOT_APP_DIR} "; then
    info "Overlay mount detected — skipping clone (update in progress)."
  elif [[ -d "${ASTRBOT_APP_DIR}" ]]; then
    if [[ "${FORCE_REINSTALL}" == true ]]; then
      warn "Force reinstall — removing existing ${ASTRBOT_APP_DIR}"
      sudo rm -rf "${ASTRBOT_APP_DIR}"
    else
      info "${ASTRBOT_APP_DIR} already exists. Skipping clone."
      info "Use FORCE_REINSTALL=true to override."
    fi
  fi

  if [[ ! -d "${ASTRBOT_APP_DIR}" ]]; then
    git clone -b "${ASTRBOT_BRANCH}" "${ASTRBOT_UPSTREAM}" "${ASTRBOT_APP_DIR}" || \
      err "Failed to clone AstrBot to ${ASTRBOT_APP_DIR}"
    local ver
    ver=$(git -C "${ASTRBOT_APP_DIR}" describe --tags 2>/dev/null || \
          git -C "${ASTRBOT_APP_DIR}" rev-parse --short HEAD)
    ok "Cloned: ${ver}"
  fi

  _log "Installing systemd service..."
  if [[ -f "${REPO_ROOT}/astrbot@.service" ]]; then
    sudo install -Dm644 "${REPO_ROOT}/astrbot@.service" \
      "/etc/systemd/system/astrbot@.service"
    sudo systemctl daemon-reload
    ok "systemd service installed."
  fi
}

## ─── Subcommands ────────────────────────────────────────────────────────────────
show_help() {
  printf '%s\n' ""
  printf '%s╔═══════════════════════════════════════════════════════╗%s\n' "${CYN}" "${RST}"
  printf '%s║%s        ✦ AstrBot Cross-Platform Installer ✦          %s║%s\n' "${CYN}" "${RST}" "${BOLD}${CYN}" "${RST}"
  printf '%s╠═══════════════════════════════════════════════════════╣%s\n' "${CYN}" "${RST}"
  printf '%s║%s  Supports: Arch / Debian / Ubuntu / RHEL / Fedora…    %s║%s\n' "${CYN}" "${RST}" "${DIM}" "${RST}"
  printf '%s╚═══════════════════════════════════════════════════════╝%s\n' "${CYN}" "${RST}"
  printf '%s\n' ""
  printf '  %s./setup.sh%s          Install / Update AstrBot\n' "${GRN}" "${RST}"
  printf '  %s./setup.sh deps%s     Step 1 — Install system dependencies\n' "${GRN}" "${RST}"
  printf '  %s./setup.sh setups%s    Step 2 — Setup users, dirs, permissions\n' "${GRN}" "${RST}"
  printf '  %s./setup.sh files%s    Step 3 — Clone app + install service\n' "${GRN}" "${RST}"
  printf '  %s./setup.sh help%s     Show this help\n' "${GRN}" "${RST}"
  printf '%s\n' ""
  printf '  %sNOTE:%s  Run %swithout sudo%s — the installer asks when needed.\n' "${YEL}" "${RST}" "${BOLD}" "${RST}"
  printf '%s\n' ""
}

show_banner() {
  printf '\n%s╔═══════════════════════════════════════════════════════════╗%s\n' "${CYN}" "${RST}"
  printf '%s║%s            ✦ AstrBot Cross-Platform Installer ✦              %s║%s\n' "${CYN}" "${RST}" "${BOLD}${CYN}" "${RST}"
  printf '%s╠═══════════════════════════════════════════════════════════╣%s\n' "${CYN}" "${RST}"
  printf '%s║%s  Multi-instance AI chatbot  ·  Discord · Telegram · …      %s║%s\n' "${CYN}" "${RST}" "${DIM}" "${RST}"
  printf '%s╠═══════════════════════════════════════════════════════════╣%s\n' "${CYN}" "${RST}"
  printf '%s║%s  GitHub: %shttps://github.com/AstrBotDevs/AstrBot%s              %s║%s\n' \
    "${CYN}" "${RST}" "${ULN}${CYN}" "${RST}" "${CYN}" "${RST}"
  printf '%s╚═══════════════════════════════════════════════════════════╝%s\n' "${CYN}" "${RST}"
  printf '\n'
}


pause() { [[ "${CI:-false}" == true ]] && return 0; printf '\n%sPress %sENTER%s to continue...%s\n' "${DIM}" "${BOLD}" "${RST}" "${DIM}"; read -r _ </dev/tty; }

## ─── Main dispatch ─────────────────────────────────────────────────────────────
prevent_root

case "${1:-install}" in
  ""|install)
    sudo_keepalive
    [[ "${SKIP_ALLGREETING}" != true ]] && show_banner
    [[ "${SKIP_ALLDEPS}"    != true ]] && { install_deps; pause; }
    [[ "${SKIP_ALLSETUPS}"  != true ]] && { setup_perms; pause; }
    [[ "${SKIP_ALLFILES}"   != true ]] && install_files
    printf '\n'
    ok "AstrBot is ready!"
    printf '\n  %sCreate an instance:%s    %sastrbotctl init <name>%s\n' "${BOLD}" "${RST}" "${GRN}" "${RST}"
    printf '  %sStart service:%s         %ssudo systemctl start astrbot@<name>%s\n' "${BOLD}" "${RST}" "${GRN}" "${RST}"
    printf '  %sEnable on boot:%s         %ssudo systemctl enable --now astrbot@<name>%s\n' "${BOLD}" "${RST}" "${GRN}" "${RST}"
    printf '  %sDocs:%s                   %shttps://docs.astrbot.app%s\n' "${BOLD}" "${RST}" "${CYN}" "${RST}"
    printf '\n'
    ;;
  deps)     install_deps ;;
  setups)    sudo_keepalive; setup_perms ;;
  files)     sudo_keepalive; install_files ;;
  help|--help|-h) show_help ;;
  *)         err "Unknown subcommand: $1  (try: ./setup.sh help)" ;;
esac
