# Shared Local and Cloud AI task policy

Work directly on `dev` in one agent context. Refetch before audits, writes and
ref updates, preserve concurrent work, and push atomic milestones.

This policy is mandatory for **Local and Cloud development AI**. The folder name
is historical; both environments read/write the same three lists through
[to-do/README.md](../README.md). Apply it when receiving a request, starting or
resuming work, and finishing a milestone. Execution location does not change
classification, priority or acceptance requirements.

| Order | Category | Scope |
| --- | --- | --- |
| 1 | [Issues/bugs](ISSUES.md) | Broken behavior, regressions, actionable warnings and correctness/release checks. Fix urgent failures first. |
| 2 | [Rework/optimization](REWORK_OPTIMIZATION.md) | Redesign existing behavior, simplify UI/docs, reduce CPU/RAM/GPU and improve responsiveness. |
| 3 | [New features](NEW_FEATURES.md) | Capabilities that the product does not yet provide, including feature delivery still awaiting acceptance. |

## Every incoming request

1. Read the latest instruction and current task lists before implementing.
   Automatically record actionable requests on receipt, even when the maintainer
   does not mention TODO or a category. A plain question/status query needs an
   answer; create/update a task only when it adds work, a defect or a constraint.
2. Classify by the requested outcome: restore broken behavior in Issues/bugs;
   improve existing behavior/design/resources in Rework/optimization; add a
   capability in New features. For example, Music cannot play → Issues; Queue
   animation/layout changes → Rework; adding image support to Notes → New features.
   A bug in an unfinished feature still belongs in Issues, linked to its feature.
3. Split mixed requests into distinct outcomes. Search for matching active items
   and archived history, merge repeats/corrections, and retain the latest scope
   and supplied image/video/log references. Reopen a completed task only when
   new work or a regression is reported; reference its prior evidence.
4. Record the outcome, received/updated date, current state, next action,
   remaining acceptance and useful evidence in the existing category item.
   Use plain inline states such as ready, in progress or waiting for a named
   dependency. Do not append the conversation or create another task ledger.
5. Re-evaluate the selection rules below and act within authorized scope. Do not
   ask the maintainer which category to use or which routine task to do next.

Use concise items describing the required result, current state, remaining
acceptance and a useful evidence/source link. A fix implemented in source stays
open when the reported desktop behavior is unverified. Mark the remaining gate
explicitly; do not treat a test PASS as visual/hardware acceptance. A reopened
bug returns to Issues/bugs with its prior evidence linked.

## Select the next task autonomously

The maintainer's explicit immediate priority, stop or deferral comes first.
Otherwise select actionable, unresolved work in this order:

| Order | Selection within the category |
| --- | --- |
| Issues/bugs | Data/config integrity, startup/crashes, authorization or install/update failures first; then broken main functions/input; then remaining correctness, visual bugs, actionable warnings and validation failures. Use actual impact/evidence, not an alarming log label alone. |
| Rework/optimization | Work that unblocks current acceptance or improves frequently used paths; prioritize strict-lossless, evidenced resource/responsiveness gains over speculative changes or cosmetic polish. Preserve the audit's proof/measurement gates. |
| New features | Requested capabilities with clear scope and available dependencies; favor broad user value and work that unblocks other requested outcomes. |

Within comparable impact, prefer work that unblocks other tasks, then the older
unresolved request. File position and message recency alone do not determine
priority. Group closely related repairs only when they share a technical purpose.
Do the minimum prerequisite needed for a selected higher-priority task, then
return to it; do not use the dependency to expand into unrelated feature work.

A task is actionable when its next meaningful step can be performed with current
access, dependencies and authorization. A source fix awaiting owner desktop,
hardware or unavailable evidence stays open with that exact dependency recorded.
Continue another actionable Issue; only when no Issue can advance, move to Rework,
then New features. Recheck waiting items on relevant new evidence. Never treat
waiting as completion or change the category to bypass priority.

If a new request arrives during work, classify/update it immediately and reassess.
Switch promptly for an explicit priority or critical failure; otherwise finish a
safe atomic milestone before switching. After each milestone, update the affected
item with its result and remaining gate, then select the next authorized task.
A generic "continue" resumes this process without asking for a task choice or
stopping at a plan/offer while actionable authorized work remains.

Ask only for genuinely missing information or required authorization that blocks
the chosen step; continue independent authorized work while waiting. If all
remaining work depends on external input, report the precise dependency rather
than inventing new scope or claiming completion.

## Completion and archives

Record the completion date and bounded validation when a task is fully complete.
Keep recent completed items in their category for seven days, then move them
to a dated file under `docs/archive/chatbot/`. Review this on every continuation
and before a checkpoint. Archive immediately superseded duplicates and retired
plans after carrying their unresolved requirements into the active categories.
Never archive an unresolved acceptance gate as completed merely because its
source patch is old.

Preserve valid maintainer/concurrent status edits. A checked item without a known
completion date is not yet eligible for age-based archiving; retain it until the
date can be established instead of inventing a date from a source commit.

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
