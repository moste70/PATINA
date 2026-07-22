#!/bin/bash
# Installs the Flutter SDK (pinned to the version used by
# .github/workflows/build-apk.yml) and prepares the app/ project so it can be
# analyzed, tested and built during Claude Code on the web sessions.
#
# Idempotent: safe to run on every session start. If the SDK and generated
# code are already present (e.g. cached container), the heavy steps are
# skipped.
set -euo pipefail

# Only needed for Claude Code on the web / remote sessions.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.32.0"
FLUTTER_ROOT="/opt/flutter-sdk/flutter"
APP_DIR="$CLAUDE_PROJECT_DIR/app"

export CI=true # suppresses the "running as root" prompt and analytics banner

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Installing Flutter $FLUTTER_VERSION..."
  TMP_TAR="$(mktemp -t flutter_linux_XXXXXX.tar.xz)"
  curl -fsSL -o "$TMP_TAR" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  mkdir -p "$(dirname "$FLUTTER_ROOT")"
  tar -xf "$TMP_TAR" -C "$(dirname "$FLUTTER_ROOT")"
  rm -f "$TMP_TAR"
  git config --global --add safe.directory "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"
echo "export PATH=\"$FLUTTER_ROOT/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
echo "export CI=true" >> "$CLAUDE_ENV_FILE"

flutter config --no-analytics >/dev/null 2>&1 || true

cd "$APP_DIR"
flutter pub get

# Drift DB codegen — app_database.g.dart is gitignored and required by
# almost every feature file (see CLAUDE.md).
flutter pub run build_runner build --delete-conflicting-outputs

# l10n codegen — app_localizations.dart is gitignored and required by any
# screen using AppL10n.of(context).
flutter gen-l10n

echo "Flutter $FLUTTER_VERSION ready. 'flutter analyze' / 'flutter test' work out of the box."
echo "NOTE: full 'flutter build apk' also needs the Android SDK + Google's Maven repo"
echo "(dl.google.com), which this environment's network policy currently blocks — the"
echo "build-apk.yml GitHub Action remains the source of truth for real APK builds."
