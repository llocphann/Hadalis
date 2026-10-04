# Wull Local AI / Desktop Agent — Canonical TODO

> **Single source of truth for Wull local-AI work.** All future planning, status updates, design changes, model/runtime decisions, benchmark results, fine-tuning/distillation notes, and acceptance evidence for this effort MUST be edited into this file only. Do not create additional Wull-AI TODO/task-board/handoff files.
>
> Repository: `llocphann/Hadalis`  
> Working branch: `dev` only; never mutate `stable`.  
> Created from dev HEAD: `77dbd3ad0f21cb6177225989d4cd7e3128c32e15`.
>
> This plan is specifically for the AI/agent subsystem. The existing visual/animation Wull Companion plan remains separate product work; do not duplicate its visual requirements here.

## 1. Objective

Build Wull as a native local desktop companion/agent that can:

- converse naturally in English and Vietnamese;
- understand user intent and choose deterministic tools;
- find/read/create/edit/copy/move/rename files as authorized;
- audit system/process/service state and summarize results;
- use clipboard, app-launch, Git, Quickshell/Hadalis IPC, DBus/compositor/system APIs where available;
- inspect screenshots/UI when a vision-capable model is selected;
- assist with Rust (highest coding priority), Quickshell/QML, JavaScript/CSS, C/C++, and Python;
- remain useful offline;
- avoid giving the LLM unrestricted shell/system authority.

Wull does **not** need heavyweight general reasoning for normal desktop tasks. Prefer deterministic Rust tools for execution and reserve model capacity for language understanding, tool selection, response generation, vision, and bounded planning.

UI localization remains English-only per `AGENTS.md`; EN/VN here means Wull conversational model input/output, not a second application translation catalog.

## 2. Architecture contract

Target production architecture:

```text
Wull / Quickshell UI
        |
        | IPC (prefer Unix socket / native IPC)
        v
wull-agent / Wull AI orchestration (Rust)
        |
        +-- Tool Router / Permission Policy
        +-- Context + Memory
        +-- RAG / repository + documentation index
        +-- Model Manager
        +-- Resource Manager
        |
        v
Existing inference runtime
        |
        +-- initial: llama-server
        +-- production candidate: libllama / llama.cpp
        |
        v
Local GGUF model
```

Training path:

```text
Teacher model(s)
   -> verified dataset
   -> Unsloth / compatible SFT, QLoRA, distillation pipeline
   -> student checkpoint
   -> export/quantize GGUF
   -> llama.cpp production inference
```

### Non-goals

- Do not implement matrix kernels, tokenizer inference, KV-cache logic, quantization, or GPU kernels from scratch.
- Do not make Ollama or LM Studio a mandatory production dependency.
- Do not let the model emit arbitrary shell commands that are executed without policy validation.
- Do not encode current repository contents or rapidly changing docs into weights when RAG/tool lookup is more appropriate.
- Do not couple the Quickshell process directly to model lifetime such that an inference crash takes down the desktop shell.

## 3. Runtime decisions

### Required

- [ ] Implement Wull-specific orchestration in Rust.
- [ ] Start integration using an existing inference runtime, preferably `llama.cpp`.
- [ ] Prototype through `llama-server` or equivalent stable local API before considering direct `libllama` FFI.
- [ ] Keep the Wull-side model API backend-neutral enough to swap runtimes/models without rewriting tool logic.
- [ ] Isolate inference in a sidecar/service boundary until crash recovery and resource behavior are proven.
- [ ] Add clean model load/unload/reload and failure recovery.
- [ ] Add configurable context/KV limits and model resource budgets.

### Development-only alternatives

Ollama and LM Studio may be used for quick model comparison/prototyping, but production must not require the user to install or manually keep either application running.

## 4. Initial model candidates

Do not choose by reputation alone. Benchmark candidates against the Wull suite before locking one in.

- [ ] **LFM2.5-VL-3B** — primary candidate when desktop vision, screenshot understanding, UI grounding, OCR, low latency, and function calling matter most.
- [ ] **Qwen3.5-4B** — primary comparison candidate when coding/Rust and stronger general reasoning matter more.
- [ ] Keep room for future 2B–4B replacements; the architecture must treat the model as replaceable.

Initial production quantization target: Q4/Q5-class GGUF, selected by measured quality/latency/RAM rather than file size alone.

## 5. Hardware/resource budget

Reference development machine:

- Ryzen 5 PRO 7540U, 6C/12T
- Radeon 740M integrated GPU
- ~18 GB system RAM
- 30 GB swap (fallback only; never treat swap as normal LLM memory)

Initial Wull budget:

- student/model class: preferably 2B–4B;
- production model artifact target: ~1.5–3.5 GB where practical;
- AI subsystem working RAM target: <= 4–6 GB under normal use;
- normal context target: 4K–8K;
- larger context: opt-in/on-demand, e.g. 16K when justified;
- prefer Vulkan/CPU hybrid acceleration after correctness is proven;
- idle Wull must not continuously generate/infer.

Performance acceptance must measure: cold load, warm first-token latency, tokens/sec, peak RSS, idle RSS, CPU/GPU usage, temperature/power impact, and recovery after model/runtime failure.

## 6. Tool layer

Define typed, schema-validated tools. Initial families:

- [ ] `filesystem.search/read/write/create/copy/move/rename`
- [ ] `clipboard.get/set`
- [ ] `process.list/status/start/stop`
- [ ] `system.audit/status/logs`
- [ ] `app.launch/focus/close`
- [ ] `git.status/diff/log/... ` with narrowly scoped write actions
- [ ] Quickshell/Hadalis IPC tools
- [ ] DBus/systemd/native Linux integration where appropriate
- [ ] compositor/window/workspace tools when supported
- [ ] screenshot/screen-inspection input path for vision models

Prefer, in order:

1. Hadalis/Quickshell native IPC/API
2. DBus/system APIs
3. compositor IPC
4. application-specific CLI/API
5. accessibility interfaces
6. mouse/keyboard simulation only as fallback
7. vision-driven pointer control only when no reliable structured interface exists

## 7. Permissions and safety

Tool execution is owned by Rust policy, not by the LLM.

Suggested tiers:

- **Tier A — read/low impact:** search/read/list/status; may run automatically.
- **Tier B — reversible mutation:** edit/copy/move/app/process/settings changes; obey explicit policy and provide clear result.
- **Tier C — destructive/privileged:** delete, sudo/root changes, package removal, security-sensitive settings, destructive Git operations; require explicit user confirmation.

Required controls:

- [ ] path canonicalization and traversal protection;
- [ ] allow/deny scopes per tool;
- [ ] structured argument validation;
- [ ] bounded output/log capture;
- [ ] timeout/cancellation;
- [ ] no arbitrary unreviewed `bash -c` execution;
- [ ] auditable action/result records without storing secrets unnecessarily.

## 8. Benchmark before training

Do **not** fine-tune or distill until a reproducible baseline exists.

Create an evaluation set of roughly 200–500 representative tasks, then grow it over time. Categories should include:

- filesystem + clipboard;
- desktop/app/tool selection;
- system audit;
- Git;
- Rust;
- Quickshell/QML;
- JavaScript/CSS;
- C/C++;
- Python;
- EN/VN conversation;
- error recovery;
- screenshot/UI grounding if a VLM is used;
- safety/permission refusal and confirmation cases.

Track at minimum:

- exact tool-selection accuracy;
- argument/schema accuracy;
- task completion rate;
- unsafe-action rate;
- hallucination rate;
- code compile/test success where applicable;
- EN/VN response quality;
- vision grounding accuracy where applicable;
- latency/RAM/power metrics.

A new model/runtime/configuration must beat or intentionally trade against the canonical benchmark before replacement.

## 9. Data strategy

Keep knowledge assets separate from model weights.

### Fine-tune / SFT / LoRA for

- Wull behavior/personality;
- tool selection and structured calls;
- Hadalis conventions/workflows;
- preferred Rust patterns/style;
- recovery behavior;
- concise EN/VN interaction style;
- stable domain behaviors that benefit from being internalized.

### RAG/tool lookup for

- current Hadalis repository contents;
- Quickshell/Qt/Rust/C/C++/Python/JS/CSS documentation;
- current system state;
- changing APIs/configuration;
- logs and runtime evidence.

### Dataset record

For useful interactions, record a sanitized training/evaluation form of:

```text
request
relevant context
expected/selected tool
tool arguments
tool result
final response
PASS/FAIL + reason
```

Do not treat raw conversation history as training data without filtering and verification.

## 10. Training and fine-tuning sequence

### Phase T0 — no training

- [ ] Run base candidates unchanged.
- [ ] Add tools, RAG, resource controls, and benchmark.
- [ ] Identify actual failure modes before changing weights.

### Phase T1 — SFT / LoRA / QLoRA

Begin only after enough high-quality examples exist.

Train primarily for:

- tool calling;
- Wull conversational behavior;
- Rust/Hadalis coding conventions;
- Quickshell workflows;
- recovery from tool errors.

Use Unsloth or another compatible training stack as tooling, not as a mandatory production runtime.

### Phase T2 — verified distillation

Only after benchmark + validators are mature:

```text
large teacher(s)
 -> generate candidate examples
 -> schema validation
 -> compiler/tests/tool simulation
 -> deduplicate/filter
 -> accepted Wull dataset
 -> student 2B–4B
```

Teacher models do not need to fit on the Wull laptop; they may run on another machine/cloud/API during dataset generation.

For code-generated training data, automatically validate wherever possible (e.g. Rust compile/tests/clippy; Python tests/lint/type checks; C/C++ compiler/tests; structured tool schemas).

## 11. Long-term distillation/model replacement policy

The durable asset is **dataset + benchmark + validators + RAG corpus + tool contracts**, not one specific model.

When a better teacher appears:

- keep verified old data;
- use the new teacher to review/repair weak samples;
- generate missing/harder cases;
- re-run validation;
- train the next student.

When a better student architecture appears:

- reuse the canonical Wull dataset and benchmark;
- retrain/distill into the new base;
- do not attempt to port incompatible LoRA weights blindly.

Production model size must not grow automatically with dataset size. Keep a fixed deployment budget and periodically consolidate/merge/re-distill rather than stacking endless adapters.

## 12. Versioning inside this single file

Do not create separate planning files per version. Maintain state here.

When work begins, update these fields:

- **Current phase:** P0 — planning/baseline
- **Current runtime:** undecided; `llama.cpp` target
- **Current baseline model:** undecided
- **Current student:** none
- **Current teacher(s):** none
- **Dataset revision:** none
- **Benchmark revision:** none
- **Last verified dev SHA:** `77dbd3ad0f21cb6177225989d4cd7e3128c32e15`
- **Last plan update:** 2026-10-04

For every significant change, update the relevant sections and the status/checklist below rather than creating another TODO.

## 13. Implementation phases

### P0 — Research/baseline definition

- [x] Decide to use an existing LLM inference engine rather than writing one from scratch.
- [x] Separate Wull Rust orchestration from inference runtime.
- [x] Select `llama.cpp` as the primary production runtime candidate.
- [x] Select Unsloth/compatible tooling for training/fine-tuning/distillation experiments, not production dependency.
- [x] Define initial model candidates: LFM2.5-VL-3B and Qwen3.5-4B.
- [ ] Verify exact model licenses, llama.cpp support, vision path, tokenizer/chat templates, and tool-call behavior before implementation lock-in.
- [ ] Establish reproducible benchmark harness and baseline results.

### P1 — Agent/tool skeleton

- [ ] Define Rust service/crate boundaries.
- [ ] Define IPC contract between Wull UI and AI service.
- [ ] Define typed tool schemas and permission policy.
- [ ] Implement read-only filesystem/system tools first.
- [ ] Add structured logging/error/result envelopes.
- [ ] Add cancellation/timeouts.

### P2 — Local inference

- [ ] Integrate `llama-server` or equivalent sidecar.
- [ ] Benchmark CPU-only and Radeon 740M/Vulkan paths.
- [ ] Add model/config selection.
- [ ] Add load/unload/restart recovery.
- [ ] Prove Wull UI remains functional if inference crashes.

### P3 — RAG/context

- [ ] Index current Hadalis source and selected docs without training them into weights.
- [ ] Implement bounded retrieval/context assembly.
- [ ] Add conversation memory policy.
- [ ] Measure context size/latency/RAM trade-offs.

### P4 — Desktop agent capability

- [ ] Implement safe file edit/copy/move operations.
- [ ] Add Quickshell/Hadalis native IPC actions.
- [ ] Add process/app/DBus/compositor actions as needed.
- [ ] Add confirmation flow for destructive/privileged actions.
- [ ] Add screenshot/VLM path if LFM2.5-VL or another vision model wins benchmark.

### P5 — Fine-tuning

- [ ] Collect and clean sufficient verified Wull examples.
- [ ] Establish train/validation/test split that prevents benchmark leakage.
- [ ] Run LoRA/QLoRA experiment.
- [ ] Compare against untuned baseline; reject tuning that harms core capability.
- [ ] Export/quantize and re-run production-runtime benchmark.

### P6 — Distillation

- [ ] Select teacher(s) based on verified task quality.
- [ ] Generate targeted synthetic/teacher data only where it improves coverage.
- [ ] Validate every mechanically verifiable sample.
- [ ] Train 2B–4B student.
- [ ] Compare student against generic same-size models and current Wull baseline.
- [ ] Promote only if Wull-domain gains justify any general-capability loss.

### P7 — Production hardening

- [ ] Determine final model/runtime/package layout.
- [ ] Add model integrity/version checks.
- [ ] Add safe update/rollback path.
- [ ] Confirm no Ollama/LM Studio user dependency.
- [ ] Run `bash scripts/validate-maintainer-local.sh` for the exact source SHA.
- [ ] Perform live desktop acceptance separately where static validation cannot cover Wayland/Quickshell behavior.

## 14. Definition of done

The first production-ready milestone is complete only when:

- Wull can run its local model without an external GUI/runtime application;
- inference failure does not crash Quickshell/Wull UI;
- common Wull actions use typed deterministic tools;
- destructive/privileged actions are permission-gated;
- benchmark results are recorded and reproducible;
- EN/VN conversation works while application localization remains English-only;
- current Hadalis/Quickshell knowledge is primarily retrieved dynamically rather than frozen into stale weights;
- model/runtime can be replaced without rewriting the desktop tool layer;
- production resource usage is acceptable on the reference 7540U/740M/~18 GB RAM machine;
- the exact source SHA passes the repository's required validation, plus separate live desktop acceptance where applicable.

## 15. Immediate next actions

1. [ ] Audit current Hadalis Rust/Quickshell boundaries and choose the least-coupled location for the Wull AI sidecar/service.
2. [ ] Specify the first version of the UI <-> agent IPC message schema.
3. [ ] Build the benchmark harness before choosing the final model.
4. [ ] Benchmark untouched LFM2.5-VL-3B and Qwen3.5-4B with the same tasks and comparable quantization/runtime settings.
5. [ ] Implement only the read-only tool subset first.
6. [ ] Record every subsequent decision, benchmark result, failure, and phase transition **in this file only**.
