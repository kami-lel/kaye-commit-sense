# kaye-commit-sense CHANGELOG

<!--
Bug `#` as line beginning will comment out the line during editor stage
Fixme add/del/balance logic is wrong
fixme hook logger messages are commented out
todo add AI maintenance sigil
todo implements UTs
todo support chinese
-->

[^format]













## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/kami-lel/commit-sense-via-dify/compare/v1.0.0...HEAD













## [1.0.0] - 2026-07-28

### Added

- automatic commit message generation: a Git hook that drafts your commit message from the staged diff, with a progress animation while it works
- `--verify` preflight check to confirm dependencies, configuration, and connectivity are all set up correctly
- opt-out for a single commit via `KCSH_ENABLE_SKIPPING`
- configurable request timeout and an option to disable Markdown formatting in generated messages
- setup and usage documentation, plus runnable example diffs

[1.0.0]: https://github.com/kami-lel/commit-sense-via-dify/releases/tag/v1.0.0













<!-- footnotes -->

[^format]: the format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
