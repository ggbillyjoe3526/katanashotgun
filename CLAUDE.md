# KATANA / SHOTGUN: notes for Claude

The spec is the source of truth: `spec.md` (large: grep its headings, then read
ranges). `DESIGN.md` is the short design doc; `README.md` covers controls,
layout and debug flags. Where the spec and the code disagree, the spec wins.

## Repo-specific
- **Godot 4.7.2-stable**, typed GDScript, GL Compatibility (the INSANE graphics
  preset runs on Forward+ after a restart; spec §14.1). The version is
  pinned in three places that must change together: `project.godot`
  (`config/features`), and `GODOT_VERSION` in `.github/workflows/ci.yml` and
  `release.yml`.
- **Cloud sessions:** the SessionStart hook (`.claude/hooks/session-start.mjs`)
  installs that Godot as `godot` on PATH. Export templates are not installed;
  CI builds releases.
- **Smoke test:** `tools/smoke_test.sh` (import, then the autoplay bot for 3000
  frames; fails on any script error). CI runs the same script on every PR.
- **Version:** one value, `config/version` in `project.godot`, named like
  `0.1 Dev 1`, `0.1 Beta 2`, `0.1` (`VERSIONING.md`). `tools/version.sh` maps it
  to the tag (`v0.1-dev.1`) and the Windows version number.
- **Releases:** `.github/workflows/release.yml`. Actions → Release → Run
  workflow releases the version in `project.godot` (or push its matching tag);
  a PR touching the pipeline does a dry run. Never create a tag unless the
  owner asks for a release. The release notes come from this version's
  `CHANGELOG.md` section (`tools/changelog_section.sh`): before releasing, set
  the new version and run `tools/changelog.sh release` (`VERSIONING.md`).
- **Changelog:** never edit `CHANGELOG.md` in a feature PR (parallel PRs
  conflict there). Add one new file `changelog.d/<short-name>.md`: a
  `### Title` line, then `- ` bullets in player words (`changelog.d/README.md`).
  CI runs `tools/changelog.sh check`.
- **Installer:** `installer/KatanaShotgun.iss` (Inno Setup 6). Never change its
  `AppId`. No slash in file, folder or shortcut names.
- **Review:** before marking a PR that touches code ready, run the `critic`
  agent (`.claude/agents/critic.md`) and fix its blocking findings.
- **Bosses:** `docs/boss-roster.md` records how every boss fights. Read it
  before adding or changing a boss (its new-boss checklist), and update it in
  the same PR as any boss change.
- **Player wiki:** `docs/wiki/` (one page per file) is published to the
  GitHub wiki on every merge (`.github/workflows/wiki.yml`). Any PR a player
  would notice (a card, mutator, boss, enemy, control, setting, score rule,
  reward, map) updates its wiki page in the same PR, live only once merged:
  features in open PRs are "Coming soon". Patch Notes are generated from the
  changelog; update `Roadmap.md` when plans change. CI runs
  `python3 tools/wiki.py check` (`docs/wiki/README.md`).
- **Reading big files:** a hook stops whole-file reads over 40 KB; grep, then
  read with offset and limit.
- **Tests and lint:** `tools/unit_tests.sh` (Gut, tests in `test/unit/`) and
  `gdlint scripts test tools` (settings in `gdlintrc`) run in CI next to the
  smoke test.
- **Exit-time leak warnings** (`RID allocations ... leaked at exit`,
  `ObjectDB instances were leaked`) appear at the end of every headless run;
  they are known and are not script errors.

## Third-party code and assets
Rules for anything made by someone else (from William's licence briefing,
2026-10-18). `ASSETS.md` is our log; `THIRD_PARTY_NOTICES.txt` is what ships.
- **Check first:** the current LICENSE and README on the source, and the
  minimum Godot version (must work on 4.7.2).
- **Addons:** copy only the repo's `addons/<name>` folder into `addons/`, never
  the whole repo or a submodule. Keep its LICENSE inside the folder (copy it in
  if the repo keeps it at the root).
- **Same commit:** log it in `ASSETS.md`. If it ships in the game, add its
  licence file to `SHIPPED` in `tools/make_notices.gd` and regenerate
  `THIRD_PARTY_NOTICES.txt` (CI fails if it is stale).
- **Debug and test addons** are excluded in every preset's `exclude_filter` in
  `export_presets.cfg`, so they never ship.
- **No GPL code in the game.** GPL programs are fine as tools on the PC.
- **Tools stay out of the repo** (MCP servers, editors, asset tools); only
  their output goes in.
- **Assets carry their own licence**, separate from the tool or site they came
  from: record each one's source and licence. Only CC0, CC-BY or SIL OFL
  (project rules).
- **Do not use:** TRELLIS and TRELLIS.2 (nvdiffrast is research-only),
  Hunyuan3D 2 and 2.1 (licence excludes the EU, UK and South Korea, including
  via Blender MCP), MusicGen models (non-commercial), and Sketchfab or Poly
  Pizza models whose licence hasn't been checked one by one.
