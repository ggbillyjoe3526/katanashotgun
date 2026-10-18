# KATANA / SHOTGUN: notes for Claude

The spec is the source of truth: `spec.md` (large: grep its headings, then read
ranges). `DESIGN.md` is the short design doc; `README.md` covers controls,
layout and debug flags. Where the spec and the code disagree, the spec wins.

## Repo-specific
- **Godot 4.7.2-stable**, typed GDScript, GL Compatibility. The version is
  pinned in three places that must change together: `project.godot`
  (`config/features`), and `GODOT_VERSION` in `.github/workflows/ci.yml` and
  `release.yml`.
- **Cloud sessions:** the SessionStart hook (`.claude/hooks/session-start.mjs`)
  installs that Godot as `godot` on PATH. Export templates are not installed;
  CI builds releases.
- **Smoke test:** `tools/smoke_test.sh` (import, then the autoplay bot for 3000
  frames; fails on any script error). CI runs the same script on every PR.
- **Releases:** `.github/workflows/release.yml`. A `vX.Y.Z` tag or Actions →
  Release → Run workflow publishes; a PR touching the pipeline does a dry run.
  Never create a tag unless the owner asks for a release. The release notes
  come from this version's `CHANGELOG.md` section (`tools/changelog_section.sh`):
  before releasing, rename `## Unreleased` to `## vX.Y.Z (date)`.
- **Installer:** `installer/KatanaShotgun.iss` (Inno Setup 6). Never change its
  `AppId`. No slash in file, folder or shortcut names.
- **Review:** before marking a PR that touches code ready, run the `critic`
  agent (`.claude/agents/critic.md`) and fix its blocking findings.
- **Reading big files:** a hook stops whole-file reads over 40 KB; grep, then
  read with offset and limit.
- **Exit-time leak warnings** (`RID allocations ... leaked at exit`,
  `ObjectDB instances were leaked`) appear at the end of every headless run;
  they are known and are not script errors.
