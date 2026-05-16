#!/usr/bin/env python3
"""LLM-as-judge gate, in an isolated context.

Isolation guarantees:
  * Brand-new Anthropic API session — no conversation history with the worker.
  * Sees only: the criteria + the working-tree diff. Not the worker's prompt,
    not its tool calls, not its scratchwork.
  * Runs in this subprocess — no env vars or files leak from the worker
    beyond what we explicitly pass.

Output contract (matches gate.sh):
  * stderr: human-readable feedback for the worker
  * exit 0 = pass, exit 1 = fail
"""
import json, os, subprocess, sys
import yaml
from anthropic import Anthropic

config_path, workspace = sys.argv[1], sys.argv[2]
cfg = yaml.safe_load(open(config_path))["gate"]
criteria = cfg["criteria"]
model = cfg.get("model", "claude-opus-4-7")

diff = subprocess.run(
    ["git", "-C", workspace, "diff", "upstream/main", "--", ".",
     ":(exclude)current_tasks", ":(exclude)ideas"],
    capture_output=True, text=True
).stdout[-12000:]

if not diff.strip():
    print("No changes to evaluate.", file=sys.stderr)
    sys.exit(1)

client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
msg = client.messages.create(
    model=model,
    max_tokens=1024,
    system="You are an isolated reviewer. You have no context beyond the "
           "criteria and diff below. Be strict but fair; the worker cannot "
           "argue with you.",
    messages=[{"role": "user", "content": f"""Criteria:
{criteria}

Diff (against upstream/main):
```
{diff}
```

Reply with ONLY a JSON object on a single line:
{{"pass": <true|false>, "feedback": "<actionable text; if pass, briefly say why; if fail, say exactly what to fix>"}}"""}],
)

text = msg.content[0].text.strip()
start, end = text.find("{"), text.rfind("}")
verdict = json.loads(text[start:end+1])

print(verdict["feedback"], file=sys.stderr)
sys.exit(0 if verdict["pass"] else 1)
