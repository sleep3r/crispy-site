#!/bin/sh
# Crispy — Linux installer
# Usage: curl -sL https://crispy.fyi/install.sh | sudo bash
#
# Auto-detects distro & architecture, downloads and installs
# the latest release (.deb / .rpm / AppImage fallback).

set -e

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}[  OK]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$1"; exit 1; }

# ── Root check ───────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    fail "This script must be run as root (use sudo)."
fi

# ── Architecture ─────────────────────────────────────────────
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)   ARCH_DEB="amd64";  ARCH_RPM="x86_64"; ARCH_AI="amd64";  ARCH_LABEL="x86_64" ;;
    aarch64|arm64)   ARCH_DEB="arm64";  ARCH_RPM="aarch64"; ARCH_AI="aarch64"; ARCH_LABEL="aarch64" ;;
    *)               fail "Unsupported architecture: $ARCH" ;;
esac
info "Architecture: ${BOLD}${ARCH_LABEL}${NC}"

# ── Fetch latest version ────────────────────────────────────
RELEASE_JSON=""
VERSION=""

fetch_release() {
    if command -v curl >/dev/null 2>&1; then
        RELEASE_JSON="$(curl -sL "$1")" || return 1
    elif command -v wget >/dev/null 2>&1; then
        RELEASE_JSON="$(wget -qO- "$1")" || return 1
    else
        fail "Neither curl nor wget found. Please install one of them."
    fi
}

info "Fetching latest release info..."

# Try release-info.json on the site first, then GitHub API
if fetch_release "https://crispy.fyi/release-info.json"; then
    VERSION="$(printf '%s' "$RELEASE_JSON" | grep -o '"version" *: *"[^"]*"' | head -1 | grep -o '"v[^"]*"' | tr -d '"')"
fi

if [ -z "$VERSION" ]; then
    if fetch_release "https://api.github.com/repos/sleep3r/crispy/releases/latest"; then
        VERSION="$(printf '%s' "$RELEASE_JSON" | grep -o '"tag_name" *: *"[^"]*"' | head -1 | grep -o '"v[^"]*"' | tr -d '"')"
    fi
fi

if [ -z "$VERSION" ]; then
    fail "Could not determine latest Crispy version."
fi

# Strip leading 'v' for filenames (e.g. v0.6.7 → 0.6.7)
VER_NUM="${VERSION#v}"
ok "Latest version: ${BOLD}${VERSION}${NC}"

GITHUB_DL="https://github.com/sleep3r/crispy/releases/download/${VERSION}"

# ── Detect package manager & install ─────────────────────────
install_deb() {
    DEB_FILE="Crispy_${VER_NUM}_${ARCH_DEB}.deb"
    DEB_URL="${GITHUB_DL}/${DEB_FILE}"
    TMP_DEB="/tmp/${DEB_FILE}"

    info "Downloading ${BOLD}${DEB_FILE}${NC}..."
    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$TMP_DEB" "$DEB_URL"
    else
        wget -qO "$TMP_DEB" "$DEB_URL"
    fi

    info "Installing via dpkg..."
    dpkg -i "$TMP_DEB" || true
    apt-get install -f -y >/dev/null 2>&1 || true

    rm -f "$TMP_DEB"
    ok "Crispy ${VERSION} installed successfully!"
}

install_rpm() {
    RPM_FILE="Crispy-${VER_NUM}-1.${ARCH_RPM}.rpm"
    RPM_URL="${GITHUB_DL}/${RPM_FILE}"
    TMP_RPM="/tmp/${RPM_FILE}"

    info "Downloading ${BOLD}${RPM_FILE}${NC}..."
    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$TMP_RPM" "$RPM_URL"
    else
        wget -qO "$TMP_RPM" "$RPM_URL"
    fi

    info "Installing via rpm..."
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y "$TMP_RPM"
    elif command -v yum >/dev/null 2>&1; then
        yum localinstall -y "$TMP_RPM"
    else
        rpm -i "$TMP_RPM"
    fi

    rm -f "$TMP_RPM"
    ok "Crispy ${VERSION} installed successfully!"
}

install_appimage() {
    AI_FILE="Crispy_${VER_NUM}_${ARCH_AI}.AppImage"
    AI_URL="${GITHUB_DL}/${AI_FILE}"
    INSTALL_DIR="/opt/crispy"
    DEST="${INSTALL_DIR}/${AI_FILE}"

    info "No apt/dnf/yum detected — falling back to AppImage."
    info "Downloading ${BOLD}${AI_FILE}${NC}..."
    mkdir -p "$INSTALL_DIR"

    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$DEST" "$AI_URL"
    else
        wget -qO "$DEST" "$AI_URL"
    fi

    chmod +x "$DEST"
    ln -sf "$DEST" /usr/local/bin/crispy

    ok "Crispy ${VERSION} installed to ${INSTALL_DIR}"
    ok "Run with: ${BOLD}crispy${NC}"
}

# ── Main ─────────────────────────────────────────────────────
if command -v apt-get >/dev/null 2>&1; then
    install_deb
elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    install_rpm
else
    install_appimage
fi

printf "\n${GREEN}${BOLD}✔ Done!${NC} Launch Crispy from your applications menu or run ${BOLD}crispy${NC} in the terminal.\n"
