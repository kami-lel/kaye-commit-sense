# commit-sense-via-dify README

> 🧠 A Dify app writes your Git commit messages from the staged diff.

A single Bash script that reads `git diff --cached`, sends it to a Dify app,
waits with visual feedback, and returns the result as the commit message. Built
to run as a Git commit hook.

> ⚠️ **Status: planned** — `commit-sense-via-dify.sh` is not yet implemented.

## Requirements

- **Bash**, **Git**, and **curl** — nothing else; a fresh Debian machine
  already has everything this needs
- a **Dify** app with an API key

## Setup

- drop `commit-sense-via-dify.sh` into your repo and make it executable
- export your Dify API key and endpoint in the environment
- wire it into your Git commit hook

## Docs

- [AGENTS.md](AGENTS.md) — conventions for code changes
- [CONTEXT.md](CONTEXT.md) — design and data flow
