# commit-sense-via-dify CHANGELOG

<!-- Todo add a hook stub -->

[^format]













## [Unreleased]

### Added

- `--verify` preflight check: validates dependencies, configuration, and Dify app mode
- hook gate checks: skip generation for COMMIT_SENSE_SKIP, reused commits, and empty diffs
- message generation: blocking call to Dify with stderr spinner feedback
- atomic message write: prepend generated answer via temporary file and atomic move
- comprehensive test suite: 14 tests covering JSON helpers and all gate conditions
- setup and usage documentation in `README.md`
- environment variable verification in `--verify` mode

### Changed

- environment variable names now use `KCC_DIFY_API_SECRET_KEY` and
  `KCC_DIFY_SERVICE_API_ENDPOINT` per KamiCommitContext naming convention
- user identifier hardcoded to `"user"` (no longer configurable via environment)
- updated all documentation to reflect completed implementation

### Deprecated

### Removed

### Fixed

### Security

- API key never logged or printed; only used for Authorization header
- fails closed on Dify errors; never emits empty commit messages
- temporary message files cleaned up on all exit paths (RETURN, INT, TERM traps)

[Unreleased]: https://github.com/kami-lel/commit-sense-via-dify/commits/main













<!-- footnotes -->

[^format]: the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
