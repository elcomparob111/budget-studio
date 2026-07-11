# Budget Studio — working rules

Read `AGENTS.md` first; start from docs, open source files only when implementing.

## Token efficiency (same rule as OpenClaw/PinPilot)

- Invoke the `token-efficient-workflow` skill at session start for any substantive task.
- Don't explore the repo broadly — the docs in `AGENTS.md` are the map. Delegate open-ended research to a subagent that reports back conclusions only.
- Filter command output (grep for failures) before it enters context; never dump full logs or test runs.
- Ask the user for the specific file/goal/verify-step if the prompt is vague, instead of wide exploration.
- Keep replies lean: outcome first, no restating file contents back.
- Mechanical "do X to file Y" tasks are Sonnet jobs — suggest the user switch model down (and `/clear` between unrelated tasks, `/compact` after a completed phase) when it would save tokens.
