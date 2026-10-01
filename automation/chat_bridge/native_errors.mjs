// Only emit fixed codes. HTTP bodies, headers and credentials remain private.
export const OPERATION_CODES = new Set(["DESKTOP_RATE_LIMITED", "DESKTOP_OPERATION_UNAVAILABLE",
  "DESKTOP_OPERATION_TIMEOUT", "LEGACY_IDENTITY_AMBIGUOUS", "GITHUB_PLUGIN_UNAVAILABLE",
  "THINKING_EFFORT_UNAVAILABLE", "DESKTOP_CAPABILITY_UNAVAILABLE", "PROJECT_UNAVAILABLE_OR_AMBIGUOUS"]);
export const RESOURCES = new Set(["conversation", "stream_status", "models", "projects", "desktop"]);

export function operationErrorCode(error) {
  const message = String(error?.message ?? "");
  if (OPERATION_CODES.has(message)) return message;
  if (error?.status === 429 || error?.statusCode === 429 || error?.responseStatus === 429 ||
      /too many requests|(?:HTTP|status(?: code)?)\s*[:=]?\s*429\b/i.test(message))
    return "DESKTOP_RATE_LIMITED";
  if (message.includes("legacy pending")) return "LEGACY_IDENTITY_AMBIGUOUS";
  if (message.includes("GitHub plugin")) return "GITHUB_PLUGIN_UNAVAILABLE";
  if (message === "THINKING_EFFORT_UNAVAILABLE") return "THINKING_EFFORT_UNAVAILABLE";
  if (/unsupported|capabilit|export contract|Desktop build/.test(message))
    return "DESKTOP_CAPABILITY_UNAVAILABLE";
  if (message.includes("project name")) return "PROJECT_UNAVAILABLE_OR_AMBIGUOUS";
  return "DESKTOP_OPERATION_UNAVAILABLE";
}

export function operationErrorObservation(error) {
  const result = {code:operationErrorCode(error)};
  const status = error?.http_status ?? error?.responseStatus ?? error?.statusCode ?? error?.status;
  if (Number.isInteger(status) && status >= 100 && status <= 599) result.http_status = status;
  if (RESOURCES.has(error?.resource)) result.resource = error.resource;
  return result;
}
