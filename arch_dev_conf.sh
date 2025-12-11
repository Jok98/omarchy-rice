#!/usr/bin/env bash
set -eu
set -o pipefail

# =======================
# Config toggles
# =======================
: "${SKIP_UPGRADE:=0}"                 # 1 = skip full upgrade
: "${SDK_JAVA_ID:=21.0.8-zulu}"       # Java 21 (Zulu LTS). Change vendor/version if you prefer.

installed_components=()
skipped_components=()
failed_components=()

log() { echo "$(date +'%Y-%m-%d %H:%M:%S') - $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "❌ missing command: $1"; exit 1; }
}

# =======================
# Sanity checks
# =======================
if [ ! -f /etc/arch-release ]; then
  log "⚠️  This script is intended for Arch Linux. /etc/arch-release not found."
  log "    Continuing in 2s (Ctrl+C to abort)"; sleep 2
fi
need_cmd sudo
need_cmd bash

# =======================
# Package db sync/upgrade
# =======================
if [ "${SKIP_UPGRADE}" = "1" ]; then
  log "🔄 Refresh pacman db (no full upgrade)..."
  if sudo pacman -Sy --noconfirm; then
    installed_components+=("pacman -Sy")
  else
    failed_components+=("pacman -Sy")
  fi
else
  log "🔄 Full system upgrade (pacman -Syu)..."
  if sudo pacman -Syu --noconfirm; then
    installed_components+=("pacman -Syu")
  else
    failed_components+=("pacman -Syu")
  fi
fi

# Idempotent pacman install helper
install_pkgs() {
  local label="$1"; shift
  local pkgs=("$@")
  log "📦 Installing ${label}: ${pkgs[*]}"
  if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
    installed_components+=("${label}")
  else
    failed_components+=("${label}")
  fi
}

# =======================
# Base utilities
# =======================
install_pkgs "base utilities (curl zip unzip)" curl zip unzip

# =======================
# Git
# =======================
if ! command -v git >/dev/null 2>&1; then
  install_pkgs "Git" git
else
  log "✅ Git already installed."
  skipped_components+=("Git")
fi

# =======================
# SDKMAN wrappers (safe with set -u)
# =======================
sdkman_init_safe() {
  local init="$HOME/.sdkman/bin/sdkman-init.sh"
  if [[ -s "$init" ]]; then
    set +u
    # shellcheck source=/dev/null
    source "$init"
    local rc=$?
    set -u
    return $rc
  fi
  return 1
}

sdk_safe() {
  # Run `sdk ...` with -u disabled to avoid internal "unbound variable" errors
  set +u
  sdk "$@"
  local rc=$?
  set -u
  return $rc
}

# =======================
# Install / init SDKMAN
# =======================
if [ ! -d "$HOME/.sdkman" ]; then
  log "📥 Installing SDKMAN..."
  if curl -s "https://get.sdkman.io" | bash; then
    installed_components+=("SDKMAN")
    sdkman_init_safe || { log "⚠️ SDKMAN init failed (continuing)"; skipped_components+=("SDKMAN init"); }
  else
    log "❌ SDKMAN installation failed."
    failed_components+=("SDKMAN")
  fi
else
  log "✅ SDKMAN already installed."
  skipped_components+=("SDKMAN")
  sdkman_init_safe || { log "⚠️ SDKMAN init failed (continuing)"; skipped_components+=("SDKMAN init"); }
fi

# =======================
# Java 21 (via SDKMAN with pacman fallback)
# =======================
install_java21_with_sdkman() {
  # requires sdkman_init_safe to have been called already
  if ! sdk_safe current java 2>/dev/null | grep -qE 'Using.*\b21(\.|$)'; then
    log "☕ Installing Java (SDKMAN) ${SDK_JAVA_ID}..."
    if sdk_safe install java "${SDK_JAVA_ID}" && sdk_safe default java "${SDK_JAVA_ID}"; then
      installed_components+=("Java ${SDK_JAVA_ID}")
      return 0
    else
      log "⚠️ SDKMAN Java install failed."
      return 1
    fi
  else
    log "✅ Java 21 already active: $( (sdk_safe current java) || true )"
    skipped_components+=("Java 21")
    return 0
  fi
}

if command -v sdk >/dev/null 2>&1 && sdkman_init_safe; then
  if ! install_java21_with_sdkman; then
    log "➡️  Fallback: installing Java 21 via pacman (jdk21-openjdk)..."
    if sudo pacman -S --needed --noconfirm jdk21-openjdk; then
      installed_components+=("Java (jdk21-openjdk)")
    else
      failed_components+=("Java 21")
    fi
  fi
else
  log "⚠️ SDKMAN not initialized; installing Java 21 via pacman (jdk21-openjdk)..."
  if sudo pacman -S --needed --noconfirm jdk21-openjdk; then
    installed_components+=("Java (jdk21-openjdk)")
  else
    failed_components+=("Java 21")
  fi
fi

# =======================
# Maven (SDKMAN with pacman fallback)
# =======================
if ! command -v mvn >/dev/null 2>&1; then
  if command -v sdk >/dev/null 2>&1 && sdkman_init_safe; then
    log "📦 Installing Maven via SDKMAN..."
    if sdk_safe install maven; then
      installed_components+=("Maven (SDKMAN)")
    else
      log "⚠️ SDKMAN Maven failed; fallback pacman."
      install_pkgs "Maven" maven
    fi
  else
    log "⚠️ SDKMAN unavailable; installing Maven via pacman."
    install_pkgs "Maven" maven
  fi
else
  log "✅ Maven already installed."
  skipped_components+=("Maven")
fi

# =======================
# Helm (pacman first, then binary fallback)
# =======================
install_helm_binary() {
  if command -v helm >/dev/null 2>&1; then
    log "✅ Helm already installed: $(helm version --short 2>/dev/null || echo '?')"
    skipped_components+=("Helm")
    return
  fi
  log "📥 Installing Helm (binary fallback)..."
  local HELM_VERSION
  HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4)
  if [ -z "${HELM_VERSION:-}" ]; then
    log "❌ Unable to retrieve the latest Helm release."
    failed_components+=("Helm")
    return
  fi
  log "ℹ️ Latest Helm version is ${HELM_VERSION}"
  curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
  curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum"
  if ! sha256sum -c "helm-${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" --quiet; then
    log "❌ Helm checksum verification failed."
    failed_components+=("Helm")
    rm -f "helm-${HELM_VERSION}-linux-amd64.tar.gz"*
    return
  fi
  tar -zxf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
  sudo mv linux-amd64/helm /usr/local/bin/helm
  sudo chmod +x /usr/local/bin/helm
  if command -v helm >/dev/null 2>&1; then
    installed_components+=("Helm ${HELM_VERSION}")
  else
    failed_components+=("Helm")
  fi
  rm -rf "helm-${HELM_VERSION}-linux-amd64.tar.gz"* linux-amd64
}

if ! command -v helm >/dev/null 2>&1; then
  if sudo pacman -S --needed --noconfirm helm; then
    installed_components+=("Helm (pacman)")
  else
    log "⚠️ pacman Helm installation failed; using binary fallback."
    install_helm_binary
  fi
else
  log "✅ Helm already installed."
  skipped_components+=("Helm")
fi

# =======================
# Docker (service + group)
# =======================
if ! command -v docker >/dev/null 2>&1; then
  install_pkgs "Docker" docker
  log "⚙️ Enabling and starting Docker service..."
  if sudo systemctl enable --now docker; then
    installed_components+=("Docker service enabled")
  else
    failed_components+=("Docker service enable")
  fi
else
  log "✅ Docker already installed."
  skipped_components+=("Docker")
  sudo systemctl enable --now docker || true
fi

# docker group membership (idempotent)
if groups "$USER" | grep -qw docker; then
  log "✅ User '$USER' already in the 'docker' group."
  skipped_components+=("docker group membership")
else
  log "👤 Adding '$USER' to the 'docker' group..."
  if sudo usermod -aG docker "$USER"; then
    installed_components+=("docker group membership")
  else
    failed_components+=("docker group membership")
  fi
fi

# =======================
# kubectl
# =======================
if ! command -v kubectl >/dev/null 2>&1; then
  install_pkgs "kubectl" kubectl
else
  log "✅ kubectl already installed."
  skipped_components+=("kubectl")
fi

# =======================
# k3d (pacman first, fallback upstream)
# =======================
install_k3d_fallback() {
  log "📥 Installing k3d (upstream script)..."
  if curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; then
    installed_components+=("k3d (upstream)")
  else
    failed_components+=("k3d")
  fi
}

if ! command -v k3d >/dev/null 2>&1; then
  if sudo pacman -S --needed --noconfirm k3d; then
    installed_components+=("k3d (pacman)")
  else
    log "⚠️ pacman k3d installation failed; using upstream installer."
    install_k3d_fallback
  fi
else
  log "✅ k3d already installed."
  skipped_components+=("k3d")
fi

# =======================
# Node.js + npm
# =======================
if ! command -v npm >/dev/null 2>&1; then
  install_pkgs "Node.js and npm" nodejs npm
else
  log "✅ Node.js and npm already installed."
  skipped_components+=("Node.js and npm")
fi

# =======================
# Final summary
# =======================
printf "\n================== ✅ INSTALLATION SUMMARY ✅ ==================\n"
echo "🟢 Installed components:"
for item in "${installed_components[@]:-}"; do echo "   - $item"; done
printf "\n🟡 Already present components:\n"
for item in "${skipped_components[@]:-}"; do echo "   - $item"; done
if [ ${#failed_components[@]:-0} -ne 0 ]; then
  printf "\n🔴 Failed components:\n"
  for item in "${failed_components[@]}"; do echo "   - $item"; done
else
  printf "\n✅ No failed components.\n"
fi
printf "===============================================================\n\n"

log "✅ All development components installed/configured."
log "ℹ️ If you were added to the 'docker' group, reopen your session or run: newgrp docker"
log "ℹ️ To install desktop components (Hyprland, cursors, plugins), run: ./installation/desktop_setup.sh"
