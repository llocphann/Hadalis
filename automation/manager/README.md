# Hadalis Automation control

Settings is a frontend to the installed `~/.local/share/hadalis-automation/control.py` JSON endpoint. The installer also delegates old repo-copy control scripts to that backend before they can overwrite migrated state. Configuration stays at `$XDG_CONFIG_HOME/hadalis/automation.json`; durable runtime, recovery copies and bounded events stay privately under `$XDG_STATE_HOME/hadalis-automation`. Migration preserves existing profiles, prompts, continuous-loop semantics and uncertain submissions. Config/state transactions recover atomically after an interrupted write.

The scheduler independently manages each profile's project, conversation, user-message ID, final-response receipt and checkpoint. It uses bounded concurrency (default 4, maximum 8) and fair admission. Waiting for a response/job holds no global owner or queue. Only equal conversation IDs and truly shared resources serialize. Navigation, opening another project and normal Desktop use do not change monitoring. Editing the managed chat itself pauses continuation to preserve its history.

Each profile has a discrete Chat slider (Instant / Medium / High), initially
High. Medium maps to `standard`, High to `extended`, and Instant selects the
highest enabled Instant Chat model without a thinking-effort override.
Set default stores `default_thinking_effort` for new profiles; existing explicit
choices and duplicated profiles keep their own level. Missing/legacy Auto
preferences resolve to that default for future turns. Legacy pending Auto
requests retain their exact intent and continue without an override.
Levels are checked against the account's Chat model metadata before dispatch.
Every new turn, including continuation, selects the highest enabled account
model in the requested Chat lane. Declared model versions are compared
numerically; legacy category ordering and the old chat's default cannot pin an
older model. Work/hidden/admin-disabled models are excluded. Unknown or tied
rankings and unsupported effort fail before dispatch rather than downgrading.
Unsupported choices fail before submission instead of silently falling back.
The resolved model and effort are captured in durable dispatch intent. Editing
the slider or default affects future turns/profiles and cannot replay or change
a pending turn. Older advanced native effort values remain supported in config.

Submission intent is durable before dispatch. Lost acknowledgements reconcile the exact message ID and never resend. An unidentified legacy pending chat remains quarantined while other profiles progress. Completed responses are persisted before counters or continuation. Desktop/network downtime backs off observation, bounded to 300 seconds, without permanently disabling it. Up to three read-only stream reattachments resume existing server streams without a new message. A server-confirmed terminal generation failure archives its receipt and permits a distinct checkpoint/evidence recovery step, bounded to three automatic recoveries. Ambiguous generation/action outcomes are never replayed. Invalid final directives or unsupported diagnosis evidence retain the completed receipt and pause only that profile.

Generic objectives can research, analyze, code through GitHub, dispatch pinned local tests/diagnostics, inspect results, debug, fix and continue. WAIT_RESULT has profile ownership and can use a private local worker receipt while Git publication is down. Continuation receives only allowlisted observations, error codes and provenance; raw machine data stays local. Optional HADALIS_CHECKPOINT preserves phase, summary, next step and evidence IDs. HADALIS_DIAGNOSIS conclusions must cite observed worker evidence IDs. ChatGPT remains the reasoning agent; the backend and worker make deterministic protocol transitions only.
Custom workflows follow the repository and branch in their objective. Normal
GitHub findings use ordinary source citations; the machine-debug envelope is
reserved for observed local worker evidence. Rejected completed responses stay
private with a specific directive/checkpoint/diagnosis reason. A resumed turn
receives correction context without replaying the consumed response or jobs.
Monitor recovery can guard the inspected status, command sequence and response
identity atomically so a newer owner Stop/Pause wins.
An immutable result owned by another profile rejects WAIT_RESULT as a protocol
conflict instead of retrying it as a transport outage. The referenced job and
final response remain private evidence; neither its result nor evidence IDs are
adopted. An automatic pause can resume through the guarded correction path,
while a newer owner Pause/Stop remains authoritative.

Conversation reads use a 30-second cadence (configurable within 15–120 seconds),
doubling for turns older than five minutes up to 120 seconds. The scheduler's
two-second control heartbeat does not issue network requests on every tick.
Due profile reads reserve separate account API slots, initially ten seconds
apart (configurable within 1–30 seconds). Generations and local jobs remain
parallel; a read reservation never owns a profile or queues its worker.
An explicit ChatGPT rate limit starts an account-wide 120-second cooldown
(initial delay configurable within 60–300 seconds). Repeated retry rounds
double the delay up to thirty minutes, persisted across service restarts and
profile replacement. Failures already in flight share one retry round; one
successful read cannot erase a run of limits. A quiet interval of at least ten
minutes and twice the current delay permits a successful read to reset backoff.
Local job results,
fsynced response receipts and user controls continue during cooldown; only the
shared ChatGPT API resource waits. Pending prompt identities never change.
HTTP status and the affected resource (conversation history, stream status,
models or projects) are projected inside Desktop before IPC can discard typed
error fields. Fixed private observations distinguish transport throttling from
a model generation quota; a 429 on a history read does not prove a five-hour
model limit. Timeout details contain no raw command, body, headers or secrets.
The read-only native `model_catalog` operation exports bounded model capability
metadata for diagnosis and never exports account fields or descriptions.

Failed execution receipts classify bounded private compiler/runtime output into
fixed QML/import, compilation, test, missing-command and lockfile error codes for
the managed chat, with the original evidence ID and source SHA. Raw text and
private paths never enter that projection or Git results. Read-only diagnostics
include `inir.service`, the actual installed shell unit, alongside compatibility
unit names. A successful new dispatch or job observation clears stale error
indicators and starts the next turn with its own observation retry budget.

Responses and completed jobs share one transition function. WAIT_RESULT first
captures its result/provenance, then applies rotation, prompt/iteration/duration
limits and interval scheduling. Job waits cannot bypass those boundaries or
discard the checkpoint when rotating a long workflow.

Start, Pause, Resume, Stop and Restart affect one profile. Pending replies remain observable after Stop. Restart is consumed once in its durable submission intent, including a lost acknowledgement; a later Restart keeps its own command sequence. It reconciles a pending reply and requests cancellation of a discovered/local job, then retains WAIT_RESULT until the final worker receipt and evidence are captured before creating the fresh chat. Legacy acknowledged restart intents are consumed only when their command event predates the new-chat dispatch. Cancel local job persists a cancellation request; action receipts prevent execution replay. Confirmed Remove archives local recovery metadata and removes only the profile, retaining ChatGPT history. Archive/delete preferences remain pending semantic Desktop support and do not perform chat cleanup.

Backend, worker and the allowlisted privilege broker start under the user default target and have no lifecycle dependency on Quickshell or Desktop. Their systemd units bound process counts, memory and shutdown. Desktop is optional transport; its startup failure does not kill diagnostics/job publication/recovery. Privileged requests have fixed command/service allowlists, reasons and a durable local audit. Authenticate with an OS Polkit agent or sudo cache; Automation has no password field or persistent credential protocol. Risky shell changes require pinned canonical validation, staging and an independent rollback journal/watchdog. See automation/worker/README.md.

Install from the full Git source with `python3 scripts/install-hadalis-automation.py --enable-now`. Restart updated Python services explicitly; they do not reload source automatically. The installer does not synchronize the whole Quickshell deployment. The reset option refuses unresolved submissions/jobs. Status is read-only and shows scheduler and worker-pool health. Bounded diagnostics/export remains private; inspect logs before sharing. Regression tests use isolated config/state and fake transport. `HADALIS_TEST_NATIVE_LIVE=1 python3 scripts/test-hadalis-native-live.py` performs opt-in real Desktop concurrency/restart acceptance with harmless objectives and private evidence.

### GitHub token

Settings accepts an optional per-profile token for local Git operations. It is
stored by `secret-tool` in the system Secret Service keyring, without a plaintext
fallback. Install `libsecret` if that tool is missing and unlock the user keyring.
Input uses private stdin; Git receives it only through a repository-scoped
credential helper pipe. Configuration, state, Activity, prompts and results
contain no token. Duplication does not copy credentials. Clear removes the
keyring entry. ChatGPT's GitHub connector keeps its own authentication.
