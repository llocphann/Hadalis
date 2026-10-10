# Optional Companion: Hadanion

Companion development has moved to [llocphann/Hadanion](https://github.com/llocphann/Hadanion). Hadalis does not ship the Companion renderer, Blender assets, behavior daemon, Companion chat service or feature-owned development tools.

Install Hadanion separately following its README, then run `inir ipc hadanion refresh` or restart Hadalis. Enable it in Settings → Companion. It is optional and remains off by default; existing settings are preserved. Hadalis can boot and use its AI tab, Todo, Obsidian and Abyss surfaces without Hadanion.

Host API 1 consists of `services/Hadanion.qml`, `modules/abyss/HadanionSurface.qml`, finite read-only discovery, an optional Settings loader and the existing surface water/input/popup lease interfaces. No core QML file statically imports an external Companion module. Loading requires a compatible, complete package, enabled preference and Abyss family. Disabling unloads the session/output objects and their native child.

Runtime discovery checks a local developer override at `optional/hadanion/`, then `${XDG_DATA_HOME:-$HOME/.local/share}/hadanion/current`. The Hadanion installer owns versioned releases and the atomic current link; Hadalis installation/update never downloads or bundles it. A system-installed Hadalis does not need write access to its shell directory to use the user package.

Compatibility remains for `abyss.companion`, `abyss.companionMind`, Settings slot 37, `wull chat/status`, Super+Alt+Comma and the private `inir/wull/chat.sqlite3` transcript. These retained names do not mean the implementation still belongs to Hadalis.

General GGUF discovery/supervision now lives in `scripts/ai/` and remains available to the AI tab. Hadanion uses the shared text-session API and explicit journal helper inputs. User journal paths and permissions are unchanged.

Companion work is now centrally tracked in
[Alis dev TODO](../to-do/README.md), including visual/AI implementation
and host acceptance. Alis-Companion retains the implementation source,
technical contracts, evidence and immutable prior-checklist snapshots,
but no separate active planning/status queue.
