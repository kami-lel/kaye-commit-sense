# kaye-commit-sense CHANGELOG

<!--
fixme hook logger messages are commented out for clarity
todo add an installer
todo utilize co-authorship, leave kaye's name
todo support chinese
todo implements UTs
-->

[^format]













## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/kami-lel/commit-sense-via-dify/compare/v1.2.0...dev













## [1.2.0] - 2026-08-06

### Changed

- ordinary-edit sigils now render as color-coded emoji (🟢🟡🔴 short, 🟩🟨🟥 long) instead of ASCII characters, and the LLM-emitted special-case sigils expanded from nine single characters to nineteen emoji, including a new one for version changes (🏷️)
- `docs/kaye_commit_sense_doc.md` renamed to `docs/kcs-doc.md` and rewritten around the emoji sigil scheme

### Removed

- `KCSH_DISABLE_MD_SYNTAX` configuration option and the Markdown-disable feature it controlled — generated messages are now always Markdown-formatted
- the leading-space workaround for lines sigiled `#`, no longer applicable now that sigils are emoji
- the unused `ADD_DEL_BALANCE_TOLERANCE` parameter from `post_per_file`'s entry point

[1.2.0]: https://github.com/kami-lel/commit-sense-via-dify/compare/v1.1.2...v1.2.0













## [1.1.2] - 2026-08-02

### Changed

- `merge_final_answer` prepends a leading space only to lines whose sigil is `#`

### Fixed

- `is_md_syntax_disabled` no longer uses the Bash 4+ `${VAR,,}` lowercase expansion
- `call_dify_chat` and `call_dify_info` no longer fail with an "unbound variable" error when the optional `timeout` binary is absent

> [!NOTE]
> restore Bash 3.2 compatibility (macOS's frozen system Bash) where the hook previously failed silently on every real invocation

[1.1.2]: https://github.com/kami-lel/commit-sense-via-dify/compare/v1.1.1...v1.1.2













## [1.1.1] - 2026-07-28

### Added

- optional `KCSH_DIFY_USERNAME` names the caller in the Dify app's logs
- `--verify` reports the resolved caller identifier and its source
- a **Configuration** section in the README, covering every optional
  environment variable

### Changed

- requests now identify the caller instead of sending a fixed value

[1.1.1]: https://github.com/kami-lel/commit-sense-via-dify/compare/v1.1.0...v1.1.1













## [1.1.0] - 2026-07-28

### Added

- the Dify app source under `dify_studio_app/` — the exported **Kaye_Commit_Sense** Chatflow together with the Python code-node scripts it runs, so the whole generator is versioned alongside the hook
- a reference document explaining diff-shape classification: how a file's added and deleted line counts become an addition, balanced, or deletion verdict

### Changed

- the project is now named **kaye-commit-sense** throughout, replacing the former `commit-sense-via-dify`
- per-file verdicts now weigh the added-to-deleted ratio against how much evidence stands behind it, so a lopsided handful of lines reads as balanced while a large change is judged on its true proportion

[1.1.0]: https://github.com/kami-lel/commit-sense-via-dify/compare/v1.0.0...v1.1.0













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
