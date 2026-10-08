# Retained migration identity; this integration is now optional in Hadalird.
# Never install helpers, enable services, mask providers or change profiles
# when installing/updating the core shell.
MIGRATION_ID="037-battery-charge-limit-helper"
MIGRATION_TITLE="Optional Hadalird TLP helper"
MIGRATION_DESCRIPTION="Managed separately by the optional Hadalird package."
MIGRATION_REQUIRED=false
migration_check() { return 1; }
migration_preview() { printf '%s\n' 'Install and configure Hadalird separately to use this integration.'; }
migration_apply() { return 0; }
