#!/usr/bin/env bash

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <target_locale> [model]"
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
SHELL_CONFIG_DIR="$(inir_config_dir)"
SHELL_CONFIG_FILE="$(inir_config_file)"
TRANSLATIONS_DIR="${SCRIPT_DIR}/../../translations"
TRANSLATIONS_TARGET_DIR="${SHELL_CONFIG_DIR}/translations"
SOURCE_FILE="${TRANSLATIONS_DIR}/en_US.json"
NOTIFICATION_APP_NAME="Shell"
TARGET_LOCALE="$1"
MODEL="${2:-${GEMINI_MODEL:-gemini-2.5-flash}}"
TARGET_FILE="${TRANSLATIONS_TARGET_DIR}/${TARGET_LOCALE}.json"

notify_error() {
    notify-send -u critical "Translation failed" "$1" -a "$NOTIFICATION_APP_NAME"
    echo "ERROR: $1" >&2
    exit 1
}

# Locale IDs become file names under the user's config tree. Accept common
# locale/BCP-47-like identifiers only; never allow path separators or traversal.
if [[ ! "$TARGET_LOCALE" =~ ^[A-Za-z]{2,3}([_-][A-Za-z0-9]{2,8})*$ ]]; then
    notify_error "Invalid locale code '$TARGET_LOCALE'. Use a locale such as fr_FR, pt_BR, or zh-CN."
fi

# Runtime packages intentionally exclude translations/tools. The shipped
# canonical catalog already matches the shipped QML snapshot, so generation
# must consume it directly rather than invoking source-maintenance tooling.
if [[ ! -r "$SOURCE_FILE" ]] || ! jq -e 'type == "object" and length > 0' "$SOURCE_FILE" >/dev/null 2>&1; then
    notify_error "The bundled English translation catalog is missing or invalid."
fi
if ! mkdir -p "$TRANSLATIONS_TARGET_DIR"; then
    notify_error "Could not create the user translation directory."
fi

# Get API key
API_KEY=$(secret-tool lookup 'application' 'illogical-impulse' 2>/dev/null | jq -r '.apiKeys.gemini // empty')
if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
    notify_error "Gemini API key not set. Type /key on the AI sidebar to configure."
fi

# Notify start
notify-send "Translation started" "Translating to $TARGET_LOCALE with $MODEL. Takes ~2 minutes, you'll be notified when done." -a "$NOTIFICATION_APP_NAME"

# Build payload via jq (--rawfile avoids MAX_ARG_STRLEN) and pipe to curl
instruction='You are to translate the user interface of a **desktop shell**. Given a JSON object of key-value pairs, return a JSON with the same structure, with keys unchanged and values translated to '"$TARGET_LOCALE"'. Be as **concise** as possible to save screen space, and make sure terminology is relevant (e.g. "discharging" refers to the battery status). Preserve placeholders like %1, %2, {0}, <name> verbatim. Preserve newline characters (\n), HTML/markup tags, and trailing /*keep*/ markers exactly as in the source.'

# 5-minute timeout — long enough for ~3800 strings, short enough to detect API hang.
response=$(jq -n \
    --arg prompt_text "$instruction" \
    --rawfile content "$SOURCE_FILE" \
    --arg temperature "0" \
    --arg model "$MODEL" \
    '{
        contents: [{
            parts: [
                {text: ($prompt_text + "\n```\n" + $content + "\n```\n")}
            ]
        }],
        generationConfig: {
            temperature: ($temperature | tonumber),
            "responseMimeType": "application/json"
        }
    }' | curl --max-time 300 --fail-with-body --silent --show-error \
    "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
    -H "x-goog-api-key: $API_KEY" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d @- 2>&1)
curl_status=$?

if [[ $curl_status -ne 0 ]]; then
    # Try to extract API error message if present
    api_err=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    notify_error "Gemini API call failed (curl ${curl_status}). ${api_err:-Network or auth error.}"
fi

# Extract the JSON content. Bail if Gemini returned an error or empty result.
translated=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
if [[ -z "$translated" ]]; then
    api_err=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    notify_error "Empty Gemini response. ${api_err:-(model may have refused; check API quota/safety filters)}"
fi

# Validate that what we got is actually parseable JSON before overwriting the target file.
if ! echo "$translated" | jq -e 'type == "object"' >/dev/null 2>&1; then
    notify_error "Gemini returned non-JSON output. Translation discarded — your existing $TARGET_LOCALE.json is untouched."
fi

# Atomic write so a half-written file can't ever appear. Exact key parity is
# mandatory: generated translations may change values, never the runtime keys.
tmp_file="${TARGET_FILE}.tmp.$$"
printf '%s\n' "$translated" > "$tmp_file"
if ! jq -e --slurpfile source "$SOURCE_FILE" \
    'type == "object" and all(.[]; type == "string") and ((keys | sort) == ($source[0] | keys | sort))' \
    "$tmp_file" >/dev/null 2>&1; then
    rm -f "$tmp_file"
    notify_error "Gemini changed, omitted, or added translation keys. Translation discarded."
fi
if ! mv "$tmp_file" "$TARGET_FILE"; then
    rm -f "$tmp_file"
    notify_error "Could not save the generated translation."
fi

# Activate the new locale with the same config lock used by other writers.
# Saving the translation and activating it are separate verified steps: never
# report full success when config mutation failed.
config_tmp="${SHELL_CONFIG_FILE}.tmp.$$"
if ! (
    flock -w 5 200 || { echo "config lock timeout" >&2; exit 1; }
    jq --arg locale "$TARGET_LOCALE" '.language.ui = $locale' "$SHELL_CONFIG_FILE" > "$config_tmp" \
        && mv "$config_tmp" "$SHELL_CONFIG_FILE"
) 200>"${SHELL_CONFIG_FILE}.lock"; then
    rm -f "$config_tmp"
    notify_error "Translation was saved, but the locale could not be activated. Select it again from Settings after checking the config file."
fi

notify-send "Translation complete" "Saved to ${TARGET_FILE}. Edit there to refine." -a "$NOTIFICATION_APP_NAME"
