from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import re

GITHUB_MENTION = "[@GitHub](plugin://github@openai-curated-remote)"
REPOSITORY = "llocphann/Hadalis"
BRANCH = "dev"

CONTINUATION_PROMPT = f"""\
{GITHUB_MENTION}

Continue Hadalis autonomously.

GitHub repository:
- repo: {REPOSITORY}
- branch: {BRANCH}

GitHub is the authoritative remote source of truth.

At the start of this turn:
1. Use the GitHub connector explicitly.
2. Verify that the connector is available and can access {REPOSITORY}.
3. Fetch the current {BRANCH} HEAD. Do not rely on a HEAD remembered from a previous turn.
4. Read the current repository state required for the next reasoning step.
5. Read the newest local execution result if one exists.
6. Continue from agent/WORK.md and agent/SESSION.md when those files exist.

ChatGPT is the ONLY reasoning agent.
The local worker must only execute explicit deterministic jobs.

Do not ask the user to type "continue".
Perform the next reasoning step now.

If the GitHub connector is unavailable, expired, disconnected, or lacks access:
- do not substitute web search,
- do not guess repository state,
- do not continue development from stale repository context,
- emit exactly:

HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB
"""

ROTATION_BOOTSTRAP_PROMPT = f"""\
{GITHUB_MENTION}

Continue the autonomous Hadalis development session.

Repository:
{REPOSITORY}
Branch:
{BRANCH}

The repository is the durable source of truth.

First verify GitHub connector access and fetch the current {BRANCH} HEAD.

Then read, when present:
1. AGENTS.md
2. agent/README.md
3. agent/CONTEXT.md
4. agent/WORK.md
5. agent/SESSION.md

Resume exactly from the recorded checkpoint.

ChatGPT is the ONLY reasoning agent.
Do not ask the user to continue.

If GitHub connector access is unavailable, do not use stale repo state and emit:

HADALIS_LOOP:CONNECTOR_BLOCKED GITHUB
"""


class DirectiveKind(str, Enum):
    WAIT_RESULT = "WAIT_RESULT"
    CONTINUE = "CONTINUE"
    ROTATE = "ROTATE"
    DONE = "DONE"
    CONNECTOR_BLOCKED = "CONNECTOR_BLOCKED"


@dataclass(frozen=True)
class LoopDirective:
    kind: DirectiveKind
    argument: str | None = None


class ProtocolError(ValueError):
    pass


_MARKER_RE = re.compile(
    r"^HADALIS_LOOP:(WAIT_RESULT|CONTINUE|ROTATE|DONE|CONNECTOR_BLOCKED)"
    r"(?:[ \t]+([A-Za-z0-9._/-]+))?[ \t]*$"
)


def parse_loop_directive(response_text: str) -> LoopDirective:
    """Parse exactly one Hadalis loop marker from a completed assistant response."""
    matches: list[LoopDirective] = []

    for raw_line in response_text.splitlines():
        line = raw_line.strip()
        match = _MARKER_RE.fullmatch(line)
        if match is None:
            continue

        kind = DirectiveKind(match.group(1))
        argument = match.group(2)

        if kind is DirectiveKind.WAIT_RESULT:
            if not argument:
                raise ProtocolError("WAIT_RESULT requires a job id")
        elif kind is DirectiveKind.CONNECTOR_BLOCKED:
            if argument != "GITHUB":
                raise ProtocolError("CONNECTOR_BLOCKED requires GITHUB")
        elif argument is not None:
            raise ProtocolError(f"{kind.value} does not accept an argument")

        matches.append(LoopDirective(kind=kind, argument=argument))

    if not matches:
        raise ProtocolError("assistant response contains no HADALIS_LOOP marker")
    if len(matches) != 1:
        raise ProtocolError("assistant response must contain exactly one HADALIS_LOOP marker")

    return matches[0]


def prompt_has_required_github_mention(prompt: str) -> bool:
    """The connector mention must be the first non-empty line of every autonomous prompt."""
    first = next((line.strip() for line in prompt.splitlines() if line.strip()), "")
    return first == GITHUB_MENTION
