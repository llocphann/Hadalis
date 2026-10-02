/* Desktop owns authentication. This adapter never reads tokens/cookies.
 * Installed renderer exports are private APIs: probe the installed build,
 * validate identities and fail closed before dispatch if it is unsupported.
 */
import fs from "node:fs";
import crypto from "node:crypto";
import {operationErrorObservation} from "./native_errors.mjs";

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function activeBranch(conversation) {
  const mapping = conversation?.mapping;
  if (!mapping || typeof mapping !== "object") throw new Error("conversation mapping unavailable");
  let id = conversation.current_node;
  const branch = [], seen = new Set();
  while (id && mapping[id] && !seen.has(id) && branch.length < 10000) {
    seen.add(id);
    const node = mapping[id];
    branch.push(node);
    id = node.parent;
  }
  return branch.reverse();
}

export function projectTurn(conversation, pending) {
  if (conversation.conversation_id && conversation.conversation_id !== pending.conversation_id)
    throw new Error("conversation identity mismatch");
  const branch = activeBranch(conversation);
  const start = branch.findIndex(n => n.message?.id === pending.user_message_id || n.id === pending.user_message_id);
  if (start < 0) return { completed: false, submitted: false };
  const messages = branch.slice(start + 1).map(n => n.message).filter(Boolean);
  // A response from a different user turn must never satisfy this receipt.
  const nextUser = messages.findIndex(m => m.author?.role === "user");
  const turn = nextUser < 0 ? messages : messages.slice(0, nextUser);
  const final = turn.findLast(m => m.author?.role === "assistant" &&
    m.recipient === "all" && (m.channel == null || m.channel === "final") &&
    m.status === "finished_successfully" && m.end_turn === true);
  if (!final) {
    const lastAssistant=turn.findLast(m=>m.author?.role === "assistant");
    return { completed: false, submitted: true,
      superseded: nextUser >= 0,
      ...(nextUser >= 0 ? {successor_user_message_id: messages[nextUser].id} : {}),
      streamError: turn.some(m => ["failed", "error", "cancelled"].includes(m.status)),
      terminal_failed: !!lastAssistant && ["failed","error","cancelled"].includes(lastAssistant.status) && lastAssistant.end_turn === true };
  }
  return { completed: true, submitted: true, response: {
    message_id: final.id, text: (final.content?.parts ?? []).filter(p => typeof p === "string").join("\n")
  }};
}

function asarReader(path) {
  const fd = fs.openSync(path, "r");
  const h = Buffer.alloc(16); fs.readSync(fd, h, 0, 16, 0);
  const size = h.readUInt32LE(12), offset = 8 + h.readUInt32LE(4);
  if (size > 32 * 1024 * 1024) throw new Error("invalid Desktop archive");
  const data = Buffer.alloc(size); fs.readSync(fd, data, 0, size, 16);
  const root = JSON.parse(data.toString());
  return {
    files: Object.keys(root.files.webview.files.assets.files),
    read(name) {
      const entry = root.files.webview.files.assets.files[name];
      if (!entry || entry.unpacked || entry.size > 32 * 1024 * 1024)
        throw new Error("unsupported Desktop asset");
      const buf = Buffer.alloc(entry.size);
      fs.readSync(fd, buf, 0, buf.length, offset + Number(entry.offset));
      return buf.toString();
    }, close() { fs.closeSync(fd); }
  };
}

function exported(source, name) {
  if (!name || !/^[\w$]+$/.test(name)) return null;
  const hits = [];
  for (const match of source.matchAll(/\bexport\s*\{([^}]{0,200000})\}/g)) {
    for (const specifier of match[1].split(",")) {
      const pieces = specifier.trim().split(/\s+as\s+/);
      if (pieces[0] === name && pieces.length <= 2 && /^[\w$]+$/.test(pieces.at(-1)))
        hits.push(pieces.at(-1));
    }
  }
  return unique(hits);
}

function unique(items) {
  const values = [...new Set(items.filter(Boolean))];
  return values.length === 1 ? values[0] : null;
}

// Read-only structural check. Returned diagnostics contain boolean capability
// flags only; never send asset source or private renderer state to GitHub.
export function inspectContractAssets(archive) {
  const checks = {
    initial_asset:false, shared_asset:false, conversation_stream_hook:false,
    api_import:false, stream_scope:false, stream_method:false,
    api_export:false, stream_export:false
  };
  const initialNames = archive.files.filter(n => /^app-initial-.*\.js$/.test(n));
  const sharedNames = archive.files.filter(n => /^app-shared-.*\.js$/.test(n));
  checks.initial_asset = initialNames.length === 1;
  checks.shared_asset = sharedNames.length === 1;
  if (!checks.initial_asset || !checks.shared_asset) return {checks, contract:null};
  const initial = archive.read(initialNames[0]), shared = archive.read(sharedNames[0]);
  const apiLocal = unique([...initial.matchAll(
    /\b([\w$]+)\s*\.\s*streamPost\s*\(\s*[\x60'"]\/f\/conversation/g
  )].map(m => m[1]));
  checks.conversation_stream_hook = Boolean(apiLocal);
  const apiImport = apiLocal && unique([...initial.matchAll(
    new RegExp("([\\w$]+)\\s+as\\s+" + apiLocal.replace(/\$/g, "\\$") + "(?=[,}])", "g")
  )].map(m => m[1]));
  checks.api_import = Boolean(apiImport);
  // Unlike the original expression, this does not depend on the arbitrary
  // name of a neighboring minified function such as "brn".
  const candidateAtoms = [...initial.matchAll(
    /(?:^|[,;])([\w$]+)\s*=\s*[\w$]+\s*\(\s*\$\s*,\s*\(\s*\{\s*scope\s*:\s*([\w$]+)\s*\}\s*\)\s*=>\s*new\s+([\w$]+)\s*\(\s*\2\s*\)\s*\)/g
  )].map(m => m[1]);
  const atom = unique(candidateAtoms.filter(x => exported(initial, x)));
  checks.stream_scope = Boolean(atom);
  checks.stream_method = /\b(?:async\s+)?startCompletionStream\s*\(/.test(initial);
  const api = exported(shared, apiImport), stream = exported(initial, atom);
  checks.api_export = Boolean(api);
  checks.stream_export = Boolean(stream);
  // An upstream Desktop build can retain the identical API object while
  // changing only its import alias. Never infer the exported name from a
  // substring or choose the first match: defer that case to a unique
  // capability-checked export of this *exact* shared module in the renderer.
  checks.api_runtime_link = initial.includes(sharedNames[0]);
  const structural = ["initial_asset", "shared_asset", "conversation_stream_hook",
    "stream_scope", "stream_method", "stream_export"];
  if (structural.some(key => !checks[key])) return {checks, contract:null};
  const staticApi = checks.api_import && checks.api_export;
  if (!staticApi && !checks.api_runtime_link) return {checks, contract:null};
  return {checks, contract:{
    shared:sharedNames[0], initial:initialNames[0], api:staticApi ? api : null,
    api_resolution:staticApi ? "static_export" : "unique_runtime_export", stream,
    serverStreamStatus:initial.includes("/conversation/{conversation_id}/stream_status"),
    fingerprint:crypto.createHash("sha256").update(initial).update(shared).digest("hex")
  }};
}

export function inspectInstalledContract() {
  const archive = asarReader(process.env.HADALIS_DESKTOP_ASAR ?? "/usr/lib/chatgpt/resources/app.asar");
  try { return inspectContractAssets(archive); }
  finally { archive.close(); }
}

export function installedContract() {
  const result = inspectInstalledContract();
  if (result.contract) return result.contract;
  const failed = Object.entries(result.checks).filter(([,passed]) => !passed).map(([key]) => key);
  throw new Error("unsupported Desktop stream contract [" + failed.join(",") + "]");
}

export async function connectNative() {
  // Verify the installed bundle before allocating any CDP resources.
  // Unsupported upgrades must fail promptly, not time out during cleanup.
  const contract = installedContract();
  const url = process.env.HADALIS_CHATGPT_CDP_URL ?? "http://127.0.0.1:9222";
  const parsed = new URL(url);
  if (parsed.protocol !== "http:" || !["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname))
    throw new Error("Desktop connection must use loopback");
  const { chromium } = await import(process.env.HADALIS_PLAYWRIGHT_MODULE ??
    "file:///usr/lib/chatgpt/resources/cua_node/lib/node_modules/playwright-core/index.mjs");
  const browser = await chromium.connectOverCDP(url, { timeout: 10000 });
  const page = browser.contexts().flatMap(c => c.pages()).find(p => p.url() === "app://-/index.html");
  if (!page) { await Promise.race([browser.close().catch(() => {}),
    new Promise(resolve => setTimeout(resolve, 1500))]);
    throw new Error("Desktop main renderer unavailable"); }
  let rendererTimer;
  try {
    await Promise.race([
      page.evaluate(async contract => {
    const shared = await import(`./assets/${contract.shared}`), initial = await import(`./assets/${contract.initial}`);
    const candidates = Object.values(shared).filter(value =>
      typeof value?.safeGet === "function" && typeof value?.streamPost === "function");
    const uniqueCandidates = [...new Set(candidates)];
    // A statically verified import remains the preferred identity. A changed
    // import alias is acceptable ONLY if the exact shared module has precisely
    // one exported client exposing both methods used by the Desktop.
    const api = contract.api_resolution === "static_export"
      ? shared[contract.api] : uniqueCandidates.length === 1 ? uniqueCandidates[0] : null;
    const definition = initial[contract.stream];
    if (typeof api?.safeGet !== "function" ||
        typeof api?.streamPost !== "function" ||
        typeof definition?.resolve !== "function")
      throw new Error("Desktop capabilities unavailable");
    // Read the app-wide scope, never the selected chat/composer. This is
    // bounded and capability checked; navigation does not change identities.
    let chain;
    const todo = Array.from(document.body.children).flatMap(el => Object.keys(el)
      .filter(k => k.startsWith("__reactContainer$")).map(k => el[k]));
    const seen = new Set();
    for (let i = 0; i < 30000 && todo.length; i++) {
      const node = todo.pop();
      if (!node || seen.has(node)) continue;
      seen.add(node);
      const value = node.memoizedProps?.value;
      if (value instanceof Map && value.has(definition.scope.id)) { chain = value; break; }
      todo.push(node.child, node.sibling, node.alternate, node.current);
    }
    if (!chain) throw new Error("Desktop app scope unavailable");
    const node = chain.get(definition.scope.id);
    const transport = node.store.get(definition.resolve(node, chain));
    if (typeof transport?.prepareCompletionStream !== "function" ||
        typeof transport?.startCompletionStream !== "function") throw new Error("unsupported Desktop transport");
    window.__hadalisNative = { api, transport, fingerprint: contract.fingerprint,
      serverStreamStatus: contract.serverStreamStatus };
    window.__hadalisReceipts ??= new Map();
      }, contract),
      new Promise((_, reject) => {
        rendererTimer = setTimeout(() =>
          reject(new Error("DESKTOP_OPERATION_TIMEOUT")), 12000);
      })
    ]);
    return { page, browser, contract };
  } catch (error) {
    // A failed renderer contract must not leave an allocated CDP client.
    await Promise.race([browser.close().catch(() => {}),
      new Promise(resolve => setTimeout(resolve, 1500))]);
    throw new Error(/Timeout/i.test(String(error?.name ?? "")) ||
      error?.message === "DESKTOP_OPERATION_TIMEOUT" ?
      "DESKTOP_OPERATION_TIMEOUT" : "Desktop capabilities unavailable");
  } finally {
    clearTimeout(rendererTimer);
  }
}

async function nativeGet(page, path, parameters, projectId = null) {
  // Only projects use this header. Older/custom GPT gizmo identities keep
  // ordinary conversation reads and cannot inject arbitrary header content.
  projectId = typeof projectId === "string" && /^g-p-[0-9a-f]{32}$/i.test(projectId) ? projectId : null;
  const result = await page.evaluate(async ({path, parameters, projectId}) => {
    try {
      return {ok:true, value:await window.__hadalisNative.api.safeGet(path, {
        signal:AbortSignal.timeout(25000), parameters,
        ...(projectId ? {additionalHeaders:{"chatgpt-project-id":projectId}} : {})
      })};
    } catch (error) {
      // Playwright otherwise drops custom HTTP status fields across IPC.
      // Project only typed status/fixed classification before leaving Desktop;
      // neither the error body nor request/response headers cross this boundary.
      const status = [error?.responseStatus, error?.statusCode, error?.status]
        .find(x => Number.isInteger(x) && x >= 100 && x <= 599);
      const limited = status === 429 || /too many requests|(?:HTTP|status(?: code)?)\s*[:=]?\s*429\b/i.test(String(error?.message ?? ""));
      return {ok:false, ...(status ? {http_status:status} : {}), code:limited ? "DESKTOP_RATE_LIMITED"
        : ["TimeoutError", "AbortError"].includes(error?.name) ? "DESKTOP_OPERATION_TIMEOUT" : "DESKTOP_OPERATION_UNAVAILABLE"};
    }
  }, {path, parameters, projectId});
  if (result.ok) return result.value;
  const resource = path === "/models" ? "models" : path.endsWith("/stream_status") ? "stream_status"
    : path.startsWith("/conversation/") ? "conversation" : path.startsWith("/gizmos/") ? "projects" : "desktop";
  const error = new Error(result.code);
  Object.assign(error, operationErrorObservation({...result, message:result.code, resource}));
  throw error;
}

export async function nativeRead(page, path, query = {}, projectId = null) {
  return nativeGet(page, path, {query}, projectId);
}

export async function nativeStreamStatus(page, pending) {
  if (!UUID.test(pending.user_message_id) || !UUID.test(pending.conversation_id))
    throw new Error("invalid stream observation identity");
  return page.evaluate(pending => {
    const receipt = window.__hadalisReceipts?.get(pending.user_message_id);
    if (!receipt) return {found:false};
    if (receipt.conversation_id && receipt.conversation_id !== pending.conversation_id)
      throw new Error("stream observation identity mismatch");
    const status = {found:true};
    status.receipt_version = receipt.streamReceiptVersion === 1 ? 1 : 0;
    status.stream_user_confirmed = receipt.streamUserConfirmed === true;
    status.stream_identity_conflict = receipt.streamIdentityConflict === true;
    status.stream_final_found = !!receipt.streamFinal;
    for (const key of ["dispatched", "accepted", "streamError", "streamComplete", "resumed"])
      status[key] = receipt[key] === true;
    for (const key of ["dispatched_at_ms", "completed_at_ms"])
      if (Number.isSafeInteger(receipt[key]) && receipt[key] >= 0) status[key] = receipt[key];
    const final = receipt.streamFinal;
    if (receipt.user_message_id === pending.user_message_id && receipt.streamUserConfirmed === true &&
        !receipt.streamIdentityConflict && status.dispatched && status.accepted && status.streamComplete &&
        !status.streamError && typeof final?.message_id === "string" && /^[0-9a-f-]{36}$/i.test(final.message_id) &&
        typeof final.text === "string" && new TextEncoder().encode(final.text).length <= 96000)
      status.response = {message_id:final.message_id, text:final.text};
    return status;
  }, pending);
}

export async function nativeServerStreamStatus(page, conversationId) {
  if (!UUID.test(conversationId)) throw new Error("invalid server stream identity");
  if (!await page.evaluate(() => window.__hadalisNative.serverStreamStatus)) return "UNAVAILABLE";
  try {
    const value = await nativeGet(page, "/conversation/{conversation_id}/stream_status", {path:{conversation_id:conversationId}});
    return ["IS_STREAMING", "COMPLETE", "FAILURE", "UNAVAILABLE"].includes(value?.status) ? value.status : "UNAVAILABLE";
  } catch (error) {
    if (error.http_status === 404) return "UNAVAILABLE";
    throw error;
  }
}

export async function nativeModelCatalog(page) {
  const data = await nativeRead(page, "/models", {iim:false, include_icons:false});
  // Read-only troubleshooting projection. No account fields, response body,
  // descriptions or credentials are exported by this operation.
  const slug = value => typeof value === "string" && /^[a-zA-Z0-9._:-]{1,128}$/.test(value) ? value : null;
  return {default_model_slug:slug(data?.default_model_slug),
    categories:(Array.isArray(data?.categories) ? data.categories : []).slice(0,128).filter(Boolean).map(c => ({
      keys:Object.keys(c).filter(k => /^[a-z_]{1,64}$/.test(k)).slice(0,32),
      model_lane:["instant","thinking","pro"].includes(c.model_lane) ? c.model_lane : null,
      model_version:parseModelVersion(c.model_version), is_soft_deprecated:c.is_soft_deprecated === true,
      default_model:slug(c.default_model), supported_models:(Array.isArray(c.supported_models) ? c.supported_models : []).slice(0,128).map(slug).filter(Boolean),
      disabled_by_admin:c.disabled_by_admin === true})),
    models:(Array.isArray(data?.models) ? data.models : []).slice(0,128).filter(m => slug(m?.slug)).map(m => ({
      slug:m.slug, keys:Object.keys(m).filter(k => /^[a-z_]{1,64}$/.test(k)).slice(0,48),
      configurable_thinking_effort:m.configurable_thinking_effort === true,
      thinking_efforts:(Array.isArray(m.thinking_efforts) ? m.thinking_efforts : []).slice(0,16)
        .map(e => e?.thinking_effort).filter(e => ["min","standard","extended","xhigh","max"].includes(e)),
      disabled_by_admin:m.disabled_by_admin === true, is_work_mode_model:m.is_work_mode_model === true,
      hidden:Array.isArray(m.tags) && m.tags.includes("hidden")}))};
}

export async function nativeStreamReceipt(page, pending) {
  const local = await nativeStreamStatus(page, pending);
  return local.response ? {completed:true, submitted:true, history_checked:false,
    response_source:"managed_stream", conversation_id:pending.conversation_id, response:local.response}
    : {completed:false, history_checked:false};
}

export async function pollNativeTurn(page, pending) {
  const path = `/conversation/${pending.conversation_id}`;
  const local = await nativeStreamStatus(page, pending);
  if (local.response) return {completed:true, submitted:true, history_checked:false,
    response_source:"managed_stream", response:local.response};
  const now = Date.now()/1000;
  const verifiedAt = pending.history_verified_at_unix, historyAfter = pending.history_poll_after_unix;
  // A recent exact-turn history permits a cheap status read between audits.
  // Missing Desktop receipts, uncertain submissions, clock changes and stale
  // or malformed schedules always require history. A status-only read cannot
  // authorize final consumption, terminal recovery or stream reattachment.
  const recent = pending.phase === "acknowledged" && local.found && !local.streamComplete &&
    Number.isSafeInteger(verifiedAt) && Number.isSafeInteger(historyAfter) &&
    verifiedAt <= now && now < historyAfter && historyAfter <= verifiedAt + 300;
  let earlyStatus;
  if (recent) {
    earlyStatus = await nativeServerStreamStatus(page, pending.conversation_id);
    if (earlyStatus === "IS_STREAMING") return {completed:false, submitted:true, terminal_failed:false,
      history_checked:false, client_stream_found:true, client_stream_error:local.streamError === true,
      client_stream_complete:false, server_stream_status:earlyStatus};
  }
  const conversation = await nativeRead(page, path, {}, pending.project_id);
  const result = {...projectTurn(conversation, pending), history_checked:true};
  if (result.completed || !result.submitted || result.superseded || result.terminal_failed) return result;
  // A disconnected client is observation evidence, never proof that server
  // generation failed. Preserve it even when the server has no final message.
  const observed = {...result, client_stream_found:local.found === true, client_stream_error:local.streamError === true,
    client_stream_complete:local.streamComplete === true};
  const aged = Number.isFinite(pending.prepared_at_unix) &&
    Date.now()/1000 - pending.prepared_at_unix >= 300;
  if (!local.streamError && !local.streamComplete && !result.streamError && !aged) return observed;
  // FAILURE must still be bracketed by two histories; a pre-read status cannot
  // fail a different user turn that arrived between these observations.
  const status = earlyStatus && earlyStatus !== "FAILURE" ? earlyStatus
    : await nativeServerStreamStatus(page, pending.conversation_id);
  if (status !== "FAILURE") return {...observed, server_stream_status:status};
  // Status is conversation-scoped. Bracket it with exact-turn reads so a later
  // human submission or a persisted final response cannot fail the wrong turn.
  const latest = await nativeRead(page, path, {}, pending.project_id);
  const verified = {...projectTurn(latest, pending), history_checked:true};
  if (verified.completed || verified.superseded || !verified.submitted) return verified;
  if (latest.current_node !== conversation.current_node) return verified;
  return {...verified, terminal_failed:true, server_stream_status:status,
    terminal_failure_source:"conversation_stream_status"};
}

export async function resolveProject(page, name) {
  let cursor;
  const matches = [];
  for (let pageNo = 0; pageNo < 5; pageNo++) {
    const data = await nativeRead(page, "/gizmos/snorlax/sidebar", {
      limit: 40, conversations_per_gizmo: 0, owned_only: true, ...(cursor ? {cursor} : {})
    });
    for (const item of data.items ?? []) {
      const gizmo = item.gizmo?.gizmo;
      if (gizmo?.display?.name === name) matches.push(gizmo.id);
    }
    cursor = data.cursor;
    if (!cursor) break;
  }
  if (new Set(matches).size !== 1) throw new Error("project name unavailable or ambiguous; bind an exact project ID");
  return matches[0];
}

const THINKING_EFFORTS = new Set(["auto", "instant", "min", "standard", "extended", "xhigh", "max"]);

function thinkingEffort(input) {
  const effort = input.thinking_effort ?? "auto";
  if (!THINKING_EFFORTS.has(effort)) throw new Error("THINKING_EFFORT_UNAVAILABLE");
  return effort;
}

function parseModelVersion(value) {
  const text = typeof value === "number" && Number.isFinite(value) ? String(value) : value;
  if (typeof text !== "string") return null;
  const match = text.match(/^(?:gpt-)?(\d+)(?:[.-](\d+))?(?:[.-](\d+))?$/i);
  if (!match) return null;
  const version = match.slice(1).map(x => x == null ? 0 : Number(x));
  return version.every(x => Number.isSafeInteger(x) && x <= 1000000) ? version : null;
}

function compareModelVersion(a, b) {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] - b[i];
  return 0;
}

export function selectThinkingModel(metadata, effort, preferredModel = "auto") {
  thinkingEffort({thinking_effort:effort});
  if (effort === "auto") return {model:preferredModel};
  const categories = Array.isArray(metadata?.categories) ? metadata.categories.slice(0, 128).filter(Boolean) : [];
  const enabled = categories.filter(c => c.disabled_by_admin !== true);
  const allModels = (Array.isArray(metadata?.models) ? metadata.models : []).slice(0, 128).filter(m =>
    typeof m?.slug === "string" && /^[a-zA-Z0-9._:-]{1,128}$/.test(m.slug) &&
    m.is_work_mode_model !== true && m.disabled_by_admin !== true && !(Array.isArray(m.tags) && m.tags.includes("hidden")) &&
    (!categories.length || enabled.some(c => c.default_model === m.slug || (Array.isArray(c.supported_models) && c.supported_models.includes(m.slug)))));
  const lane = enabled.filter(c => effort === "instant" ? c.model_lane === "instant"
    : ["thinking", "pro"].includes(c.model_lane));
  let candidates = lane.flatMap(c => {
    const model = allModels.find(m => m.slug === c.default_model);
    if (!model) return [];
    const fromSlug = model.slug.match(/^(gpt-\d+(?:[.-]\d+){0,2})(?=$|[-:])/i)?.[1];
    return [{model, version:parseModelVersion(c.model_version) ?? parseModelVersion(fromSlug),
      pro:c.model_lane === "pro", deprecated:c.is_soft_deprecated === true}];
  });
  // Metadata supplies the enabled lane defaults, not a performance ordering.
  // Compare declared versions numerically; never pin an older conversation's
  // model or interpret array order as "highest". Unknown/tied rankings fail
  // closed, and unsupported effort cannot silently downgrade the model.
  if (!categories.length && allModels.length === 1 && effort !== "instant")
    candidates = [{model:allModels[0], version:null, pro:false, deprecated:false}];
  if (candidates.some(c => !c.deprecated)) candidates = candidates.filter(c => !c.deprecated);
  const distinct = new Set(candidates.map(c => c.model.slug));
  if (!candidates.length || (distinct.size > 1 && candidates.some(c => !c.version)))
    throw new Error("THINKING_EFFORT_UNAVAILABLE");
  candidates.sort((a,b) => a.version && b.version ? compareModelVersion(b.version,a.version) || Number(b.pro)-Number(a.pro) : 0);
  const best = candidates[0];
  const ties = candidates.filter(c => (!best.version || !c.version || compareModelVersion(c.version,best.version) === 0) && c.pro === best.pro);
  if (new Set(ties.map(c => c.model.slug)).size > 1) throw new Error("THINKING_EFFORT_UNAVAILABLE");
  const model = best.model;
  if (effort !== "instant" && (model.configurable_thinking_effort !== true || !Array.isArray(model.thinking_efforts) ||
      !model.thinking_efforts.some(e => e?.thinking_effort === effort))) throw new Error("THINKING_EFFORT_UNAVAILABLE");
  return {model:model.slug, thinking_effort:effort};
}

export async function nativePreflight(page, input) {
  const effort = thinkingEffort(input);
  if (input.requires_github) await page.evaluate(() => {
    const plugins = window.__hadalisNative.transport.scope.queryClient.getQueryCache().getAll()
      .filter(q => q.queryKey[0] === "plugins" && Array.isArray(q.state.data)).flatMap(q => q.state.data)
      .map(x => x.plugin).filter(p => p?.id === "github@openai-curated-remote" && p.installed && p.enabled && p.remotePluginId);
    if (new Set(plugins.map(p => p.remotePluginId)).size !== 1) throw new Error("GitHub plugin capability unavailable");
  });
  if (effort === "auto") return {ready:true};
  const metadata = await nativeRead(page, "/models", {iim:false, include_icons:false});
  return {ready:true, ...selectThinkingModel(metadata, effort, input.model || "auto")};
}

export async function nativeSubmit(page, input) {
  if (!UUID.test(input.user_message_id) || !UUID.test(input.parent_message_id)) throw new Error("invalid submission identity");
  if (input.conversation_id && !UUID.test(input.conversation_id)) throw new Error("invalid conversation identity");
  const effort = thinkingEffort(input);
  if (effort === "instant" && (typeof input.model !== "string" || input.model === "auto" ||
      !/^[a-zA-Z0-9._:-]{1,128}$/.test(input.model))) throw new Error("THINKING_EFFORT_UNAVAILABLE");
  return page.evaluate(async input => {
    const {api, transport} = window.__hadalisNative, receipts = window.__hadalisReceipts;
    if (receipts.has(input.user_message_id)) return receipts.get(input.user_message_id);
    // No UI mutation, no account credential exposure, no transport resend.
    const hints = [];
    if (input.requires_github) {
      let plugins = transport.scope.queryClient.getQueryCache().getAll()
        .filter(q => q.queryKey[0] === "plugins" && Array.isArray(q.state.data))
        .flatMap(q => q.state.data).map(x => x.plugin).filter(Boolean)
        .filter(x => x.id === "github@openai-curated-remote" && x.installed && x.enabled);
      const ids = [...new Set(plugins.map(p => p.remotePluginId).filter(Boolean))];
      if (ids.length !== 1) throw new Error("GitHub plugin capability unavailable");
      hints.push(`plugin:${ids[0]}`);
    }
    const request = { action: "next", model: input.model || "auto",
      ...(["auto", "instant"].includes(input.thinking_effort) ? {} : {thinking_effort:input.thinking_effort}),
      parent_message_id: input.parent_message_id, messages: [{ id: input.user_message_id,
        author: {role: "user"}, content: {content_type: "text", parts: [input.prompt]},
        metadata: {system_hints: hints} }], system_hints: hints,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      timezone_offset_min: new Date().getTimezoneOffset(),
      ...(input.project_id ? {gizmo_id: input.project_id,
        conversation_mode: {kind: "gizmo_interaction", gizmo_id: input.project_id}} : {}),
      ...(input.conversation_id ? {conversation_id: input.conversation_id} : {}) };
    const prepared = await transport.prepareCompletionStream(request, {signal: AbortSignal.timeout(20000)});
    // Receipt insertion is the last local point before the possible send.
    // Python has already committed dispatch intent, so failure stays uncertain.
    const receipt = { user_message_id: input.user_message_id, conversation_id: input.conversation_id, streamReceiptVersion:1,
      dispatched: false, streamError: false };
    for (const [id, prior] of receipts) {
      if (receipts.size < 32) break;
      if (prior.streamComplete || (prior.streamError && !prior.dispatched)) receipts.delete(id);
    }
    if (receipts.size >= 64) throw new Error("managed stream limit reached");
    receipts.set(input.user_message_id, receipt);
    const inspect = value => {
      if (!value || typeof value !== "object") return;
      const id = value.conversation_id ?? value.conversationId ?? value.conversation?.conversation_id;
      if (typeof id === "string" && /^[0-9a-f-]{36}$/i.test(id)) {
        if (receipt.conversation_id && receipt.conversation_id !== id) receipt.streamIdentityConflict = true;
        else receipt.conversation_id = id;
      }
      // Installed Desktop decodes updates as {type:"message", conversationId,
      // message}. Capture only a final reply after the exact user echo, never
      // reasoning/tool output. Missing echoes or conflicting users fall back
      // to history; stream close/error alone cannot manufacture a final reply.
      if (value.type !== "message" || id !== receipt.conversation_id) return;
      const message = value.message;
      if (message?.author?.role === "user") {
        if (message.id === input.user_message_id) receipt.streamUserConfirmed = true;
        else receipt.streamIdentityConflict = true;
      }
      if (receipt.streamUserConfirmed && !receipt.streamIdentityConflict &&
          message?.author?.role === "assistant" && message.recipient === "all" &&
          (message.channel == null || message.channel === "final") &&
          message.status === "finished_successfully" && message.end_turn === true &&
          typeof message.id === "string" && /^[0-9a-f-]{36}$/i.test(message.id) &&
          Array.isArray(message.content?.parts) && message.content.parts.every(p => typeof p === "string")) {
        const text = message.content.parts.join("\n");
        if (new TextEncoder().encode(text).length <= 96000)
          receipt.streamFinal = {message_id:message.id, text};
      }
    };
    try {
      await transport.startCompletionStream({request, prepared: Promise.resolve(prepared),
        startupSignal: AbortSignal.timeout(25000),
        onRequestStart: () => { receipt.dispatched = true; receipt.dispatched_at_ms = Date.now(); },
        onResponse: () => { receipt.accepted = true; },
        onUpdate: inspect,
        onEvent: event => { try { inspect(typeof event.data === "string" ? JSON.parse(event.data) : event.data); } catch {} },
        onError: () => { receipt.streamError = true; },
        onComplete: () => { receipt.streamComplete = true; receipt.completed_at_ms = Date.now(); }
      });
      const deadline = Date.now() + 10000;
      while (!receipt.conversation_id && !receipt.streamError && Date.now() < deadline)
        await new Promise(resolve => setTimeout(resolve, 100));
      return receipt;
    } catch (error) {
      receipt.streamError = true;
      receipt.errorName = error.name;
      // Kept only in Desktop memory for local diagnosis, never returned in
      // the publication protocol or stored alongside profile configuration.
      receipt.localError = String(error.message).slice(0, 1000);
      throw new Error("Desktop submission outcome uncertain; reconcile message identity");
    }
  }, {...input, thinking_effort:effort});
}

export async function discoverSubmission(page, pending) {
  const receipt = await page.evaluate(id => {
    const r = window.__hadalisReceipts?.get(id);
    return r ? {conversation_id: r.conversation_id, streamError: r.streamError} : null;
  }, pending.user_message_id);
  if (receipt?.conversation_id) return receipt;
  const list = await nativeRead(page, pending.project_id
    ? `/gizmos/${pending.project_id}/conversations` : "/conversations", {limit: 40, owned_only: true, order: "updated"});
  // Limit history scans per reconciliation; no guessing by title or UI.
  const recent = (list.items ?? []).filter(c => Number(c.create_time) >= pending.prepared_at_unix - 120).slice(0, 12);
  for (const item of recent) {
    const conversation = await nativeRead(page, `/conversation/${item.id}`, {}, pending.project_id);
    if (Object.values(conversation.mapping ?? {}).some(n => n.message?.id === pending.user_message_id || n.id === pending.user_message_id))
      return {conversation_id: item.id};
  }
  return {conversation_id: null};
}

export async function nativeResume(page, pending) {
  if (!UUID.test(pending.conversation_id)) throw new Error("invalid resume identity");
  // Read-only reattachment to the server stream. No new user message, variant
  // generation, prompt replay or credential persistence is permitted here.
  return page.evaluate(async pending => {
    const {transport} = window.__hadalisNative;
    if (typeof transport.resumeCompletionStream !== "function") throw new Error("Desktop resume capability unavailable");
    const receipt = window.__hadalisReceipts.get(pending.user_message_id) ?? {
      conversation_id:pending.conversation_id, user_message_id:pending.user_message_id};
    window.__hadalisReceipts.set(pending.user_message_id,receipt);
    await transport.resumeCompletionStream({request:{conversation_id:pending.conversation_id,offset:0},
      onResponse:()=>{receipt.resumed=true;},onUpdate:()=>{},onDecodedPayload:()=>{},
      onError:()=>{receipt.streamError=true;},onTransportClose:()=>{},
      onComplete:()=>{receipt.streamComplete=true;receipt.completed_at_ms=Date.now();}});
    return {reattached:true};
  }, pending);
}
