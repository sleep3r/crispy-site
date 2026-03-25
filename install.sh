#!/bin/sh
# Crispy — Linux installer
# Usage: curl -sL https://crispy.fyi/install.sh | sudo bash
#
# Auto-detects distro & architecture, downloads and installs
# the latest release (.deb / .rpm / AppImage fallback).

set -e

# ── Colours (generate real ESC sequences, works in dash/bash/zsh) ────
ESC=$(printf '\033')
RED="${ESC}[0;31m"
GREEN="${ESC}[0;32m"
YELLOW="${ESC}[1;33m"
CYAN="${ESC}[0;36m"
BOLD="${ESC}[1m"
NC="${ESC}[0m"

info()  { printf "%s[INFO]%s  %s\n" "$CYAN" "$NC" "$1"; }
ok()    { printf "%s[  OK]%s  %s\n" "$GREEN" "$NC" "$1"; }
warn()  { printf "%s[WARN]%s  %s\n" "$YELLOW" "$NC" "$1"; }
fail()  { printf "%s[FAIL]%s  %s\n" "$RED" "$NC" "$1"; exit 1; }

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

# ── Download helper ──────────────────────────────────────────
download() {
    # $1 = URL, $2 = output path
    if command -v curl >/dev/null 2>&1; then
        curl -fSL --progress-bar -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -qO "$2" "$1"
    else
        fail "Neither curl nor wget found. Please install one of them."
    fi
}

fetch_text() {
    # $1 = URL → stdout
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$1"
    else
        fail "Neither curl nor wget found. Please install one of them."
    fi
}

# ── Fetch latest version ────────────────────────────────────
RELEASE_JSON=""
VERSION=""

info "Fetching latest release info..."

# Try release-info.json on the site first, then GitHub API
if RELEASE_JSON="$(fetch_text "https://crispy.fyi/release-info.json" 2>/dev/null)"; then
    VERSION="$(printf '%s' "$RELEASE_JSON" | grep -o '"version" *: *"[^"]*"' | head -1 | grep -o '"v[0-9][^"]*"' | tr -d '"')"
fi

if [ -z "$VERSION" ]; then
    if RELEASE_JSON="$(fetch_text "https://api.github.com/repos/sleep3r/crispy/releases/latest" 2>/dev/null)"; then
        VERSION="$(printf '%s' "$RELEASE_JSON" | grep -o '"tag_name" *: *"[^"]*"' | head -1 | grep -o '"v[0-9][^"]*"' | tr -d '"')"
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
    if ! download "$DEB_URL" "$TMP_DEB"; then
        fail "Failed to download ${DEB_FILE}. Check your internet connection."
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
    if ! download "$RPM_URL" "$TMP_RPM"; then
        fail "Failed to download ${RPM_FILE}. Check your internet connection."
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

    if ! download "$AI_URL" "$DEST"; then
        fail "Failed to download ${AI_FILE}. Check your internet connection."
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

printf "\n%s%s✔ Done!%s Launch Crispy from your applications menu or run %scrispy%s in the terminal.\n" "$GREEN" "$BOLD" "$NC" "$BOLD" "$NC"
