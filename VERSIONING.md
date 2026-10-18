# Versioning

How KATANA / SHOTGUN versions are named (decided by the owner, 2026-10-18).

## The names
Each version number goes through three stages:

| Stage | Names, in order | Meaning |
|---|---|---|
| Dev | `0.1 Dev 1`, `0.1 Dev 2`, `0.1 Dev 3`, ... | in development |
| Beta | `0.1 Beta 1`, `0.1 Beta 2`, ... | feature-complete, being tested |
| Release | `0.1` | out of beta |

The game is currently **0.1 Dev 1**. Each update moves to the next name:
the Dev count goes up until the game enters beta, the Beta count goes up
until it is released, and then the release is plain `0.1`. What comes after
`0.1` (for example `0.2 Dev 1`, or fixes to `0.1`) is for the owner to decide
when we get there.

## Where it lives
The version is set in **one place**: `config/version` in `project.godot`,
written exactly as players see it:

```
config/version="0.1 Dev 1"
```

Everything else reads it from there:
- **Title screen:** bottom-right corner shows the name as is (`0.1 Dev 1`).
- **Release pipeline** (`.github/workflows/release.yml`): `tools/version.sh`
  turns the name into the forms below.
- **Windows installer** (`installer/KatanaShotgun.iss`): the name, the file
  name and the Windows version number all come from the release pipeline.
- **Unit test:** `test/unit/test_version.gd` fails if the name doesn't follow
  this scheme.

| Name (players see) | Git tag and file names | Windows version number | GitHub Release |
|---|---|---|---|
| `0.1 Dev 1` | `v0.1-dev.1` | `0.1.1.1` | pre-release |
| `0.1 Beta 2` | `v0.1-beta.2` | `0.1.2.2` | pre-release |
| `0.1` | `v0.1` | `0.1.3.0` | full release |

Windows wants four plain numbers, so the third one is the stage (1 Dev,
2 Beta, 3 release) and the fourth is the count. That keeps the number
always going up: every Dev is below every Beta, which is below the release,
which is below the next version's `Dev 1`.

Check any name with `tools/version.sh "0.1 Beta 2"`.

## Releasing a new version
Only when the owner asks for a release.
1. In a pull request, set `config/version` in `project.godot` to the new
   name (for example `0.1 Dev 2`), then run `tools/changelog.sh release`: it
   gathers the notes in `changelog.d/` into a `## 0.1 Dev 2 (date)` section
   of `CHANGELOG.md` and deletes them. Read the section over and commit it.
   The owner merges it. (Nothing has been released yet, so the first release
   is `0.1 Dev 1` itself and only needs the changelog step.)
2. *Actions → Release → Run workflow* on `main`. It releases the version in
   `project.godot` and creates its tag (`v0.1-dev.2`).

Pushing a tag works too, but the tag must match `project.godot` or the
release stops with an error. A version that has already been released can't
be released again.
