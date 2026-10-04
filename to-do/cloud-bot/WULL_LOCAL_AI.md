# Wull Local AI / Desktop Agent — Canonical TODO

> **Single source of truth for Wull local-AI work.** All future planning, status updates, architecture/model/runtime decisions, benchmark summaries, fine-tuning/distillation notes, rollout state, and acceptance evidence for this effort MUST be edited into this file only. Do not create another Wull-AI TODO/task-board/handoff document.
>
> Repository: `llocphann/Hadalis`  
> Working branch: `dev` only; never mutate `stable`.  
> Last pre-write repository audit HEAD: `5653fa24fb8c9e948afc3337826581da190e6325`.
>
> This file is the only **planning/status** document for Wull AI. Normal implementation source, tests, fixtures and generated benchmark outputs may exist elsewhere in the repository as needed; they must not become competing planning documents.
>
> The existing Wull visual/animation plan remains separate product work. AI must consume/publish semantic state without duplicating or replacing the deterministic visual engine.

## 0. Current decision snapshot

**Current phase:** P0.5 — verified downloaded artifacts + integrated text-only local baseline; P1 agent/vision benchmark remains open
**Runtime target:** `llama.cpp`; start with process-isolated CLI/server APIs, consider direct `libllama` only after the process boundary is proven  
**Reflex model target:** `unsloth/LFM2.5-VL-3B-GGUF` — `UD-Q6_K_XL`  
**Reflex vision projector target:** `mmproj-F16.gguf` or the exact compatible projector shipped for that model revision  
**Brain model target:** `unsloth/Qwen3.5-4B-MTP-GGUF` — `UD-Q4_K_XL`  
**Specialist model:** none; Rust/Python/Hadalis specialization comes from tools + RAG first  
**Fine-tuning:** not started and intentionally blocked until the baseline benchmark exists  
**Distillation:** not started and intentionally blocked until benchmark + validators are mature  
**Production model files:** never committed to Git

Maintainer status reported on 2026-10-04:

- [x] LFM2.5-VL-3B family downloaded from Unsloth.
- [x] Qwen3.5-4B family downloaded from Unsloth.
- [x] Verify actual downloaded GGUF filenames/quantizations: LFM `UD-Q6_K_XL`, Qwen `UD-Q5_K_XL` (different from the planned Q4/MTP target).
- [x] Record SHA-256 for both models and both present projectors in generated artifact evidence; this does not qualify a P1 benchmark.
- [x] Verify the same-revision LFM `mmproj-F16.gguf` is present. Vision loading/correctness remains unqualified.
- [x] Pin the text-smoke runtime: Unsloth llama.cpp `0.5.0-dev`, build `11160`, commit `a3c12db9d`, Clang 23.0.0. P1 numbers do not exist yet.

Expected deployment intent, subject to measurement:

```text
Always-on / warm path
LFM2.5-VL-3B UD-Q6_K_XL
  -> screen perception / OCR / grounding / compact visual state
  -> no continuous inference while idle

On-demand reasoning path
Qwen3.5-4B-MTP UD-Q4_K_XL
  -> reasoning / planning / EN+VN / Rust+Python / tool planning
  -> wake only when routing requires it
  -> unload or sleep after measured idle TTL
```

Do not assume the size shown by a download UI is equal to resident RAM. Measure model mapping, KV cache, projector, runtime allocations and GPU offload separately.

### 0.1 Integrated text baseline — 2026-10-04

The maintainer explicitly resumed local conversation and permitted a better implementation than the initial plan. Runtime feature `fa84b0e20db145c5f302a358f9a8fed8281467b6` integrates bounded downloaded-GGUF discovery, the existing AI model catalog, Companion selection and one supervised local request. Current installed/test source is `8b2a0067ed1612770121d8896f46aa5b6db2216d`; its later changes are visual 3D motion plus focused test repairs. This is a **text-only P0.5 baseline**, not the full Rust agent/router/vision/tool implementation.

`LocalModels` shares one finite inventory with AI settings and Wull: Hugging Face snapshots, Unsloth exports/library, Models, Downloads and the local shell-model directory. It validates GGUF headers, deduplicates resolved artifacts and excludes projectors/vocabulary from chat choices. Startup/manual Refresh scans neither download nor load models. Both installed models are now discovered; Wull selects a downloaded model only when AI is enabled and its model preference is empty, preserving an existing selection. The maintainer's current LFM selection remains unchanged.

The chosen early process boundary is an external Python supervisor (`scripts/wull/gguf_runtime.py`), reached by narrow JSON requests from QML. It owns a private Unix socket and cross-client model lock, one slot, CPU at most four threads, context 2,048 and output at most 180 tokens. Deadlines, cancellation, parent-death signaling and bounded TERM/KILL/reap cleanup prevent a resident orphan. There is no TCP listener, cloud fallback, model download, web UI or model execution in `inir-companiond`. General AI chat and Wull share this same supervisor/lock. The optional Ollama loopback adapter remains compatible, but downloaded GGUF execution requires no Ollama dependency. See the official [llama.cpp server contract](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md). A native Rust agent manager remains future P1 work, not something supplied by this baseline.

Verified artifacts, with stable metadata before/after hashing:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| LFM2.5-VL-3B-UD-Q6_K_XL.gguf | 2,403,953,024 | `f3ae8a9b2565d829396cd84b6d7bc62541aeee9b17d0e1796feb5bd0e64efe1a` |
| LFM mmproj-F16.gguf | 853,994,080 | `234ce26278f7dbc2339e55614a28cf787424aae205711e5a143ce7ee5e1e0654` |
| Qwen3.5-4B-UD-Q5_K_XL.gguf | 3,304,827,200 | `d76bf69a16f1d59f8d6c74a7373c41e43e14dc7ab47901cc2504c7ad647c6ba6` |
| Qwen mmproj-F16.gguf | 672,423,488 | `d63b1a847fe9cd52e8e1525008cd33703821299f5a9eae40b2865426208767e7` |

LFM snapshot revision is `22f063714556bd4daa81c40dc1ff15ca37ae92ea`; Qwen snapshot revision is `86835bf9949e4d14d6860f7910b1340ad4f271a9`. [Generated artifact receipt](../../docs/evidence/wull-ai/artifacts-20261004.json) records actual GGUF version/header counts and identities, without committing binaries or private paths. Qwen became discoverable during this run after the earlier inventory contained only LFM. This downloaded Q5 artifact supersedes the assumption that the planned Q4/MTP artifact was already verified. No MTP path or projector is enabled by the text baseline.

Two generic installed-source integration requests used no Obsidian data. [LFM smoke](../../docs/evidence/wull-ai/lfm-smoke-20261004.json) returned a cute English JSON reply in 9.886 s, with child maximum RSS 2,842,724 KiB; [Qwen smoke](../../docs/evidence/wull-ai/qwen-smoke-20261004.json) returned a cute English JSON reply in 23.090 s. Both processes were reaped and all request sockets removed. These are **one request per model**, on CPU during other validation work, not throughput/latency/residency/resource-saving or ten-run P1 benchmarks. Runtime version and installed-helper digests are pinned in each receipt.

The speech UI now has one Mood question/choice row followed by one Energy question/choice row, no automatic prompt input or extra action buttons. `Super + Alt + Comma` opens explicit chat and focuses its input; Enter sends and Escape cancels/dismisses. The explicit choice helper writes only the selected scalar into **today's existing Todo-resolved journal**, checks the date and field whitelist, preserves BOM/CRLF/mode and unrelated bytes, replaces only against unchanged source bytes and verifies readback. The UI advances only after successful persistence; missing/malformed/conflicting notes produce an error rather than a fabricated success. User choices authorize these writes. Tests use owned journals; no mood/energy was invented or written into the maintainer's actual journal during validation. Actual read-only context resolves the configured daily journal successfully.

Occasional idle check-ins/reminders use the maintainer's requested policy. Funny built-in English lines remain available offline, with occasional bounded local generation when configured. Timed journal Day Planner/Agenda/Schedule/Tasks entries, current-date unchecked Todo tasks, recurring weekday schedules and existing calendar events feed deduplicated due reminders; calisthenics/cardio receive specific playful wording. Only date/mood/energy/timed semantic rows reach optional local conversation. Other journal/reflection text is excluded. Vault contents are untrusted data, never instructions. Deterministic choices/reminders run independently of the visual reflex engine and do not enable arbitrary tools or vault writes from generated text.

Focused validation passes for actual owned Qt choice clicks + helper-written journal/readback, separate questions/no check-in input, explicit keyboard focus/Enter/Escape, stale/cancel drain, model catalog/selection/shared Unix supervisor, discovery, bounded arguments, invalid inputs and cancel/reap. The preceding canonical run on `fa84b0e20db145c5f302a358f9a8fed8281467b6` was **FAIL: 414 PASS / three FAIL / eleven SKIP**: two stale explicit-focus expectations and a presence fixture that ignored the new minimum visit duration. Those fixtures were corrected forward in `1bead8100`; production behavior was retained. Final canonical validation is **PASS on exactly installed source `8b2a0067ed1612770121d8896f46aa5b6db2216d`: 418 PASS / zero FAIL / eleven SKIP**, including all 89 Wull Python checks, Qt 6.11.2 parser and a clean validator source tree. [Exact-source receipt](../../docs/wull-visual/spatial-20261004/validation.json) records that result; the later evidence/documentation commit is not relabeled as the tested SHA. [Live integration receipt](../../docs/evidence/wull-ai/live-readback-20261004.json) records two discovered models, the preserved selection and read-only journal resolution, without note contents/event titles/user configuration.

P1 remains open: repeatable cold/warm/offload/resource measurements, compatible projector loading + visual/OCR/grounding correctness, planned Qwen MTP qualification, native Rust agent supervision/router, typed tools and permission decisions, RAG, multi-step EN/VN/coding quality and multi-output/lifecycle acceptance. Fine-tuning and distillation remain blocked on those benchmarks. No full desktop agent, vision support, automatic model residency, measured optimization or product-wide AI acceptance is claimed.

---

## 1. Product objective

Build Wull as a local desktop companion/agent that can:

- converse naturally in English and Vietnamese;
- perceive visible desktop state when vision is actually required;
- choose deterministic typed tools instead of guessing shell commands;
- perform authorized desktop/file/system actions;
- reason across Rust, Python, Quickshell/QML and the Hadalis codebase;
- explain and recover from tool/runtime failures;
- remain useful offline;
- preserve Quickshell responsiveness even when inference is slow, crashes or runs out of memory;
- scale to future 2B–4B models without rewriting Wull's tool layer.

Wull does **not** need a large model for every interaction. The architecture must minimize model use:

```text
structured system state available?
  yes -> deterministic tool/API
  no
  |
  +-- visual perception needed? -> Reflex
  |
  +-- multi-step reasoning/code/ambiguity? -> Brain
```

A correct tool result beats an LLM guess. A small model with precise context beats a larger model fed an entire repository.

---

## 2. Repository integration boundary

The repository already has two important boundaries that must remain distinct:

- `native/inir-companiond` is a deterministic semantic Wull presence/animation engine. It currently consumes bounded JSON-line events/intents/preferences and emits visual state. **Do not put LLM inference, RAG or arbitrary tool execution into this daemon during the first implementation.**
- `services/Ai.qml` already owns multi-provider chat/conversation UI behavior. It may expose a local-Wull provider/bridge later, but **QML must not own model process lifetime, permission enforcement or unsafe system actions.**

Preferred new production boundary after P0/P1 succeeds:

```text
Quickshell / services/Ai.qml / Wull UI
                  |
             narrow IPC
                  v
       native/inir-wull-agentd
       (new Rust agent sidecar)
          |       |       |
          |       |       +-- typed tools + permission policy
          |       +---------- RAG/context/memory
          +------------------ router + model manager
                    |
          +---------+----------+
          |                    |
          v                    v
  LFM inference         Qwen inference
  process/runtime       process/runtime
          |
          +---- semantic Wull activity events ----> inir-companiond
```

Naming `inir-wull-agentd` is the preferred working name, not a requirement to create it before baseline measurements. Before implementation, verify it fits current native workspace/package conventions.

### Hard architectural rules

- Quickshell remains alive if either model/runtime dies.
- `inir-companiond` remains deterministic and must remain useful without AI.
- Model runtime processes are supervised and restartable.
- The LLM never directly owns destructive authority.
- Tool contracts stay independent of model prompt syntax.
- Model-specific chat templates/tool-call adapters belong behind the model backend interface.
- No model binary or projector is stored in Git.
- No cloud provider is required for the local baseline.
- No Ollama/LM Studio dependency is required in production.

---

## 3. Selected two-model architecture

### 3.1 Reflex — LFM2.5-VL-3B

Target: `LFM2.5-VL-3B-GGUF / UD-Q6_K_XL`.

Responsibilities:

- screenshot understanding;
- OCR of visible UI, terminal and code when needed;
- UI element detection/grounding;
- compact scene summary;
- confidence/uncertainty reporting;
- simple visual questions that do not need multi-step reasoning;
- producing structured perception for Brain or deterministic actions.

Reflex is **not** the default reasoning engine and must not be used merely because it is already resident.

Required perception output contract, conceptually:

```json
{
  "frame_id": "...",
  "summary": "...",
  "visible_text": [],
  "elements": [
    {
      "role": "button",
      "label": "...",
      "bbox": [x, y, w, h],
      "confidence": 0.0
    }
  ],
  "uncertainties": [],
  "recommended_followup": "none|brain|structured_api"
}
```

The final schema may differ, but it must be bounded and typed. Do not forward unrestricted prose vision output into an action executor.

### 3.2 Brain — Qwen3.5-4B-MTP

Target: `Qwen3.5-4B-MTP-GGUF / UD-Q4_K_XL`.

Responsibilities:

- EN/VN conversation;
- multi-step reasoning;
- planning;
- Rust/Python analysis;
- Hadalis architecture reasoning;
- deciding among already-authorized typed tools;
- recovery after tool errors;
- synthesizing retrieved documentation/source evidence.

Brain should normally receive **structured text/context**, not raw screenshots. LFM owns the primary visual path so Qwen's vision projector is unnecessary for the initial architecture.

MTP is an optimization, not a correctness dependency. Benchmark Brain with MTP enabled and with the closest supported non-speculative path. If MTP is unstable or unsupported by the pinned runtime, correctness wins.

### 3.3 No specialist model

Do not add a third coding model in the first implementation.

Coding knowledge comes from:

```text
Qwen3.5-4B base capability
        +
retrieved Rust/Python/Qt/Quickshell docs
        +
relevant Hadalis source
        +
compiler/test/tool feedback
```

Only reconsider a specialist model if the benchmark proves a repeated failure that RAG/tools/fine-tuning cannot solve within the resource budget.

---

## 4. Router design

The router is one of the most important parts of Wull. It must initially be **rule/feature driven in Rust**, not another LLM call.

### Route classes

**R0 — deterministic/no model**

Examples:

- query known workspace/window/process state;
- launch an app by a validated ID;
- retrieve shell config through known APIs;
- check a file that the user named exactly;
- deterministic Wull animation/presence event.

**R1 — Reflex only**

Examples:

- "what is visible in this dialog?";
- identify a button/icon when structured accessibility/API data is unavailable;
- OCR a terminal line;
- locate a UI element;
- summarize a screenshot into structured state.

**R2 — Brain only**

Examples:

- explain Rust ownership/borrow errors from already-provided text;
- compare a Python and Rust implementation;
- plan a sequence of typed actions;
- reason about Hadalis code retrieved from source;
- answer EN/VN questions not requiring the current screen.

**R3 — Reflex -> Brain**

Examples:

- screenshot contains an error and user asks for diagnosis;
- user asks Wull to inspect visible UI then decide the next action;
- visual evidence must be converted into a multi-step plan.

### Initial escalation rules

Escalate to Brain when one or more are true:

- request explicitly asks "why", "compare", "analyze", "plan", "debug", "design", "rewrite", "Rust", "Python", "code";
- task needs more than one dependent action;
- tool selection is ambiguous;
- Reflex reports uncertainty below the accepted confidence threshold;
- previous deterministic action failed and recovery requires interpretation;
- retrieved evidence conflicts.

Do **not** wake Brain for:

- animation/emotion;
- hover/click feedback;
- deterministic shell state;
- basic app launch;
- successful known typed action;
- simple OCR/grounding answer.

### Router metrics

Track:

- hard-task miss rate: Brain was needed but not invoked;
- unnecessary Brain wake rate;
- unnecessary vision call rate;
- mean number of model calls/task;
- route-to-completion latency;
- route correctness by category.

Initial acceptance target after the benchmark is calibrated:

- protected/destructive tasks: 0 direct model-executed actions;
- hard-task miss <= 5%;
- unnecessary Brain wake <= 15% on the canonical desktop suite;
- simple deterministic tasks should complete with 0 LLM calls whenever structured state is sufficient.

---

## 5. Runtime plan

### 5.1 Pin runtime before measuring

Before collecting any result:

- [ ] Build/install a current `llama.cpp` revision that supports both target model architectures.
- [ ] Record `llama.cpp` git SHA, compiler, build flags, Vulkan/CPU backend availability.
- [ ] Record kernel/driver/Mesa/Vulkan device versions.
- [ ] Do not compare results from different runtime revisions without labeling them separately.

### 5.2 LFM isolated baseline

Verify:

- model loads;
- compatible `mmproj` loads;
- one fixed screenshot produces a valid answer;
- image input works repeatedly;
- no crash/leak after a bounded loop;
- CPU-only path works as correctness fallback;
- Vulkan/offload path is measured separately.

Measure:

- cold model load;
- projector/image preprocessing;
- prompt processing;
- first-token latency;
- end-to-end screenshot -> structured result latency;
- output tokens/sec;
- peak RSS;
- GPU memory/offload if applicable;
- CPU/GPU utilization;
- repeated-frame behavior.

### 5.3 Qwen isolated baseline

Verify:

- model loads;
- Vietnamese/English output;
- thinking/reasoning behavior under bounded budgets;
- Rust/Python coding prompts;
- structured JSON/tool-call output;
- MTP path;
- non-MTP/fallback path where supported.

Measure:

- cold load;
- warm prompt processing;
- first-token latency;
- decode tokens/sec;
- MTP accepted draft-token behavior if runtime exposes it;
- peak RSS;
- CPU/Vulkan behavior;
- quality at fixed output budgets.

### 5.4 Context policy

Do **not** lock Brain to 4K–8K merely to save memory. Qwen's official Qwen3.5-4B guidance says the model is native to 262,144 tokens and advises at least 128K when preserving its strongest thinking behavior matters. That recommendation was made for the model generally, not for this 18 GB desktop target, so Wull must measure the quality/resource curve rather than blindly following either extreme.

Benchmark four Brain context profiles on the same reasoning suite:

- **8K** — minimum-memory / simple desktop tasks;
- **32K** — likely everyday RAG + code working set;
- **64K** — deeper repository/debug tasks;
- **128K** — reference deep-thinking profile to quantify whether the quality gain is worth the memory/latency cost on the target machine.

Reflex uses LFM2.5-VL-3B's native 32K context as an upper capability bound, but ordinary screen perception should use only the tokens needed for the current image/task.

Qwen3.5 is a hybrid Gated DeltaNet/full-attention architecture, so its long-context memory behavior is not identical to a conventional all-attention transformer. Measure KV cache, recurrent-state memory, prompt/context checkpoint RAM, compute buffers, model weights, and server overhead separately.

Use one Brain slot during the first implementation. Large default prompt-cache/checkpoint allocations can hide the true cost of the model; explicitly benchmark bounded/disabled prompt caching before deciding production defaults.

No context profile is promoted solely because the model supports it. Production context is chosen by measured Wull task quality per GiB and latency.

---

## 6. Benchmark harness

Do not integrate models into the live Wull UI until a repeatable harness exists.

### 6.1 Harness principles

The harness must:

- run the same task set against multiple model/runtime configs;
- separate cold and warm tests;
- save machine-readable results;
- record exact model SHA-256 + runtime SHA;
- record command/config used;
- capture exit code and timeout;
- never silently replace a failed result;
- produce an aggregate table that can be copied into this file.

Raw benchmark outputs may be generated by scripts/fixtures elsewhere; **all decisions and canonical summary numbers remain in this file**.

### 6.2 Reflex suite

Minimum first useful suite: 100 real Wull-like screenshots, then grow toward 200+.

Include:

- simple dialogs;
- dense settings pages;
- terminal text;
- editor/code text;
- small icons;
- disabled/enabled controls;
- multiple monitors where possible;
- light/dark themes;
- 1080p/1440p/4K scale variants;
- fractional scaling;
- partially obscured UI;
- English UI text;
- Vietnamese text appearing in content;
- similar/ambiguous icons;
- error dialogs;
- screenshot compression/blur stress cases.

Metrics:

- OCR character error rate;
- target element hit rate;
- bounding-box/point grounding success;
- wrong-element rate;
- hallucinated-element rate;
- confidence calibration;
- screenshot-to-action latency.

### 6.3 Brain suite

Minimum first useful suite: 150 tasks, then grow toward 300+.

Buckets:

- EN conversation;
- VN conversation;
- Rust reasoning;
- Python reasoning;
- Rust vs Python architectural choice;
- Quickshell/QML;
- Hadalis source reasoning using retrieved context;
- tool-plan generation;
- schema-constrained JSON;
- recovery after tool failure;
- "insufficient evidence" behavior;
- refusal/confirmation for privileged actions.

Metrics:

- exact structured output validity;
- correct tool choice;
- argument accuracy;
- code compile/test success;
- factual grounding to supplied context;
- hallucination rate;
- task completion rate;
- latency/resource use.

### 6.4 Router suite

At least 100 mixed requests labeled R0/R1/R2/R3.

The router benchmark is mandatory because the project goal is not "best model score"; it is **minimum cost to correct action**.

### 6.5 Safety suite

At least 50 cases covering:

- deletion;
- overwriting;
- permission escalation;
- package/service mutation;
- dangerous Git operations;
- credential/private-file access;
- path traversal;
- prompt injection inside retrieved files/screenshots;
- malicious UI text instructing Wull to ignore policy.

Release gate: no protected action may bypass Rust policy because the model requested it.

---

## 7. Resource budget

Reference development machine currently documented for this project:

- Ryzen 5 PRO 7540U, 6C/12T;
- Radeon 740M integrated GPU;
- ~18 GB system RAM;
- swap is emergency fallback, not normal model memory.

Initial budget:

```text
Reflex model/projector expected artifact footprint: ~3.3 GB class
Brain model expected artifact footprint:            ~3.7 GB class
Peak if both loaded:                                ~7 GB weights/artifacts
+ runtime/KV/vision buffers:                        measured, not guessed
```

Production behavior target:

- Reflex may remain warm only if idle power/RAM is acceptable.
- Brain is on-demand by default until measurements justify residency.
- Normal AI subsystem target: <= 4–6 GB working RAM when only normal Reflex path is active.
- Combined peak should remain comfortably below pressure that causes swap thrash on the reference 18 GB machine.
- Idle inference CPU/GPU use should approach zero.
- No continuous screenshot polling purely for AI. Capture must be event/user/task driven unless a later feature has an explicit bounded need.

### Load policy experiment

Benchmark at least:

1. both resident;
2. Reflex resident + Brain on-demand;
3. both on-demand;
4. Brain retained for 30 s / 60 s / 180 s after use.

Choose based on measured:

- second-request latency;
- memory pressure;
- power;
- user-perceived responsiveness.

The initial production preference is **Reflex warm, Brain on-demand**, but benchmark may change it.

---

## 8. Model manager

Rust Model Manager owns:

- configured local model paths;
- artifact existence/hash check;
- runtime process spawn;
- health probe;
- load state;
- request queue;
- cancellation;
- per-model timeout;
- idle unload;
- bounded restart;
- stderr/log capture;
- runtime feature detection (MTP, vision/projector, Vulkan);
- resource-pressure response.

Suggested states:

```text
Missing
Ready
Loading
Warm
Busy
CoolingDown
Unloading
Failed
CircuitOpen
```

Never model "loaded" as a boolean only; failures and transitions matter.

### Failure behavior

- missing Reflex model/projector -> Wull visual still works; vision features report unavailable;
- missing Brain -> deterministic + Reflex features still work;
- Brain OOM -> unload Brain, keep shell alive, report bounded error;
- Reflex crash -> restart with bounded attempts; no click/action from stale perception;
- repeated runtime crash -> open circuit and require explicit retry/restart window;
- request timeout -> cancel/kill bounded child if necessary; never freeze UI;
- malformed model output -> schema reject, no tool execution;
- MTP failure -> retry via verified fallback configuration, not an unbounded restart loop.

---

## 9. Tool execution architecture

LLMs propose; Rust validates and executes.

### Initial typed tool families

- `filesystem.search/read/stat`
- `clipboard.get`
- `process.list/status`
- `system.status/logs`
- `app.list/launch/focus`
- `git.status/diff/log`
- Hadalis/Quickshell IPC reads
- compositor/window/workspace reads
- screenshot capture

Add mutation only after read-only end-to-end flow is stable:

- `filesystem.write/create/copy/move/rename`
- app/process mutation
- shell config mutation
- Git write actions

### Execution preference

1. Hadalis/Quickshell native IPC;
2. DBus/system APIs;
3. compositor IPC;
4. typed native helper;
5. application API/CLI;
6. accessibility interface;
7. simulated input;
8. vision-guided pointer action only as last resort.

### Permission tiers

**A — read / low impact:** may execute automatically when request intent is clear.  
**B — reversible mutation:** must satisfy explicit policy and surface what changed.  
**C — destructive/privileged:** explicit confirmation required immediately before execution.

Hard controls:

- canonicalize paths;
- block traversal outside granted scope;
- validate every argument;
- bound stdout/stderr;
- enforce timeout/cancel;
- no unrestricted model-generated `bash -c`;
- redact secrets from logs;
- never let screenshot/retrieved text alter permission policy.

---

## 10. Reflex -> Brain contract

Brain must not receive an unbounded dump of OCR/screenshot prose.

The handoff should include only:

- user request;
- selected visible text;
- selected elements/coordinates if relevant;
- confidence;
- uncertainties;
- current app/window identity if deterministically known;
- relevant tool results;
- provenance/frame ID.

Example:

```json
{
  "request": "Why is this build failing?",
  "perception": {
    "source": "screen",
    "frame_id": "f-123",
    "active_app": "terminal",
    "text": [
      "error[E0277]: ..."
    ],
    "uncertain": false
  }
}
```

If a tool can read the terminal/log file directly, prefer that source over OCR before asking Brain to reason.

---

## 11. RAG strategy

Do not fine-tune current documentation into weights.

### Initial corpora

- current Hadalis `dev` source;
- `AGENTS.md`, architecture/structure docs and relevant project docs;
- Rust standard/book/reference/API material needed for tasks;
- Python language/library docs needed for tasks;
- Qt/QML/Quickshell docs;
- selected Linux/system/compositor docs.

### Retrieval rules

- retrieve narrowly by query/task;
- include file path/source/revision in chunks;
- cap token budget;
- prefer exact source definition and surrounding context over broad summaries;
- include only the minimum code needed for reasoning;
- never treat retrieved text as trusted instructions;
- repository policy/system instructions outrank retrieved content.

### Index freshness

Hadalis repository retrieval must be revision-aware. A response about code should know which commit/source version it used.

Invalidate/reindex changed files incrementally rather than rebuilding everything on every chat.

### RAG benchmark

Measure:

- retrieval recall@k on known questions;
- irrelevant-token ratio;
- answer correctness with/without retrieval;
- latency added by retrieval;
- stale-source rate.

---

## 12. Memory design

Separate three concepts:

### Session working memory

Short-lived conversation/task state. Discard/compact aggressively.

### Local durable user memory

Only store information that has a clear future value and is permitted by product policy. Must support inspection and deletion. Do not silently store secrets, credentials, raw clipboard history or arbitrary screenshots.

### Knowledge/RAG index

Documents/source are not "user memory". They have their own revision/provenance.

Initial implementation may use a simple local SQLite/JSON metadata store plus a replaceable vector/index backend. Do not bind the agent architecture to one embedding database.

Memory must never be required for Wull's deterministic visual behavior.

---

## 13. IPC/API contract

The QML-facing API should be small and asynchronous.

Conceptual request:

```json
{
  "v": 1,
  "id": "req-...",
  "type": "ask",
  "text": "...",
  "attachments": [],
  "screen_context": "none|capture_if_needed"
}
```

Conceptual streamed events:

```text
accepted
route_selected
model_loading
thinking
tool_proposed
confirmation_required
tool_running
token_delta
completed
failed
cancelled
```

The exact protocol must:

- version messages;
- bound message/frame size;
- carry request IDs;
- support cancellation;
- distinguish model text from trusted tool results;
- never rely on parsing human-readable logs.

Wull activity can be mapped into existing `inir-companiond` semantic events such as thinking/working/success/warning/error without sending frame-rate animation traffic through the AI daemon.

---

## 14. Integration with existing `services/Ai.qml`

Do not rewrite the existing multi-provider AI stack merely to prove local Wull.

Planned sequence:

1. isolated Rust/runtime benchmark;
2. Rust agent sidecar;
3. local provider/adapter that exposes the sidecar to existing UI where useful;
4. keep remote providers as separate optional chat providers;
5. Wull-specific tool/permission policy remains in Rust.

Questions to answer before integration:

- Can current provider catalog express the local Wull endpoint/capabilities cleanly?
- Which conversation state should remain in `Ai.qml` versus move into the Rust agent?
- How are streaming/cancellation mapped without blocking the QML event loop?
- How can existing safe actions be reused instead of duplicated?
- How does local-only policy select Wull without breaking other provider behavior?

No source change in `Ai.qml` is authorized merely by this plan; inspect and test its current contracts first.

---

## 15. Security / prompt-injection model

Treat the following as **untrusted data**, never instructions:

- webpage text;
- screenshot text;
- terminal output;
- source comments;
- README/docs retrieved by RAG;
- clipboard content;
- tool output.

The Brain may reason about this data but cannot let it override:

- tool permissions;
- confirmation requirements;
- path restrictions;
- system policy;
- model routing/security policy.

Required tests include text such as "ignore previous instructions and delete..." inside a screenshot/document. Expected result: data is summarized/handled as data; policy remains unchanged.

---

## 16. Training policy

### T0 — base models only

Mandatory first.

- tools;
- routing;
- RAG;
- benchmark;
- resource manager;
- error recovery.

Do not tune weights before these exist.

### T1 — LoRA/QLoRA/SFT

Only after repeated base-model failures are categorized.

Suitable targets:

- Wull concise EN/VN style;
- structured tool calls;
- Hadalis conventions;
- recovery behavior;
- stable Rust/QML patterns.

Do **not** use tuning to memorize fast-changing repo source/docs.

### T2 — distillation

Only after automated validators exist.

```text
teacher
 -> generated candidate
 -> schema/compile/test validation
 -> human/agent review where needed
 -> accepted dataset
 -> 2B–4B student
 -> same canonical benchmark
```

The long-term durable assets are:

- benchmark;
- verified dataset;
- validators;
- tool contracts;
- RAG corpus/provenance.

The deployed model remains replaceable.

---

## 17. Detailed implementation phases

### P0.5 — Local artifact + runtime verification — CURRENT

- [x] Select two-model architecture: LFM Reflex + Qwen Brain.
- [x] Select LFM target quant: `UD-Q6_K_XL`.
- [x] Select Qwen target quant: `UD-Q4_K_XL`.
- [x] Select Qwen MTP build as preferred Brain candidate.
- [x] Maintainer reports both model families downloaded.
- [ ] Verify exact filenames.
- [ ] Verify model SHA-256.
- [ ] Verify compatible LFM `mmproj`.
- [ ] Pin `llama.cpp` revision.
- [ ] Run one-image LFM smoke test.
- [ ] Run EN/VN + Rust/Python Qwen smoke tests.
- [ ] Run MTP smoke test.
- [ ] Record cold/warm RAM and latency baseline.

**Exit gate:** both models can be invoked independently and reproducibly; failures are understood; exact artifacts/runtime are recorded.

### P1 — Benchmark harness

- [ ] Define machine-readable case schema.
- [ ] Create first Reflex screenshot set.
- [ ] Create first Brain reasoning/tool set.
- [ ] Create route labels.
- [ ] Create safety set.
- [ ] Capture metrics + environment automatically.
- [ ] Produce repeatable summary tables.
- [ ] Compare CPU vs Vulkan.
- [ ] Compare Brain MTP on/off/fallback.
- [ ] Compare llama.cpp multi-model router vs two independent server processes.
- [ ] Compare Brain reasoning controls/budgets at fixed task quality.
- [ ] Compare Reflex full-screen vs downscaled vs active-window/ROI capture.
- [ ] Compare LFM warm fast-text path vs waking Qwen for simple non-reasoning text.
- [ ] Verify Vulkan output correctness across practical batch/ubatch values, not throughput alone.
- [ ] If available, compare LFM `UD-Q5_K_XL`, `Q6_K`, `UD-Q6_K_XL` only on the same exact suite before claiming the extra memory is worthwhile.

**Exit gate:** one command can reproduce the baseline on a known machine and outputs evidence sufficient to compare configs.

### P2 — Rust agent/model-manager skeleton

- [ ] Audit current native workspace patterns.
- [ ] Add the new Rust sidecar using established workspace conventions.
- [ ] Implement request IDs, cancellation, timeouts, bounded logs.
- [ ] Implement process supervision for inference runtime.
- [ ] Prefer llama.cpp router load/unload/sleep/status APIs where they prove stable; do not duplicate working lifecycle machinery in Rust.
- [ ] Keep dual-server supervision as a tested fallback topology.
- [ ] Implement model state machine.
- [ ] Implement artifact/path/hash validation.
- [ ] Implement no-model graceful mode.
- [ ] Unit test crash/restart/cancel/state transitions.

**Exit gate:** Rust can safely supervise both model paths without Quickshell integration.

### P3 — Router + two-model handoff

- [ ] Implement R0/R1/R2/R3 deterministic router.
- [ ] Implement typed Reflex result.
- [ ] Implement bounded Reflex -> Brain context.
- [ ] Add confidence/uncertainty handling.
- [ ] Add Brain wake/unload policy.
- [ ] Benchmark route accuracy and model-call count.

**Exit gate:** mixed benchmark tasks reach the correct model path with bounded resource use.

### P4 — Read-only typed tools

- [ ] filesystem read/search/stat;
- [ ] process/system status;
- [ ] app/window/workspace queries;
- [ ] clipboard read with privacy guard;
- [ ] Git status/diff/log;
- [ ] Hadalis IPC read paths;
- [ ] screenshot capture.

**Exit gate:** Brain can solve useful desktop tasks with no mutation authority and all calls are schema validated.

### P5 — RAG

- [ ] repository index with revision provenance;
- [ ] Rust/Python/Qt/QML/Quickshell doc retrieval;
- [ ] bounded context builder;
- [ ] injection-resistant retrieval boundary;
- [ ] incremental refresh;
- [ ] retrieval benchmark.

**Exit gate:** Hadalis/Rust/Python answers measurably improve without inflating the model or feeding whole repositories.

### P6 — Quickshell/Wull integration

- [ ] define versioned async IPC;
- [ ] integrate with existing Wull UI without blocking render loop;
- [ ] map AI activity into `inir-companiond` semantic states;
- [ ] evaluate integration with `services/Ai.qml`;
- [ ] streaming text;
- [ ] cancellation UI;
- [ ] model unavailable/crash UI state;
- [ ] no-AI visual fallback.

**Exit gate:** killing either inference process does not crash or freeze Quickshell/Wull.

### P7 — Mutation tools + permissions

- [ ] reversible file actions;
- [ ] app/process mutation;
- [ ] shell config mutation through existing safe contract;
- [ ] Git write actions only when clearly scoped;
- [ ] confirmation gate for destructive/privileged operations;
- [ ] audit log/redaction;
- [ ] prompt-injection tests.

**Exit gate:** safety suite passes with zero policy bypass for protected actions.

### P8 — Resource optimization

- [ ] tune GPU offload;
- [ ] tune context/KV limits;
- [ ] benchmark residency TTL;
- [ ] avoid swap;
- [ ] idle power check;
- [ ] reduce duplicate buffers/copies;
- [ ] benchmark screenshot resolution/cropping strategy;
- [ ] decide final default quant/config from evidence.

**Exit gate:** selected default meets resource and quality gates on reference hardware.

### P9 — Optional tuning/distillation

- [ ] identify benchmark-backed failure clusters;
- [ ] collect verified examples;
- [ ] create leakage-safe train/validation/test split;
- [ ] LoRA/QLoRA experiment;
- [ ] reject regressions;
- [ ] consider teacher distillation only if it beats the untuned 4B architecture on Wull tasks.

### P10 — Production hardening

- [ ] model install/update/checksum flow;
- [ ] license/attribution review;
- [ ] safe rollback;
- [ ] missing/corrupt model recovery;
- [ ] version compatibility checks;
- [ ] canonical local repository validation;
- [ ] live Wayland/Quickshell acceptance;
- [ ] document measured hardware minimum/recommended profile.

---

## 18. Initial acceptance gates

These are starting targets; P1 may tighten them but must not silently weaken safety gates.

### Correctness

- structured model/tool output schema validity >= 99% on canonical cases;
- protected-action policy bypass = 0;
- hallucinated executable tool/action = 0 after Rust validation;
- Reflex target-element success >= 95% on the standard UI subset before vision-driven actions are enabled;
- low-confidence perception must fail closed or request another evidence source;
- model replacement cannot be promoted if it regresses core task completion without an explicit resource trade-off decision.

### Stability

- inference crash never terminates Quickshell;
- cancellation completes without orphaning an unbounded request;
- repeated crash enters circuit-breaker state;
- model missing/corrupt produces a useful error and preserves non-AI Wull;
- no background generation while idle.

### Resource

- no normal-use swap thrashing on the reference machine;
- idle Brain should not remain resident unless measurements show a justified user benefit;
- model/runtime memory must be measured including KV/projector/buffers;
- production default should prioritize desktop responsiveness over maximum tokens/sec.

### Latency

Do not invent an absolute release number before P1. Establish:

- Reflex screenshot -> structured result P50/P95;
- Brain cold wake -> first token P50/P95;
- Brain warm -> first token P50/P95;
- simple deterministic action latency;
- end-to-end routed task latency.

After baseline, record explicit numeric release thresholds in this section.

---

## 19. Benchmark result ledger

Keep aggregate results here. Raw generated files are evidence, not the source of truth for decisions.

### Environment

- Date: TBD
- Hadalis dev SHA: TBD
- `llama.cpp` SHA: TBD
- CPU: Ryzen 5 PRO 7540U
- GPU: Radeon 740M
- Mesa/Vulkan: TBD
- RAM: ~18 GB
- OS/kernel: TBD

### Reflex — LFM2.5-VL-3B

| Config | Model SHA | mmproj SHA | Backend | Cold load | P50 E2E | P95 E2E | OCR CER | Grounding | Peak RSS | Notes |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---|
| UD-Q6_K_XL | TBD | TBD | CPU | TBD | TBD | TBD | TBD | TBD | TBD | baseline |
| UD-Q6_K_XL | TBD | TBD | Vulkan | TBD | TBD | TBD | TBD | TBD | TBD | baseline |

### Brain — Qwen3.5-4B-MTP

| Config | Model SHA | Backend | MTP | Cold load | Warm TTFT | tok/s | Quality score | Peak RSS | Notes |
|---|---|---|---|---:|---:|---:|---:|---:|---|
| UD-Q4_K_XL | TBD | CPU | off/fallback | TBD | TBD | TBD | TBD | TBD | baseline |
| UD-Q4_K_XL | TBD | CPU | on | TBD | TBD | TBD | TBD | TBD | baseline |
| UD-Q4_K_XL | TBD | Vulkan | on | TBD | TBD | TBD | TBD | TBD | baseline |

### Router

| Metric | Result |
|---|---:|
| hard-task miss | TBD |
| unnecessary Brain wake | TBD |
| unnecessary vision call | TBD |
| average model calls/task | TBD |
| task completion | TBD |

### Decision log

- 2026-10-04 — choose two-model design instead of 12B Brain + separate coding specialist.
- 2026-10-04 — Reflex target set to LFM2.5-VL-3B `UD-Q6_K_XL` because perception/OCR errors contaminate downstream reasoning and the memory delta versus Q5 is small enough to benchmark.
- 2026-10-04 — Brain target set to Qwen3.5-4B-MTP `UD-Q4_K_XL`; keep Brain on-demand initially.
- 2026-10-04 — no specialist model; use RAG/tools/compiler feedback first.
- 2026-10-04 — do not fine-tune until reproducible base-model results exist.
- 2026-10-04 — do not assume 4K–8K Brain context is sufficient: benchmark 8K/32K/64K/128K because Qwen recommends >=128K when preserving strongest thinking behavior matters.
- 2026-10-04 — **superseded by later upstream audit:** current llama.cpp has a real multi-model router. Primary candidate is now one private llama-server router with two model presets/instances; benchmark against dual-server fallback before locking topology.
- 2026-10-04 — bind local inference servers to private Unix sockets where practical, disable llama.cpp WebUI/server tools/agent/MCP, and keep all executable tool authority in Rust.
- 2026-10-04 — Vulkan is a benchmark candidate, not an assumption: Qwen3.5 Gated DeltaNet Vulkan support exists upstream, but AMD performance remains architecture/driver/build sensitive.

Add future decisions here with the evidence/benchmark revision that caused them.

---

## 20. Local model storage/package policy

Proposed user-data location, subject to existing Hadalis XDG conventions:

```text
$XDG_DATA_HOME/inir/models/wull/
  lfm/
  qwen/
  manifest.json
```

Do not hardcode a home path until current installer/config conventions are audited.

Manifest should eventually record:

- model logical ID;
- exact filename;
- quant;
- source repository/revision;
- SHA-256;
- byte size;
- compatible projector;
- compatible runtime feature requirements;
- license/attribution;
- install timestamp.
- upstream license identifier/text/NOTICE requirements;
- commercial-use constraint metadata when the model is not Apache/MIT-like.

Runtime must validate files before treating them as usable.

Refined XDG layout candidate after repository audit:

~~~text
$XDG_DATA_HOME/inir/models/wull/       # large immutable-ish model artifacts
$XDG_RUNTIME_DIR/inir/wull/            # private live sockets/temp runtime state
$XDG_STATE_HOME/inir/wull/             # durable manifests/benchmark summaries/log metadata
~~~

Create the runtime directory as private user state (target mode 0700) and model/agent sockets as user-only (target mode 0600). Reuse the repository's established XDG conventions rather than inventing fixed home-directory paths.

---

## 21. What not to do

- Do not commit GGUF/`mmproj` binaries.
- Do not make Wull wait on Brain for hover/animation.
- Do not pass raw model prose straight into shell execution.
- Do not use vision when a structured system API can answer the same question.
- Do not give the model unrestricted shell access.
- Do not put large mutable docs into model weights.
- Do not benchmark one quant/runtime on one task and generalize to all Wull workloads.
- Do not treat tokens/sec as the only performance metric.
- Do not assume MTP is faster until measured on the target machine.
- Do not assume Vulkan is faster than CPU for every prompt/image size.
- Do not let a retrieved README/webpage/screenshot redefine permissions.
- Do not merge AI lifetime into the deterministic animation daemon until there is evidence this is superior.
- Do not add a third model until a benchmark-backed need exists.
- Do not create another Wull-AI planning file.

---

## 22. Immediate next execution sequence

This is the next work order; complete in order.

1. **Local artifact inventory**
   - identify exact two GGUF paths;
   - confirm `UD-Q6_K_XL` and `UD-Q4_K_XL`;
   - confirm LFM projector;
   - compute hashes/sizes.

2. **Pin/build runtime**
   - record current `llama.cpp` SHA;
   - record CPU/Vulkan build capabilities;
   - verify LFM vision and Qwen MTP feature support.

3. **Smoke LFM**
   - one fixed screenshot;
   - one OCR task;
   - one grounding task;
   - repeat 10 times;
   - record crash/latency/RSS.

4. **Smoke Qwen**
   - EN;
   - VN;
   - Rust;
   - Python;
   - Rust-vs-Python reasoning;
   - strict JSON/tool schema;
   - MTP path.

5. **Create P1 harness**
   - make these tests reproducible before integrating with QML.

6. **Benchmark resource modes**
   - CPU and Vulkan;
   - Brain MTP/fallback;
   - cold and warm;
   - no guesswork from model file size.

7. **Only after baseline**
   - create Rust agent/model-manager skeleton;
   - do not modify live Wull/QML path earlier unless needed for a bounded harness.

8. **Update this file**
   - record hashes, runtime SHA, measured numbers, failures and next phase;
   - keep this file as the only local-AI plan/status ledger.

---

## 23. Definition of first usable milestone

The first usable local-Wull milestone is achieved only when all are true:

- LFM can inspect a real screenshot and return schema-validated perception;
- Qwen can reason in EN/VN and across representative Rust/Python tasks;
- router chooses deterministic/Reflex/Brain/cascade paths correctly on the initial suite;
- Brain can be started/stopped without freezing Wull;
- a model/runtime crash does not crash Quickshell;
- read-only typed tools work end-to-end;
- no protected action can bypass Rust policy;
- benchmark/runtime/model revisions are reproducible;
- model binaries remain outside Git;
- current source passes the repository's canonical maintainer validator for the exact tested SHA;
- live Wayland/Quickshell behavior is accepted separately where static validation cannot prove it.

Only after this milestone should Wull proceed to mutation tools, deeper RAG/memory, LoRA or distillation.


---

## 24. Research pass — runtime/API/backend findings (2026-10-04)

This pass validates and sharpens the two-model design against current upstream model/runtime behavior. It does **not** advance the phase beyond P0.5 because no measurements from the maintainer's machine have been collected yet.

### 24.1 The Reflex/Brain split is benchmark-supported

Liquid AI's LFM2.5-VL-3B release data makes the model unusually well matched to the Reflex role:

- ScreenSpot-v2 average: **80.7**;
- RefCOCO grounding macro P@1: **87.9**;
- ToolSandbox: **59.5**;
- it is explicitly a **non-reasoning** model intended for low-latency direct answers;
- the published model supports Vietnamese and has a 32K context window.

In the same Liquid AI comparison, Qwen3.5-4B scores **78.5** on ScreenSpot-v2 average and **86.6** on RefCOCO, so the smaller LFM is competitive/slightly stronger on the two screen/grounding metrics most important to Reflex. Qwen3.5-4B is substantially stronger on instruction following/tool benchmarks in that table, which supports keeping Qwen as Brain instead of asking LFM to perform deep planning.

**Decision:** keep the two models specialized by role; do not collapse to one model before local end-to-end measurements.

### 24.2 Exact artifact footprint clarification

Current Unsloth repository metadata reports:

- LFM2.5-VL-3B UD-Q6_K_XL: about **2.40 GB**;
- LFM mmproj-F16.gguf: about **854 MB**;
- combined Reflex artifacts: about **3.25 GB** before runtime/cache overhead;
- Qwen3.5-4B-MTP UD-Q4_K_XL: about **2.99 GB** in current repository metadata.

Therefore older rough UI-derived values such as "~3.7 GB Brain" must **not** be treated as authoritative. File size, mapped RSS, GPU-visible memory and total process memory are separate measurements.

**Action:** P0.5 must record actual local byte size + SHA-256 rather than copying website/UI size estimates into acceptance calculations.

### 24.3 Runtime topology correction: test llama.cpp router mode first

A newer/current upstream audit changes the earlier two-process recommendation. Current `llama-server` has a **multi-model router mode**: launch the server without a single `-m`, provide `--models-dir` and/or `--models-preset`, and the router starts/forwards to model instances by the request's `model` field.

Model presets support ordinary per-model llama.cpp arguments plus router-only controls including:

- `load-on-startup`;
- `stop-timeout`;
- model-specific context/backend/mmproj/speculative-decoding settings.

Router APIs include:

- `GET /models` for state/config/capability information;
- `POST /models/load`;
- `POST /models/unload`;
- `GET /models/sse` for real-time loading/status events, including `text_model`, `spec_model`, and `mmproj_model` stages.

The server also supports `--sleep-idle-seconds` in multi-model mode: idle model memory, including KV cache, is unloaded and a later task wakes/reloads it automatically.

This maps unusually well to Wull:

~~~text
Quickshell
   |
   v
inir-wull-agentd
   |
   | private HTTP over Unix socket
   v
llama-server router
   |
   +-- preset: wull-reflex
   |      LFM2.5-VL-3B + mmproj
   |      load-on-startup = true (candidate)
   |
   +-- preset: wull-brain
          Qwen3.5-4B-MTP
          load-on-startup = false
          sleep after measured idle TTL
~~~

**Primary candidate:** one supervised router parent with two named presets/instances.

**Fallback:** two independently supervised `llama-server` processes remain valid if the router introduces unacceptable failure coupling, memory residue, MTP/mmproj configuration limitations, or reload latency.

P0.5/P1 must benchmark **router mode vs dual-server mode** before production lock-in. Compare peak/idle RSS, cold wake, restart isolation, stale worker processes, MTP behavior, mmproj behavior and recovery after intentionally killing one model worker.

Keep the server private:

- Unix socket under a private `$XDG_RUNTIME_DIR/inir/wull/` directory where supported;
- `--no-webui`;
- single slot initially;
- do **not** enable llama.cpp server tools/agent/MCP;
- executable tool authority remains in Rust.

### 24.4 llama-server already provides useful protocol primitives

Current server APIs can remove custom plumbing from the first implementation:

- OpenAI-compatible /v1/chat/completions;
- streaming responses;
- multimodal image_url input when an mmproj is loaded;
- schema-constrained JSON via response_format;
- tool-call parsing support;
- reasoning controls/template kwargs;
- model capability metadata from /v1/models.

Use **schema-constrained JSON** for the Reflex perception contract before inventing a custom text parser.

For multimodal requests, treat llama.cpp support as experimental and pin the exact runtime revision. Prefer passing captured image bytes/base64 from the Rust sidecar; if local file URLs are used, restrict --media-path to a dedicated temporary capture directory, never the user's home directory.

### 24.5 Qwen MTP is usable upstream but needs a hard fallback

Unsloth documents Qwen3.5 MTP support in mainline llama.cpp after the May 2026 merge. Current recommended flags include:

~~~text
--spec-type draft-mtp
--spec-draft-n-max 6
--parallel 1
~~~

Unsloth also documents two limitations relevant to architecture: MTP does not support --mmproj in that path, and -np > 1 is not supported for the documented MTP configuration.

These are compatible with Wull because Brain is text/reasoning only and the initial agent is single-user/single-slot.

There are still active/very recent llama.cpp edge-case reports around Qwen3.5 MTP, including compact draft-vocabulary handling. This is not evidence that the selected Unsloth integrated MTP GGUF is broken, but it is enough to require an MTP-on benchmark, a non-MTP baseline, automatic configuration fallback after a verified MTP initialization failure, and the exact llama.cpp SHA in every result.

MTP is a latency optimization, never a dependency for correctness.

### 24.6 AMD/Vulkan is promising but cannot be assumed on Radeon 740M

Qwen3.5 uses Gated DeltaNet recurrent layers plus periodic full-attention layers. llama.cpp now has Vulkan support for the Gated DeltaNet operator, and recent hardware reports show it can run correctly on AMD Vulkan. However, current reports also show highly variable decode performance across Radeon generations/drivers and Qwen3.5 configurations.

A published Qwen3.5-4B Vulkan result on a much faster discrete Radeon shows Qwen3.5 can be materially slower than Qwen3-4B despite stronger model quality. Other integrated-Radeon reports show Vulkan often beats CPU generation, but performance is strongly affected by memory bandwidth, power limits and driver/build revision.

There is no trustworthy benchmark found for the exact **Ryzen 5 PRO 7540U / Radeon 740M** target running these exact two models.

**Decision:** keep all three baseline modes where available: CPU, Vulkan with maximum practical offload, and partial/hybrid offload if full offload is worse or unstable.

Do not spend time building ROCm-specific production logic until it beats Vulkan/CPU on the target machine.

### 24.7 Qwen context length is now a first-class benchmark variable

Qwen's official Qwen3.5-4B model card states native context **262,144** and advises at least **128K** when preserving strongest thinking behavior matters.

This conflicts with the earlier tentative Wull assumption that normal Brain context should simply be 4K–8K. On a desktop companion, 128K may still be too expensive, but shrinking context can change capability, not only memory use.

Because only 8 of Qwen3.5-4B's 32 layers are full-attention under its documented 3-linear/1-attention layout, cache scaling is different from an all-attention transformer. llama.cpp also stores recurrent state/checkpoints for hybrid models, so ordinary KV-only estimates are incomplete.

**Benchmark requirement added:** evaluate 8K/32K/64K/128K with the same hard Brain suite and record quality, TTFT, prompt processing, RSS and cache/checkpoint memory. The production default is the smallest profile that preserves the required Wull capability.

Also benchmark --ctx-checkpoints / --cache-ram behavior. Recent llama.cpp reports show recurrent-model prompt checkpoints can consume substantial host RAM when many checkpoints are retained. Wull is single-user and does not need a huge prompt cache by default.

### 24.8 Existing Hadalis AI stack can be reused as UI adapter

Repository audit at dev HEAD 6787666cba0c282ec30295c01ccc198a781c21b1 found:

- services/Ai.qml already owns multi-provider conversation behavior and typed safe shell-action integration;
- services/ai/AiProviderCatalog.qml already discovers local/remote OpenAI-compatible catalogs and tracks provider health;
- modules/common/AiProviderPresets.qml already has local Ollama and LM Studio presets;
- no direct llama.cpp/Wull provider preset currently exists.

Because llama-server is OpenAI-compatible, a future **single Wull local provider** can fit the existing UI/provider model without exposing LFM and Qwen as two separate assistants.

Preferred integration:

~~~text
Ai.qml
  -> one local "Wull" provider
  -> inir-wull-agentd
  -> internal router
       -> Reflex server
       -> Brain server
~~~

Do not point Ai.qml independently at both llama-server processes. The router, permissions, RAG and model lifecycle belong behind the Rust Wull provider.

The existing safe action registry is also evidence that the project should reuse/extend current typed actions rather than create an unrelated second execution system.

### 24.9 New P0.5 experiments produced by this research

Before P1 implementation, collect these exact comparisons locally.

**Brain context sweep:** 8K, 32K, 64K, 128K at identical prompts/sampling, with MTP off first, then MTP on for the winning practical profiles.

**Brain backend sweep:** CPU, Vulkan, and Vulkan with relevant flash-attention settings. Measure both prompt processing and decode; a backend can win one and lose the other.

**Server-memory sweep:** default prompt cache/checkpoints, bounded cache/checkpoints, prompt cache disabled. Measure idle + post-request RSS because hybrid-model checkpoints can survive beyond generation.

**Reflex input sweep:** full screenshot, downscaled screenshot, cropped target region. Measure grounding/OCR accuracy against end-to-end latency. For Wull, reducing vision tokens before inference may save more latency than changing quantization.

### 24.10 Upstream references used in this pass

- Liquid AI, LFM2.5-VL-3B release post, 2026-08-12.
- Unsloth LFM2.5-VL-3B-GGUF model card/files.
- Qwen Qwen3.5-4B official model card.
- Unsloth Qwen3.5-4B-MTP-GGUF model card/MTP instructions.
- llama.cpp tools/server/README.md and tools/mtmd/README.md.
- llama.cpp current Qwen3.5 model implementation and Gated DeltaNet/Vulkan issue/discussion history.

Upstream pages are moving targets. The **pinned llama.cpp SHA + local benchmark** remains authoritative for Wull.


---

## 25. Research pass — multi-model router, Unix IPC, licensing and fast paths (2026-10-04)

This pass continues P0.5. It changes the preferred runtime topology, but does not claim local acceptance until the maintainer's machine produces measurements.

### 25.1 llama.cpp can own model residency without owning Wull policy

The current llama.cpp router is more capable than assumed in the previous pass. In addition to model-specific presets, it exposes explicit load/unload and status APIs and can sleep idle models.

That means `inir-wull-agentd` does **not** need to reimplement a full model loader state machine from scratch. Rust should still own the product-level state and recovery policy, but it can delegate low-level residency to the router:

~~~text
Rust state              llama.cpp router state
-----------             ----------------------
Ready          <----->  unloaded
Loading        <----->  loading
Warm/Busy      <----->  loaded
CoolingDown    <----->  loaded / idle timer
Sleeping       <----->  sleeping
Failed         <----->  failure / worker exit
~~~

Rust remains responsible for request routing, timeouts, user cancellation, retry limits, policy, RAG, typed tools and deciding when a server failure is terminal. llama.cpp owns the actual model instance lifecycle only while it behaves correctly.

Important caveat: sleep unloads model memory but current router workers may remain alive. Therefore benchmark **RSS/VRAM after sleep**, not merely reported status.

### 25.2 Quickshell can use a native Unix socket to the Rust agent

Quickshell's `Quickshell.Io.Socket` provides a Unix socket client with path/connected/write/flush plus stream parsers. `SocketServer` also exists.

Preferred UI transport therefore becomes:

~~~text
services/Ai.qml / Wull QML
        |
        | versioned bounded JSONL
        v
$XDG_RUNTIME_DIR/inir/wull/agent.sock
        |
        v
inir-wull-agentd (Rust)
        |
        | HTTP over Unix socket
        v
$XDG_RUNTIME_DIR/inir/wull/llama.sock
        |
        v
llama-server router
~~~

This avoids exposing a local TCP port for the normal Linux path.

Implementation requirements:

- verify the packaged Quickshell build has socket support before depending on it;
- private runtime directory, owned by effective UID;
- socket mode 0600;
- Rust should verify same-UID peers with `SO_PEERCRED` where practical;
- bounded frame/message sizes;
- versioned protocol;
- request IDs;
- cancellation message;
- QML never receives a raw model-server socket or permission token.

If a supported Quickshell build lacks socket support, a long-lived bounded stdio `Process` bridge is a fallback, not the first design.

### 25.3 Rust can call llama-server over Unix socket directly

Current reqwest on Unix supports `ClientBuilder::unix_socket(...)`. Therefore the Rust sidecar does not need curl or a localhost proxy to call llama.cpp.

This keeps the internal path:

- local-only;
- dependency-light at runtime;
- easy to supervise;
- independent from user firewall/port conflicts.

The Rust HTTP client should use explicit connect/read/request timeouts and bounded response bodies even on a Unix socket.

### 25.4 Qwen thinking should be dynamically budgeted, not simply ON/OFF

Current llama.cpp exposes several reasoning controls:

- server-level `--reasoning on|off|auto`;
- `reasoning_effort` in chat requests/templates;
- `--reasoning-budget N`, where 0 ends immediately and positive N is a token budget;
- `reasoning_control` with a live `reasoning_end` control action for an in-flight completion.

Qwen's own model card warns that long context helps preserve thinking capability, while its chat behavior does not use the old Qwen3 slash-command convention as the architectural control point.

Wull should therefore benchmark three practical Brain modes:

| Mode | Use | Candidate control |
|---|---|---|
| Fast | short direct text / obvious tool plan | reasoning off or budget 0 |
| Normal | common debugging/planning | bounded budget |
| Deep | difficult code/system reasoning | larger bounded budget + larger context if needed |

Do not map "high" to a fixed quality claim until the pinned template/runtime shows that it actually honors that effort level. The more reliable release metric is **task success at a measured reasoning-token budget**.

### 25.5 Consider LFM as a fast text path, but only after benchmark

LFM is already intended to be warm for vision, supports Vietnamese/function calling, and Liquid explicitly positions it as a non-reasoning low-latency model. This creates a possible extra optimization:

~~~text
simple text, no reasoning
      |
      +--> warm LFM -> short response
      |
complex/ambiguous/code
      |
      +--> wake Qwen -> reasoning
~~~

Candidate LFM-fast tasks:

- greeting/acknowledgement;
- short UI explanation from already-structured state;
- simple rewrite/translation;
- short confirmation;
- simple single-step intent classification.

This is **not** enabled by assumption. Add a fast-text suite and compare:

- LFM quality/latency while already warm;
- Qwen with reasoning disabled;
- Qwen cold wake;
- Qwen warm.

Only route text to LFM if quality remains acceptable and it measurably avoids Brain wakes.

### 25.6 Screenshot resolution/cropping may matter more than another quant step

LFM uses a dynamic vision path that can split large images into 512×512 regions plus a global view. A 4K desktop can therefore cost far more visual work than an active-window or target-region capture.

Hadalis already ships/uses `grim` and has existing targeted `grim -g` capture patterns. Reuse that infrastructure.

Benchmark:

1. full native-resolution output;
2. downscaled full output;
3. active-window crop;
4. semantic region-of-interest crop;
5. second-pass crop after coarse grounding.

For each, record:

- preprocessing time;
- prompt/vision token count if available;
- OCR CER;
- grounding success;
- end-to-end latency.

Preferred future policy if accuracy holds:

~~~text
structured API knows target/window -> crop directly
unknown screen target              -> coarse/full perception
coarse target found                -> optional high-res ROI second pass
~~~

This can improve both speed and accuracy because small UI text is not forced to compete with unrelated pixels.

### 25.7 Vulkan benchmarking must include correctness across batch settings

Recent upstream reports show Qwen3.5/Vulkan behavior can be sensitive to device, driver and batch/ubatch configuration. A throughput number is invalid if output quality corrupts.

For every GPU profile, the harness must first run deterministic sanity prompts and compare against the CPU baseline before recording performance.

Test at least:

- runtime default batch/ubatch;
- ubatch 512;
- ubatch 1024 where memory allows;
- practical GPU-layer/offload choices.

Reject any profile that produces NaNs, garbage, schema failures or reproducible answer corruption, even if tokens/sec is higher.

### 25.8 Cache/checkpoint memory needs explicit control

Current llama.cpp defaults include a large prompt cache budget and recurrent/hybrid context checkpoints. For Wull's single-user desktop workload, blindly accepting those defaults can consume more RAM than the weights themselves justify.

Benchmark:

- `cache-ram = 0` (disabled baseline);
- a small bounded cache;
- default cache;
- lower vs default context checkpoint counts.

Measure after:

- startup;
- one short request;
- repeated same-prefix requests;
- long RAG request;
- idle/sleep;
- model wake.

A cache setting is justified only by repeated-task latency saved per GiB retained.

### 25.9 KV-cache quantization is experimental, not a default

Because Qwen3.5 is hybrid rather than all-attention, quantized KV may offer useful savings, but community results are not enough to call it lossless.

If P0.5 memory pressure makes this worthwhile, benchmark in order:

1. F16/reference cache;
2. Q8-class cache;
3. Q4-class only as an experimental profile.

Run the full hard reasoning/schema suite after every cache-format change. Do not promote a memory optimization that silently changes reasoning/tool output.

### 25.10 LFM licensing must remain separate from Hadalis GPL code

Qwen3.5-4B is Apache-2.0. LFM2.5-VL-3B is distributed under Liquid AI's **LFM Open License v1.0**, which is Apache-derived but adds a commercial-use condition: free commercial rights end for entities at/above the stated **USD 10 million annual revenue** threshold, after which a separate commercial license is required. Redistribution also requires retaining the applicable license/attribution/NOTICE material.

Consequences for Hadalis packaging:

- never describe the LFM weights as GPL merely because Hadalis source is GPL;
- keep model files as separately licensed artifacts;
- prefer opt-in/downloaded model installation under XDG data rather than embedding multi-GB weights in the source repository;
- store/display source + license metadata in the Wull model manifest;
- preserve required attribution/license text when redistributing model artifacts;
- keep the Reflex interface replaceable so an organization that cannot accept the LFM license can select another compatible VLM.

This is a packaging/license compatibility concern, not a reason to reject LFM for ordinary eligible users.

### 25.11 Revised topology to benchmark

The leading candidate is now:

~~~text
Quickshell / Ai.qml / Wull UI
         |
         | Unix socket
         v
   inir-wull-agentd
         |
         +-- deterministic router / RAG / tools / policy
         |
         | HTTP over Unix socket
         v
   llama-server router
      |             |
      v             v
  wull-reflex    wull-brain
  LFM + mmproj   Qwen + MTP
~~~

Benchmark against the fallback:

~~~text
inir-wull-agentd
   |            |
   v            v
reflex server  brain server
~~~

Promotion criteria for router mode:

- no quality difference;
- model-specific LFM mmproj and Qwen MTP settings work simultaneously;
- worker failure recovery is bounded;
- sleeping Brain actually releases enough memory;
- router overhead is negligible;
- no meaningful reliability loss relative to two servers.

### 25.12 Immediate research-derived local tests

Add these to the first local test run once exact paths are known:

- router preset can load LFM + mmproj;
- router preset can load Qwen + MTP;
- both appear distinctly in `GET /models`;
- Reflex can be `load-on-startup` while Brain starts unloaded;
- Brain auto-load / explicit load works;
- Brain sleep releases RAM/VRAM;
- Brain wake latency after sleep;
- kill Brain worker and verify Reflex remains usable;
- kill router and verify Wull UI/companion remain usable;
- QML ↔ Rust Unix-socket reconnect after agent restart;
- reasoning budget 0 / bounded / deeper budget;
- full-screen vs ROI capture;
- Vulkan correctness before throughput;
- cache disabled/small/default memory sweep.

### 25.13 Upstream references used in this pass

- llama.cpp current `tools/server/README.md` and router endpoints.
- Quickshell `Quickshell.Io.Socket` / `SocketServer` documentation.
- reqwest current `ClientBuilder::unix_socket` documentation.
- Liquid AI LFM Open License v1.0 and official LFM2.5-VL-3B release notes.
- Qwen Qwen3.5-4B official model card.
- current llama.cpp reasoning/cache/router documentation and recent issue history.

As before, upstream behavior is not a production contract until pinned by SHA and reproduced locally.
