#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Horologium Flutter project.
# Installs the CI-pinned Flutter SDK (if missing) and resolves dependencies.
set -euo pipefail

FLUTTER_VERSION="3.47.4"
FLUTTER_HOME="/opt/flutter"
FLUTTER_TARBALL="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TARBALL}"

log() { printf '[install] %s\n' "$*"; }

install_flutter() {
  if [ -x "${FLUTTER_HOME}/bin/flutter" ]; then
    log "Flutter already present at ${FLUTTER_HOME}"
    return
  fi
  log "Downloading Flutter ${FLUTTER_VERSION}..."
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/${FLUTTER_TARBALL}" "${FLUTTER_URL}"
  log "Extracting Flutter to ${FLUTTER_HOME}..."
  sudo mkdir -p "$(dirname "${FLUTTER_HOME}")"
  sudo tar xf "${tmp}/${FLUTTER_TARBALL}" -C "$(dirname "${FLUTTER_HOME}")"
  sudo chown -R "$(id -u):$(id -g)" "${FLUTTER_HOME}"
  rm -rf "${tmp}"
}

install_flutter

export PATH="${FLUTTER_HOME}/bin:${PATH}"

# git treats the SDK checkout as "dubious ownership" without this.
git config --global --add safe.directory "${FLUTTER_HOME}" || true
git config --global --add safe.directory "$(pwd)" || true

# Persist PATH and Chrome location for interactive/agent shells and for
# `flutter test --platform chrome`.
PROFILE_SNIPPET="/etc/profile.d/flutter.sh"
{
  echo 'export PATH="/opt/flutter/bin:$PATH"'
  if [ -x /usr/local/bin/google-chrome ]; then
    echo 'export CHROME_EXECUTABLE=/usr/local/bin/google-chrome'
  fi
} | sudo tee "${PROFILE_SNIPPET}" >/dev/null || {
  grep -q '/opt/flutter/bin' "${HOME}/.bashrc" || echo 'export PATH="/opt/flutter/bin:$PATH"' >>"${HOME}/.bashrc"
}

flutter config --no-analytics >/dev/null 2>&1 || true

log "Resolving Dart/Flutter dependencies..."
flutter pub get

log "Done. $(flutter --version | head -1)"
