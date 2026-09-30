// Only emit fixed codes. HTTP bodies, headers and credentials remain private.
export function operationErrorCode(error) {
  const message = String(error?.message ?? "");
  if (error?.status === 429 || error?.statusCode === 429 ||
      /too many requests|(?:HTTP|status(?: code)?)\s*[:=]?\s*429\b/i.test(message))
    return "DESKTOP_RATE_LIMITED";
  if (message.includes("legacy pending")) return "LEGACY_IDENTITY_AMBIGUOUS";
  if (message.includes("GitHub plugin")) return "GITHUB_PLUGIN_UNAVAILABLE";
  if (/unsupported|capabilit|export contract|Desktop build/.test(message))
    return "DESKTOP_CAPABILITY_UNAVAILABLE";
  if (message.includes("project name")) return "PROJECT_UNAVAILABLE_OR_AMBIGUOUS";
  return "DESKTOP_OPERATION_UNAVAILABLE";
}
