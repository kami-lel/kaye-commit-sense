# commit-sense-via-dify README

> 🧠 A Dify app writes your Git commit messages from the staged diff.

A single Bash script that reads `git diff --cached`, sends it to a Dify app,
waits with visual feedback, and returns the result as the commit message. Built
to run as a Git commit hook.


## Requirements

- `bash`, `git`, `curl`, `jq`, and a **Dify** app with an API key

> [!IMPORTANT]
> Install `jq` before using this hook.

## Setup

### Prerequisites

Ensure `jq`, `curl`, `git`, and `bash` are installed and in your `PATH`.

### Installation

1. Copy `kaye-commit-sense-hook.sh` to your repository and make it executable:
   ```bash
   cp kaye-commit-sense-hook.sh /path/to/your/repo/
   chmod +x /path/to/your/repo/kaye-commit-sense-hook.sh
   ```

2. Install the hook into `.git/hooks/`:
   ```bash
   ln -s ../../kaye-commit-sense-hook.sh /path/to/your/repo/.git/hooks/prepare-commit-msg
   ```

3. Export your Dify credentials in your shell environment or in `.bashrc`:
   ```bash
   export KCC_DIFY_API_SECRET_KEY="your-dify-api-key"
   export KCC_DIFY_SERVICE_API_ENDPOINT="http://your-dify-instance/v1"
   ```

### Verification

Run the preflight check to confirm everything is wired correctly:
```bash
./kaye-commit-sense-hook.sh --verify
```

This checks that dependencies are present, configuration is set, and the Dify
app is reachable and configured as `advanced-chat` mode.

### Optional install

- [`kamilog`](https://github.com/kami-lel/kamilog) — a logging utility. When
  present on `PATH`, the hook routes its log lines through it; otherwise the
  hook falls back to plain output.
  ```bash
  pip install git+https://github.com/kami-lel/kamilog.git
  ```

## Usage

The hook runs automatically on `git commit`. To skip generation for a single
commit, set the opt-out:
```bash
COMMIT_SENSE_SKIP=1 git commit
```

To test the hook manually:
```bash
./kaye-commit-sense-hook.sh /tmp/test-message "template"
```

For help:
```bash
./kaye-commit-sense-hook.sh --help
```

## Docs

- [AGENTS.md](AGENTS.md) — conventions for code changes
- [CONTEXT.md](CONTEXT.md) — design and data flow
