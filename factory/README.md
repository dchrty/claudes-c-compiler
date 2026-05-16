# factory

A small, project-agnostic port of [`vizopsai/async_compiler_factory`](https://github.com/vizopsai/async_compiler_factory).
Same coordination model (N parallel CLI-agent containers sharing a bare git
repo) — but the project, the toolchain, the gate, **and the agent** are all
configured in `factory.yaml`.

## How you set up a new project

You write **two markdown files and one yaml**:

1. `CLAUDE.md.template` — what the worker agents do in their ralph loop
   (the existing one is a sane default; usually just edit `${TARGET}`).
2. `factory.yaml` — pick the agent, gate type, fleet size, toolchain.
3. (only if `gate.type: judge`) `JUDGE.md.template` — the rubric the
   reviewing agent applies.

That's the whole authoring surface.

## The two gate paths

You pick one of these in `factory.yaml`:

```yaml
gate:
  type: shell
  cmd: "cargo test --release 2>&1 | tail -50"
```

This is the simplest case — your test suite *is* the truth. No second agent.
The worker's ralph loop runs the command and trusts the exit code.

```yaml
gate:
  type: judge
  criteria_md: ./JUDGE.md
```

For things you can't easily test (architectural fit, prompt quality,
"is this design reasonable"). A fresh agent session is spawned in a
sandboxed tmpdir containing only `JUDGE.md` + `diff.patch`. It writes
`verdict.json` and exits. The worker has no way to bias it; the judge
has no view of the worker's reasoning, repo, or prompt.

The `JUDGE.md` itself is rendered from `JUDGE.md.template` into the
seed at init time, so it travels with the repo.

## Pluggable agent

`agent.kind` in `factory.yaml`:

- `codex` — current target. Uses `codex exec "<prompt>"`.
- `claude-code` — adapter present, not the current focus.

Adding a new agent kind = drop a script in `scripts/agents/<kind>.sh`
implementing the contract `<kind>.sh PROMPT WORKDIR`, then add one
`case` branch to `scripts/run_agent.sh`. The dispatcher hides the
choice from everything else, including the gate.

## Usage

```bash
export OPENAI_API_KEY=...           # for agent.kind=codex
# or: export ANTHROPIC_API_KEY=...  # for agent.kind=claude-code

./scripts/run.sh                    # uses factory.yaml in this dir
./scripts/run.sh path/to/other.yaml
```

## Host prerequisites

- `docker`
- `yq` (mikefarah/yq v4)
- `gettext` (provides `envsubst` — used by `init_repo.sh` to render templates)

## What's the same as ACF

- `upstream.git/` bare repo as the only coordination mechanism.
- `current_tasks/*.txt` lock protocol.
- `ideas/*.txt` backlog.
- Per-agent container, fresh clone every cycle, push frequently.
- Time + (eventually) cost caps.

## Status

Skeleton, **not end-to-end tested.** The `codex.sh` adapter assumes
`codex exec "<prompt>"` is the headless invocation — verify against your
codex version and adjust if needed.

## Layout

```
factory/
  factory.yaml             # the only per-project config
  Dockerfile               # slim base + build-arg toolchain
  CLAUDE.md.template       # worker job description
  JUDGE.md.template        # judge rubric (only used when gate.type: judge)
  scripts/
    run.sh                 # orchestrator
    init_repo.sh           # render templates, seed -> upstream.git
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
