# Active autonomous work

## Objective

Bring the Hadalis autonomous development loop from feasibility to a validated first end-to-end local run while preserving the rule that ChatGPT is the only reasoning agent.

## Current implementation

- deterministic loop-marker protocol and state transitions;
- mandatory GitHub connector mention in automatic prompts;
- ChatGPT Desktop CDP driver and CLI;
- crash-safe bridge runtime with persisted local state and singleton locking;
- deterministic local execution worker;
- user-service installer;
- localhost-only ChatGPT CDP host supervisor;
- regression tests for protocol/state, worker safety, and CDP host safety.

## Current gate

The repository contains pending local validation job:

`JOB-AUTOMATION-VALIDATE-001`

The next reasoning step after its result is published is to read `automation/results/JOB-AUTOMATION-VALIDATE-001.json`, fix any failures, then run the canonical maintainer validator through a new explicit worker job before the first live autonomous-loop acceptance run.
