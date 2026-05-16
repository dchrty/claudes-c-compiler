# factory

A small, project-agnostic port of [`vizopsai/async_compiler_factory`](https://github.com/vizopsai/async_compiler_factory).
Same coordination model (N parallel Claude Code agents in containers, sharing a
bare git repo) — but the project, the toolchain, and the gate are all
configured in `factory.yaml` instead of hardcoded.

## What's different from ACF

1. **`factory.yaml` is the only per-project surface.** Target description,
   seed repo, gate, agent count, duration, toolchain — all here.
2. **Pluggable gate.** Either:
   - `shell`: a command (e.g. `cargo test`); exit 0 means pass.
   - `judge`: an LLM-as-judge in an *isolated* session — fresh API call, no
     view of the worker's reasoning, only the diff and the criteria.
3. **Slim, extensible Dockerfile.** Build args carry `apt` packages and
   toolchain choices through from `factory.yaml`.

## What's the same

- `upstream.git/` bare repo as the only coordination mechanism.
- `current_tasks/*.txt` lock protocol.
- `ideas/*.txt` backlog.
- Per-agent container, fresh clone every cycle, push frequently.
- Time + (eventually) cost caps.

## Usage

```bash
export ANTHROPIC_API_KEY=sk-...
./scripts/run.sh                   # uses factory.yaml in this dir
./scripts/run.sh path/to/other.yaml
```

`run.sh` builds the image, initializes `upstream.git/` from the seed,
launches N agents, monitors every 5 minutes, and stops on time-out.

```bash
./scripts/status.sh           # peek at the fleet
./scripts/status.sh --short
```

## The gate contract

`scripts/gate.sh` is the only thing the worker agent invokes. It:
- exits **0** for pass, **1** for fail
- prints feedback to stderr

That's the whole interface. Adding a new gate type means adding a `case`
branch in `gate.sh` that respects this contract.

## Status

Skeleton. The pieces are in place and mirror ACF's working pattern, but
**this hasn't been end-to-end tested yet** — there's no Docker daemon in
the environment it was authored in. Expect to need to fix at least:
- `yq` flavor differences (script assumes `mikefarah/yq` v4 syntax)
- the example seed compiles but is intentionally trivial; pick a target
  that's actually interesting before drawing conclusions
- judge model name (`claude-opus-4-7`) — adjust to whatever you have access to

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
    entrypoint.sh          # per-agent loop (mirrors ACF)
    gate.sh                # dispatch shell|judge, honor exit-code contract
    judge.py               # LLM-as-judge in an isolated API session
    status.sh              # observability
  examples/
    json_parser_seed/      # toy example used by factory.yaml
```
