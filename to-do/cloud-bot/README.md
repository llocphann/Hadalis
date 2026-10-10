# Chatbot task index

Work directly on `dev` in one agent context. Refetch before audits, writes and
ref updates, preserve concurrent work, and push atomic milestones.

| Order | Category | Scope |
| --- | --- | --- |
| 1 | [Issues/bugs](ISSUES.md) | Broken behavior, regressions, actionable warnings and correctness/release checks. Fix urgent failures first. |
| 2 | [Rework/optimization](REWORK_OPTIMIZATION.md) | Redesign existing behavior, simplify UI/docs, reduce CPU/RAM/GPU and improve responsiveness. |
| 3 | [New features](NEW_FEATURES.md) | Capabilities that the product does not yet provide, including feature delivery still awaiting acceptance. |

## Every incoming request

Classify it automatically when received. Split a mixed message into the relevant
categories and merge a repeated request into the existing item. Preserve the
maintainer's latest correction and any supplied image/video/log reference.
Do not append the conversation or create a second task ledger.

Use concise items describing the required result, current state, remaining
acceptance and a useful evidence/source link. A fix implemented in source stays
open when the reported desktop behavior is unverified. Mark the remaining gate
explicitly; do not treat a test PASS as visual/hardware acceptance. A reopened
bug returns to Issues/bugs with its prior evidence linked.

Default priority is **Issues/bugs → Rework/optimization → New features**. An
explicit maintainer instruction may change the immediate priority. A blocked
owner/hardware check does not prevent independent authorized work.

## Completion and archives

Record the completion date and bounded validation when a task is fully complete.
Keep recent completed items in their category for seven days, then move them
to a dated file under `docs/archive/chatbot/`. Review this on every continuation
and before a checkpoint. Archive immediately superseded duplicates and retired
plans after carrying their unresolved requirements into the active categories.
Never archive an unresolved acceptance gate as completed merely because its
source patch is old.

[Archive index](../../docs/archive/README.md) holds historical task snapshots,
retired designs and completed migration notes. Existing evidence, screenshots,
source pins and consumed receipts keep their original paths and status. Old
ABYSS/OPTIMIZATION/RELEASE files are short link-compatibility pointers only.

## Research and external repositories

[Optimization research](../../docs/optimization/README.md) remains technical
reference, separate from task status. Resumed product work authorizes the
requested strict-lossless implementations after parity/measurement gates;
research-only findings are not automatically approved runtime changes.

[Hadalird](https://github.com/llocphann/Hadalird) owns optional TLP, Thinkfan and
Obsidian implementation. [Hadanion](https://github.com/llocphann/Hadanion) owns
Companion design/animation and AI tasks. Hadalis owns their host/package UI and
shared APIs. Use the owning repo's current task entry for implementation there.

Only the **five-hour** limit remaining below 3% triggers checkpoint/push and
a single continuation at that window's reset plus three minutes. Weekly usage
does not trigger stopping or scheduling. Do not use reset credits.
