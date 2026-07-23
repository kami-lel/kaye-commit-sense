---
name: commit-sense-via-dify AGENTS
alwaysApply: true
---

# commit-sense-via-dify AGENTS

The entire project is a single Bash script, `commit-sense-via-dify.sh`, that
generates Git commit messages from the staged diff via a Dify app. See
[CONTEXT.md](CONTEXT.md) for design and data flow.

> Status: the script is not yet implemented. This repository holds scaffolding.

## Scope

- keep all logic in one file — `commit-sense-via-dify.sh`
- add no runtime dependencies beyond `git`, `curl`, and a POSIX shell
- target **Bash**, invoked as a Git commit hook

## Code Style

- start the script with `#!/usr/bin/env bash`
- enable `set -euo pipefail` near the top for safe failure
- quote all variable expansions; prefer `"${var}"` form
- read Dify credentials and endpoints from the environment, never hardcode
- keep visual feedback on `stderr` so it never pollutes the commit message

## Testing Instructions

- lint the script with `shellcheck commit-sense-via-dify.sh`
- format with `shfmt -i 2 -w commit-sense-via-dify.sh` if available
- smoke-test manually: stage a change, run the script, inspect the output

## Security Considerations

- the staged diff is sent to an external Dify service — never log the API key
- the API key must come from the environment; keep it out of the repo and history
- fail closed — if Dify is unreachable, do not silently emit an empty message

## PR & Commit Instructions

- run `shellcheck` before opening a pull request
- record notable changes in [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`

## Documentation Maintenance

- update [CONTEXT.md](CONTEXT.md) when the data flow or design changes
- update [README.md](README.md) when setup, usage, or configuration changes
- keep this file behavioral — send architecture narration to `CONTEXT.md`
