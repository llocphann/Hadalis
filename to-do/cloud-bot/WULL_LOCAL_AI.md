# Wull Local AI / Desktop Agent — Canonical TODO

> **Single source of truth for Wull local-AI work.** All future planning, status updates, architecture/model/runtime decisions, benchmark summaries, fine-tuning/distillation notes, rollout state, and acceptance evidence for this effort MUST be edited into this file only. Do not create another Wull-AI TODO/task-board/handoff document.
>
> Repository: `llocphann/Hadalis`  
> Working branch: `dev` only; never mutate `stable`.  
> Last pre-write repository audit HEAD: `e2e23fba59866f1b2e649370f215fd03fb96afb9`.
>
> This file is the only **planning/status** document for Wull AI. Normal implementation source, tests, fixtures and generated benchmark outputs may exist elsewhere in the repository as needed; they must not become competing planning documents.
>
> The existing Wull visual/animation plan remains separate product work. AI must consume/publish semantic state without duplicating or replacing the deterministic visual engine.

## 0. Current decision snapshot

**Current phase:** P0.5 — downloaded-model verification + isolated runtime baseline  
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
- [ ] Verify the exact local GGUF filenames/quantizations actually downloaded.
- [ ] Record SHA-256 for each local model artifact in benchmark evidence.
- [ ] Verify the LFM-compatible `mmproj` file is present.
- [ ] Pin the exact `llama.cpp` revision/build used for all baseline numbers.

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

Start small:

- Reflex: minimum context that reliably supports one screenshot + compact instruction/result.
- Brain normal: 4K–8K.
- Brain extended: 16K only when retrieval/planning actually needs it.
- Very long context is not a default feature merely because the model supports it.

KV/cache memory must be included in every resource table.

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
- [ ] If available, compare LFM `UD-Q5_K_XL`, `Q6_K`, `UD-Q6_K_XL` only on the same exact suite before claiming the extra memory is worthwhile.

**Exit gate:** one command can reproduce the baseline on a known machine and outputs evidence sufficient to compare configs.

### P2 — Rust agent/model-manager skeleton

- [ ] Audit current native workspace patterns.
- [ ] Add the new Rust sidecar using established workspace conventions.
- [ ] Implement request IDs, cancellation, timeouts, bounded logs.
- [ ] Implement process supervision for inference runtime.
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

Runtime must validate files before treating them as usable.

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
