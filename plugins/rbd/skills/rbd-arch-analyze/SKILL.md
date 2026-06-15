---
name: rbd-arch-analyze
description: >
  Runs a full architectural analysis of the target project. Invoke when
  the user types /rbd-arch-analyze, asks to "analyze the architecture",
  "check code coherence", "generate architecture diagrams", or "detect
  mismatches between code and requirements". Dispatches the arch-analyst
  agent with full project context (requirements, architecture.md, and
  source code). Produces a timestamped analysis report in docs/.
---

# RBD Architecture Analysis

This skill is **read-only with respect to project requirements,
architecture, and source code**. It dispatches the `arch-analyst` agent
and confirms the output path to the user.

## Gather Context

Before dispatching the agent, collect the following context from the
target project:

1. Read all `requirements/*.md` files and pass them as context.
2. Read `docs/architecture.md` if it exists and pass it as context.
3. Identify the source code root (look for common directories: `src/`,
   `lib/`, `app/`, or files at the project root).
4. Pass the current working directory so the agent can locate all
   project files.

## Dispatch arch-analyst

Launch the `arch-analyst` agent using the Agent tool. This is a named
Claude Code agent installed at `.claude/agents/arch-analyst.md`.

Invoke with `subagent_type: "claude"` and use the agent file's content
as the prompt, or dispatch by agent name if your Claude Code version
supports named agent dispatch.

Pass as context:

- The full content of all `requirements/*.md` files.
- The full content of `docs/architecture.md` (or a note that it is
  absent).
- The path to the source code root so the agent can scan files.
- Today's date in `YYYY-MM-DD` format (used for the output filename).

Wait for the agent to complete and write `docs/analysis-YYYY-MM-DD.md`.

## Confirm Output

After the agent completes:

1. Verify that `docs/analysis-YYYY-MM-DD.md` was created.
2. Tell the user: "Architecture analysis complete. Report saved to
   `docs/analysis-YYYY-MM-DD.md`."
3. Summarize the number of diagrams produced and the number of
   mismatches found (if any).

If the agent fails or the file is not created, report the error to the
user and do not retry automatically.
