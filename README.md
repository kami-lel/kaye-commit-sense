# commit-sense-via-dify README

> 🧠 A Dify app writes your Git commit messages from the staged diff.

A single Bash script that reads `git diff --cached`, sends it to a Dify app,
waits with visual feedback, and returns the result as the commit message. Built
to run as a Git commit hook.













## Prerequisites

Require `bash`, `git`, `curl`, `jq`, `mktemp`, and a **Dify** app with an API
key

> [!IMPORTANT]
> Install `jq` before using this hook.

#### optional install

- [`kamilog`](https://github.com/kami-lel/kamilog)













## Setup

Copy both files into the repository's hooks directory:

```
your-repo/
└── .git/
    └── hooks/
        ├── prepare-commit-msg            # stub, forwards to the hook
        └── kaye-commit-sense-hook.sh     # the hook itself
```

(If `core.hooksPath` is set, both files belong in that directory instead — the stub resolves the hook next to itself, so the two must stay together)

----

Export your Dify credentials in your shell environment (or in `.bashrc`):

```bash
export KCSH_DIFY_API_SECRET_KEY="your-dify-api-key"
export KCSH_DIFY_SERVICE_API_ENDPOINT="http://your-dify-instance/v1"
```

----

Run the preflight check to confirm everything is wired correctly:
```bash
./kaye-commit-sense-hook.sh --verify
```













## Usage

The hook runs automatically on `git commit`.

To skip generation for a single commit, set the opt-out:

```bash
COMMIT_SENSE_SKIP=1 git commit
```

For help:
```bash
./kaye-commit-sense-hook.sh --help
```
