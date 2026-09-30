#!/usr/bin/env bash
# Historical tombstone: the experimental Niri native live-preview migration was
# retired. Keep this numbered migration in place because migration history is
# append-only. It must never install or enable a preview backend again.

MIGRATION_ID="046-niri-native-window-preview"
MIGRATION_TITLE="Retired Niri native preview"
MIGRATION_DESCRIPTION="Historical no-op retained for migration ordering; Niri Overview uses cached PNG snapshots only."
MIGRATION_TARGET_FILE=""
MIGRATION_REQUIRED=true

migration_check() {
  return 1
}

migration_preview() {
  echo "No changes. The experimental Niri native preview backend is retired."
}

migration_diff() {
  echo "No changes. Cleanup is owned by migration 048-retired-niri-live-preview."
}

migration_apply() {
  return 0
}
