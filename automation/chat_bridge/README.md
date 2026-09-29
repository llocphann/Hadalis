# Hadalis Chat Bridge

This directory is the deterministic control layer between ChatGPT Desktop and the Hadalis repository workflow.

## Non-negotiable architecture

- **ChatGPT is the only reasoning agent.**
- The bridge does not choose commands, generate patches, interpret failures semantically, alter goals, or decide development steps.
- The local worker executes only explicit jobs written by ChatGPT and returns mechanical evidence.
- GitHub/repository state is the durable source of truth.
- Desktop/session state such as CDP targets, PIDs, retry counters, and conversation identifiers stays local and must not be committed.

## Autonomous prompt contract

Every automatically injected prompt starts with the literal connector mention:

```text
[@GitHub](plugin://github@openai-curated-remote)
```

The prompt then requires ChatGPT to verify access to `llocphann/Hadalis` and fetch the current `dev` HEAD before reasoning from repository state. If GitHub is unavailable, expired, disconnected, or lacks access, ChatGPT emits:

```text
HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB
```

The bridge must stop automatic resubmission in that state; otherwise an expired connector would create a retry loop.

## Loop markers

A completed assistant response contains exactly one machine-readable marker:

```text
HADALIS_LOOP:WAIT_RESULT JOB-000127
HADALIS_LOOP:CONTINUE
HADALIS_LOOP:ROTATE
HADALIS_LOOP:DONE
HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB
```

`protocol.py` parses the marker. `controller.py` maps it to a deterministic state transition. Neither module interprets repository contents or decides what development work should happen next.

## Desktop action policy

The production controller should prefer these mechanisms in order:

1. semantic DOM discovery and activation through CDP;
2. a verified internal Electron command/IPC action when it is more stable than DOM;
3. niri focus plus native Wayland input as a fallback;
4. coordinate clicking is not part of the normal control path.

Known ChatGPT Desktop observations from the local feasibility probes:

- main renderer: exact URL `app://-/index.html`;
- project new-chat control: `New chat in Hadalis Cloud`;
- valid main composer labels include `Ask ChatGPT` and `New chat in Hadalis Cloud`;
- Send is exposed as an enabled/disabled semantic button;
- generation start is observable through a Stop control;
- generation end is observable when Stop disappears and Regenerate response becomes available.

Selectors must be verified by postconditions rather than assumed to remain valid forever.
