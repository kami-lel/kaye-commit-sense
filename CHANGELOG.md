# commit-sense-via-dify CHANGELOG

<!--
TODO test real use hook
todo add spinner back
fixme rewrite in-script bash function docs
todo mpl UT
-->

[^format]













## [Unreleased]

### Added

- `--verify` preflight check: validates dependencies, configuration, and Dify app mode
- hook gate checks: skip generation for `KCSH_ENABLE_SKIPPING`, reused commits, and empty diffs
- message generation: blocking call to Dify, with `kamilog` progress feedback on stderr
- atomic message write: prepend generated answer via temporary file and atomic move
- setup and usage documentation in `README.md`
- environment variable verification in `--verify` mode, now also logging the
  resolved API endpoint, request timeout, and Markdown-syntax setting
- sample diff fixtures under `examples/diffs/`, each paired with a runnable
  demo script under `examples/` that exercises message generation against it
- optional `kamilog` integration: structured logging throughout the hook,
  degrading to a no-op shim when `kamilog` is not installed
- `kamilog` "done" log line on a successful hook run
- reusable run stages extracted from `run_hook`: `is_generation_allowed`,
  `read_staged_diff`, `generate_message`, and `write_message_file`, each
  callable on its own by a demo script
- `KCSH_REQUEST_TIMEOUT_SEC` environment variable: configures the Dify
  request timeout, in seconds; defaults to `45`
- `KCSH_DISABLE_MD_SYNTAX` environment variable: tells the Dify app to skip
  Markdown syntax in the generated message; defaults to `False`

### Changed

- environment variable names now use the `KCSH_` prefix throughout —
  `KCSH_DIFY_SERVICE_API_ENDPOINT`, `KCSH_DIFY_SERVICE_API_SECRET_KEY`, and
  `KCSH_ENABLE_SKIPPING` (the skip-generation toggle, renamed from
  `SKIP_KAYE_COMMIT_SENSE`)
- user identifier hardcoded to `"user"` (no longer configurable via environment)
- updated all documentation to reflect completed implementation
- renamed `prepare-commit-msg.sh` to `prepare-commit-msg` to match its
  installed hook name
- `run_hook` reduced to orchestration over the stage functions, behavior
  unchanged
- `kamilog` logger names consolidated under `LOGGER_ROOT="KCSH"`, with
  sub-loggers `KCSH.dify` and `KCSH.git` in place of the earlier flat
  `LOGGER_NAME`
- messages piped to `kamilog` no longer carry a trailing newline
- section banners inside the script use a consistent dash-ruled sub-heading in
  place of ad hoc inline dividers
- `USAGE_TEXT` relocated next to `main`, grouped with the rest of the
  entry-point section; `VERSION` moved back to the top of the script
- `run_verify` moved ahead of the Dify section, so setup checks read before usage
- diff fixtures relocated from `demos/diffs/` to `examples/diffs/`
- `check_dependencies` now logs a `succ`/`error` line per required command as
  each is checked, then one `pass`/`fail` summary line for the whole check;
  `run_verify` gates on this single unified check instead of a separate
  hardcoded `jq` pre-check ahead of it

### Deprecated

### Removed

- unit-test suite (`tests/test-commit-sense-via-dify.sh`) and its `tests/`
  directory; the hook script's public stage functions remain available for
  demo scripts to source
- stderr spinner utility, in favor of `kamilog` progress feedback
- `generate_message_from_file`, an unused stage for generating from a diff
  already saved to a file

### Fixed

- `--verify` now checks for `jq` before parsing any JSON, instead of failing
  deeper in the check with a confusing error

### Security

- API key never logged or printed; only used for Authorization header
- fails closed on Dify errors; never emits empty commit messages
- temporary message files cleaned up on all exit paths (RETURN, INT, TERM traps)

[Unreleased]: https://github.com/kami-lel/commit-sense-via-dify/commits/main













<!-- footnotes -->

[^format]: the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
