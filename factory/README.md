# factory

A small, project-agnostic port of [`vizopsai/async_compiler_factory`](https://github.com/vizopsai/async_compiler_factory).
Same coordination model (N parallel CLI-agent containers sharing a bare git
repo) — but the project, the toolchain, the gate, **and the agent** are all
configured in `factory.yaml` instead of hardcoded.

## What's different from ACF

1. **`factory.yaml` is the only per-project surface.** Target description,
   seed repo, gate, agent count, duration, toolchain, agent kind — all here.
2. **Pluggable agent.** `agent.kind: codex | claude-code`. The dispatcher
   (`scripts/run_agent.sh`) hides the choice from everything else.
3. **Pluggable gate.** Either:
   - `shell`: a command (e.g. `cargo test`); exit 0 means pass.
   - `judge`: a **fresh agent session in a sandboxed tmpdir** that sees only
     `criteria.txt` + `diff.patch` and writes `verdict.json`. Same agent kind
     as the worker, but a separate process with no shared CLI history and no
     view of the worker's repo, prompt, or scratchwork.

No API calls anywhere. The harness only ever spawns CLI sessions.

## What's the same as ACF

- `upstream.git/` bare repo as the only coordination mechanism.
- `current_tasks/*.txt` lock protocol.
- `ideas/*.txt` backlog.
- Per-agent container, fresh clone every cycle, push frequently.
- Time + (eventually) cost caps.

## Usage

```bash
export OPENAI_API_KEY=...           # for agent.kind=codex
# or: export ANTHROPIC_API_KEY=...  # for agent.kind=claude-code

./scripts/run.sh                    # uses factory.yaml in this dir
./scripts/run.sh path/to/other.yaml
```

`run.sh` builds the image, initializes `upstream.git/` from the seed,
launches N agents, monitors every 5 minutes, and stops on time-out.

## The two contracts

**Agent dispatcher** — `scripts/run_agent.sh PROMPT WORKDIR`
Spawns a fresh agent session of the configured kind in `WORKDIR`. That's it.
Adding a new agent type means adding `scripts/agents/<kind>.sh` and one
`case` branch in `run_agent.sh`.

**Gate** — `scripts/gate.sh`
Exits 0 (pass) or 1 (fail), prints feedback to stderr. The worker invokes
this directly before pushing. The judge variant uses `run_agent.sh` to spawn
its isolated reviewer session.

## Status

Skeleton, **not end-to-end tested.** The `codex.sh` adapter assumes
`codex exec "<prompt>"` is the headless invocation — verify against your
codex version and adjust if needed. The `claude-code` adapter is included
but not the current target.

## Layout

```
factory/
  factory.yaml             # the only per-project config
  Dockerfile               # slim base + build-arg toolchain
  CLAUDE.md.template       # rendered into upstream.git on init
  scripts/
    run.sh                 # orchestrator
    init_repo.sh           # seed -> upstream.git
    launch.sh              # docker run × N
    entrypoint.sh          # per-agent loop
    gate.sh                # shell|judge dispatch, exit-code contract
    run_agent.sh           # agent kind dispatch
    agents/
      codex.sh             # codex CLI adapter
      claude_code.sh       # claude code CLI adapter
    status.sh              # observability
  examples/
    json_parser_seed/      # toy example used by factory.yaml
```
