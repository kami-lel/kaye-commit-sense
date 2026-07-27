---
name: commit-sense-via-dify AGENTS
alwaysApply: true
---

# commit-sense-via-dify AGENTS

The entire project is a single Bash script, `kaye-commit-sense-hook.sh`, that
generates Git commit messages from the staged diff via a Dify app. See
[CONTEXT.md](CONTEXT.md) for design and data flow.


## Scope

- keep all logic in one file — `kaye-commit-sense-hook.sh`
- add no runtime dependencies beyond `git`, `curl`, `jq`, and a POSIX shell
- target **Bash**, invoked as a Git commit hook

## Code Style

- start the script with `#!/usr/bin/env bash`
- enable `set -euo pipefail` near the top for safe failure
- quote all variable expansions; prefer `"${var}"` form
- read Dify credentials and endpoints from the environment, never hardcode
- give every environment variable the `KCSH_` prefix (e.g.
  `KCSH_DIFY_SERVICE_API_ENDPOINT`, `KCSH_REQUEST_TIMEOUT_SEC`); optional ones
  resolve a default inside `resolve_config`, never at the point of use
- keep visual feedback on `stderr` so it never pollutes the commit message
- give each script section its own `kamilog` logger name, `${LOGGER_ROOT}.<section>`
  (e.g. `KCSH.dify`, `KCSH.git`), and use the bare `LOGGER_ROOT` (`KCSH`) only
  at the entry point
- messages piped to `kamilog` carry no trailing newline; `kamilog` adds its own
- export `GIT_PAGER=cat PAGER=cat` near the top, before any `git` subprocess
  call, so nothing ever waits on a pager
- resolve `git`/`curl`/`jq` to absolute paths via `resolve_dependency` into
  `GIT_BIN`/`CURL_BIN`/`JQ_BIN`; call sites use these variables, never the
  bare command name
- open a `kamilog` progress line with `-N` before starting the throb widget,
  so the line stays open for the throb to animate on and `kamilog` is never
  called again per frame; see `start_generating_throb`/`stop_generating_throb`

## Testing Instructions

- lint the script: `shellcheck kaye-commit-sense-hook.sh`
- smoke-test the hook: stage a change, run `KCSH_ENABLE_SKIPPING=1 git commit`
  to verify the hook wires correctly without invoking Dify (opt-out works)
- demo fixtures live under `examples/diffs/`, each paired with a runnable
  demo script under `examples/` that sources the hook script's public stage
  functions rather than exercising them through a unit-test suite

## Security Considerations

- the staged diff is sent to an external Dify service — never log the API key
- the API key must come from the environment; keep it out of the repo and history
- fail open on the hook path — every internal error inside `run_hook` logs to
  `stderr` and exits `0`, so a broken generator never blocks a commit; never
  add a `return 1` there. `--verify` is the sole command allowed to exit
  non-zero, since it is a manual preflight check with no commit at risk

## PR & Commit Instructions

- run `shellcheck` before opening a pull request
- record notable changes in [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`

## Documentation Maintenance

- update [CONTEXT.md](CONTEXT.md) when the data flow or design changes
- update [README.md](README.md) when setup, usage, or configuration changes
- keep this file behavioral — send architecture narration to `CONTEXT.md`
