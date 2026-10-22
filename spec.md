# KATANA / SHOTGUN — Build Specification for Claude Code

> Complete hand-off spec, compiled from the full concept and prototype
> sessions. It covers every decision made so far. Where something is
> undecided it says **OPEN**. Where a prototype value is a placeholder it
> says **PLACEHOLDER**. When this document and the prototype disagree, **this
> document wins**.
>
> **How to use this file (Claude Code):**
> 1. Read §0 for the vision.
> 2. Do **PART S** (setup, workflow, releases), guiding the developer step by
>    step.
> 3. Then work through §0.5 / §18.
> 4. Keep this file updated as decisions change. It lives in the repo root as
>    `spec.md`.

---

## 0. Read this first

### 0.1 What you are building
**KATANA / SHOTGUN** (the title is always written with a slash) is an
**arcade, first-person, cyberpunk horde shooter** for **desktop** (Windows
first, then Mac and Linux), built in **Godot 4 (GDScript)**. The player holds
a **katana in the left hand** and a futuristic electric **"shotgun taser" in
the right hand**. They fight endless, seeded waves on neon rooftops, with a
boss every third wave, and chase a high score and a rising Player Level.

**First person, always.** Leaning toward Doom: not top-down or isometric,
which would feel too close to Diablo.

**It is NOT a browser game.** A web export existed only as a prototyping
convenience. Do not design around browser limits.

### 0.2 The vibe (non-negotiable)
- **Pure adrenaline. A constant dopamine hit. Deeply satisfying. Visually
  overwhelming**, in the spirit of Persona 5's energy, but translated into our
  own cyberpunk look (see §9).
- **Simple but incredibly replayable.** Few mechanics, each one deep.
- **Easy to play, rewarding to master.** It should always be easy and fun. It
  has the *feel* of a skill shooter (Counter-Strike, Valorant: quick
  reactions, crisp hit feedback, headshots matter) but it is **not**
  competitive or esports-hard. Skill and experience pay off in score and
  spectacle; they are never a wall you must climb to keep playing.
- **Presentation first.** Visuals, audio, UI and game feel are where the effort
  goes.

### 0.3 Scope rules (avoid scope creep)
- **Do not add new mechanics, weapons or systems** unless this spec asks for
  them. The core stays: katana + shotgun + dash + jump.
- Unlocks add content and cosmetics only, never new mechanics (§11).
- Future maps are planned (§12) but are not the current priority.
- When in doubt, keep it simple and make it look and sound amazing.

### 0.4 A working prototype exists (v0.3)
A Godot 4.7 prototype (`katana-shotgun/`, GDScript, about 7k lines, everything
built in code) implements most of the moment-to-moment game and much of the
presentation. **If the prototype is provided, start from it and refactor**
(§17 lists what to keep and what to change). If it isn't, build from this
spec; every number you need is here.

### 0.5 Priority order for the next work
0. **PART S first:** set up the developer's PC (Godot, Git, GitHub CLI), the
   GitHub repo and the release pipeline that produces the installable .exe.
1. Fix the critical feedback items in §18.1: UI readability, audio mix (rain
   hiss), multi-colour palettes, object pooling and performance.
2. Profile and save system + Player Level + boss rewards (§11). **Critical.**
3. Settings menu (audio buses, sensitivity, FOV, render scale, quality
   presets, FPS cap/VSync, key rebinding).
4. A replaceable audio pipeline for the professional soundtrack and SFX (§10).
5. Then new maps (§12) and boss variants.

---

# PART S: Setup, workflow and releases (do this FIRST)

> **Claude Code: read this part before anything else.** The developer is not
> necessarily technical. Your first job is to get their PC, their GitHub repo
> and the release pipeline working, **guiding them step by step in plain
> language.** Do it with the checklist in S2.

## S1. How this project is developed (decided)

- **Develop locally:** Claude Code runs **on the developer's Windows PC**,
  with **Godot 4 installed there**. This gives:
  - an instant play-test loop (the developer presses Play)
  - real-GPU screenshots, captures and performance numbers
  - Windows-specific behaviour caught early (mouse capture, fullscreen,
    input)
  - Cloud machines have no GPU and render in software: slow, and their
    performance numbers are meaningless.
- **GitHub is the home of the project** (source of truth, history, backups).
- **GitHub Actions does the releases.** Tagging a version builds the game in
  the cloud and publishes downloadable files on GitHub Releases, including a
  **Windows installer (.exe)** and a portable .zip (S4).
- **No MCP is needed for Godot.** Claude Code drives Godot through its
  command line: run the game, run the headless bot tests, capture frames,
  read errors, export builds. Community Godot MCP servers exist (editor
  integration: run a specific scene, read debugger output). They are an
  optional extra; try one only if it clearly helps.
- **If you (Claude Code) are running in the cloud instead of on the PC:**
  - Tell the developer plainly. You can still write code, run headless tests
    and use CI.
  - The developer then has to download each build to play it.
  - Recommend switching to Claude Code on their PC (the setup in S2) for
    day-to-day work.

### S1.1 What Claude Code can and can't do here
- **Can:** write and edit every part of the project. Godot projects are text:
  `.gd` scripts, `.tscn` scenes, `.tres` resources, `.gdshader`,
  `project.godot`, `export_presets.cfg`. Run the game, the headless autoplay
  bot and the `--juicetest` showcase; capture frames and video to check
  visuals; export builds; set up CI; manage git and GitHub releases.
- **Can't:**
  - **Judge feel.** Mouse feel, pacing, difficulty and fun need the developer
    to play. Ask for focused play-tests at milestones (S3.3).
  - **Make the final music, SFX or 3D models.** These come from people
    (§9.6, §10.2). Wire them in when they arrive.
  - **Do account steps for the developer.** Creating accounts, logging in,
    approving permissions and installers with Windows prompts are theirs.
    Walk them through it.

## S2. First-time setup: guide the developer through this

**How to guide:**
- **One step at a time, in plain words.** Say what the step is for in one
  sentence.
- **Do the work yourself whenever you can** (run the commands). Only ask the
  developer to do things that need them: downloads with Windows prompts,
  accounts, logins, clicking in a browser.
- **After every step, verify it worked** (run a check command) before moving
  on. If something fails, explain what happened and fix it. Don't pile up
  steps.
- Never ask them to edit code or config by hand.
- Keep a short checklist in your replies so they can see progress. The
  developer's PC is **Windows x64**.

### Step 1: Check what's already installed
Run in a terminal (PowerShell):
`godot --version`, `git --version`, `gh --version`, `winget --version`.
Report what's missing in plain words, and skip the steps that are already
done.

### Step 2: Install Godot (the editor and command line)
- Use the **same Godot version as the project**:
  - Read `config/features` in `project.godot`. The prototype uses **Godot
    4.7.2 stable**.
  - Never upgrade without asking. If you upgrade on purpose, update CI
    (`GODOT_VERSION`) at the same time.
  - Use the **standard** build, **not the .NET/C# one**.
- **Option A (simplest, if winget works):**
  `winget install --id GodotEngine.GodotEngine -e`. If winget's version isn't
  the one the project needs, use Option B.
- **Option B (manual, exact version):**
  1. Ask the developer to open **https://godotengine.org/download/archive/**
     (or the GitHub releases at `github.com/godotengine/godot-builds`), pick
     **4.7.2-stable**, and download the **Windows 64-bit standard** zip.
  2. Create the folder `C:\Godot` and unzip into it. It contains
     `Godot_v4.7.2-stable_win64.exe` (the editor) and
     `Godot_v4.7.2-stable_win64_console.exe` (same app, but it prints output
     to the terminal).
  3. **You do this:** copy the console exe to `C:\Godot\godot.exe`, so the
     command `godot` works and shows output.
  4. **You do this:** add `C:\Godot` to the user PATH (PowerShell):
     `[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";C:\Godot", "User")`
     Then the developer opens a **new** terminal window. Verify with
     `godot --version` (it should print 4.7.2.stable…).
- **Optional:** a desktop shortcut to the editor exe, so the developer can
  open the project and press **F5 (Play)** to play-test.
- **Export templates:** not needed locally (CI builds the releases). If the
  developer wants local exports: Godot editor → *Editor → Manage Export
  Templates → Download and Install* (it must match the editor version).

### Step 3: Install Git and the GitHub CLI
- `winget install --id Git.Git -e` and `winget install --id GitHub.cli -e`
  (or the installers from git-scm.com and cli.github.com). The developer
  accepts the Windows prompts. Open a new terminal.
- Set the identity (ask for their name and the email they use on GitHub):
  `git config --global user.name "…"` and `git config --global user.email "…"`.
- Verify: `git --version`, `gh --version`.

### Step 4: GitHub account and login
- If they don't have one, the developer creates a free account at
  **https://github.com/signup**.
- Run `gh auth login` and choose **GitHub.com → HTTPS → Login with a web
  browser**. The developer copies the one-time code into the browser and
  approves.
- Verify: `gh auth status`.

### Step 5: Decide public or private (ask the developer)
- **Public repo:** anyone can download releases, and anyone can see the
  source.
- **Private repo:** releases are **only visible to the owner and invited
  collaborators**, so players can't download them.
- If they want public downloads but private code: keep the code private and
  publish releases from a separate **public** repo (for example
  `katana-shotgun-releases`). Alternatively use itch.io or Steam later.
  Record the decision in S6.

### Step 6: Create the repo and the first commit
1. Put the project in a folder such as `C:\Dev\katana-shotgun`. If the
   prototype zip was provided, unzip it so `project.godot` sits at the repo
   root. This file goes in the root as **`spec.md`**.
2. Add a Godot `.gitignore`:
   ```
   # Godot 4
   .godot/
   build/
   dist/
   *.tmp
   # OS / editors
   .DS_Store
   Thumbs.db
   .vscode/
   ```
   Commit the `*.import` files and `export_presets.cfg`; Godot 4 needs them.
   Never commit passwords or signing keys; those go in GitHub Secrets.
3. `git init -b main`, `git add .`, `git commit -m "Prototype v0.3"`.
4. `gh repo create katana-shotgun --private --source . --push` (or
   `--public`, per Step 5).
5. Verify: `gh repo view --web` opens the repo in the browser. Show the
   developer.
- **Large files:** the audio is small now (about 10 MB). If repo size grows
  a lot later (professional music, models), consider **Git LFS** for
  `.wav/.ogg/.glb`. GitHub's free LFS quota is small, so only use it when
  needed.

### Step 7: First local run and smoke test
1. `godot --headless --path . --import` (imports assets and builds the class
   cache).
2. Smoke test: `godot --headless --path . --quit-after 3000 -- --autoplay --god`.
   It must show **no "SCRIPT ERROR"** lines.
3. Ask the developer to open the project in the Godot editor (Import →
   select `project.godot`) and press **F5**. Confirm the game runs, the mouse
   captures, LMB swings the katana, RMB fires the shotgun.

### Step 8: Set up the release pipeline (S4), then do a test release
Do a dry run (*Actions → Release → Run workflow* with Publish unticked; the
version comes from `project.godot`, S3.2), watch the Actions run, and check that the GitHub Release has the installer, the
portable zip and the other platforms. Ask the developer to download the
installer, install, play, and uninstall. Explain the SmartScreen warning
(S4.4) **before** they see it.

**Setup done.** Summarise what's installed and where, and move on to the
work list (§0.5).

## S3. Day-to-day workflow

### S3.1 Working rules for Claude Code
- **Small, safe steps.** Make a change, run the headless smoke test (and the
  relevant `--juicetest` or autoplay capture for visual work), then commit
  with a clear message.
- **Explain changes in plain language.** Show screenshots or short clips
  (Movie Maker frames to mp4) for visual changes.
- **Don't add mechanics or systems that aren't in this spec** (§0.3). Ask
  first.
- Keep `CHANGELOG.md` (newest first, written for players and the
  developer) and keep this spec up to date when decisions change. Each change
  adds its note as a new file in `changelog.d/` (one per PR, so parallel PRs
  don't conflict); a release gathers them into `CHANGELOG.md`. **The spec
  is the source of truth.**
- Branching:
  - Simple is fine: commit to `main` when tests pass.
  - For risky work (save system, big refactors), use a branch and merge when
    it works.
  - Never rewrite pushed history.

### S3.2 Versioning
- **Version names** (owner's decision, 2026-10-18; details in `VERSIONING.md`):
  `0.1 Dev 1`, `0.1 Dev 2`, ... then `0.1 Beta 1`, `0.1 Beta 2`, ... then the
  release `0.1`. `0.1 Dev 1` was released 2026-10-18; the current version is
  `0.1 Dev 2`.
  - Set in one place: `config/version` in `project.godot`, written as players
    see it. The title screen and the installer show it.
  - `tools/version.sh` maps a name to its tag (`0.1 Dev 1` → `v0.1-dev.1`,
    `0.1` → `v0.1`) and the Windows version number (`0.1.1.1`). Releasing
    publishes the version in `project.godot`; a pushed tag must match it.
- **Release when the developer asks**, or propose one at a milestone. Before
  tagging:
  1. Gather the CHANGELOG notes (`tools/changelog.sh release`).
  2. Run the full smoke test and a 10-minute autoplay run.
  3. Make sure saves from the previous version still load (once §11 exists).

### S3.3 Play-tests (ask the developer)
- At each milestone, ask for a short play-test with **specific questions**:
  - Is any text hard to read?
  - Is the rain/ambience too loud?
  - Does wave 1–3 feel easy?
  - How does the mouse feel?
  - Any stutter?
- Ask them to note the run's **seed** (on the HUD and the results screen) when
  something odd happens, so it can be reproduced with
  `--seed=XXXX-XXXX`.
- Bugs: ask for the seed, the wave, what they did, and what they expected.

## S4. Release pipeline (GitHub Actions + Windows installer)

**Goal:** releasing a version (S3.2; tags like `v0.1-dev.1`, written
`vX.Y.Z` below) produces a **GitHub Release** with these files:
- `KatanaShotgun-vX.Y.Z-Windows-Setup.exe`: an **installer**. Installs to
  Program Files, adds Start Menu and optional desktop shortcuts, adds an
  uninstaller, and optionally launches the game at the end.
- `KatanaShotgun-vX.Y.Z-Windows-Portable.zip`: the single exe, no install.
- `KatanaShotgun-vX.Y.Z-Linux.zip` and `KatanaShotgun-vX.Y.Z-macOS.zip`
  (optional; see S4.4).
- Auto-generated release notes, plus the CHANGELOG section.

### S4.1 Export presets (in `export_presets.cfg`)
- **Windows Desktop** (exists): x86_64, `embed_pck = true` (single exe),
  `modify_resources = false` (CI runs on Linux without rcedit; the installer
  supplies the icon). Output `build/windows/KatanaShotgun.exe`.
- **Linux:** add an x86_64 preset with embed_pck. Output
  `build/linux/KatanaShotgun.x86_64`.
- **macOS:** add an unsigned preset with a bundle id such as
  `com.<developer>.katanashotgun`. Output `build/macos/KatanaShotgun.zip`.
  Optional; drop it if it causes trouble.
- The **Web** preset from the prototype has been deleted (2026-10-18).

### S4.2 Workflow file `.github/workflows/release.yml` (reference; check action versions)
> **Built (2026-10-18).** The real workflow in the repo supersedes this
> reference: it takes the version from `project.godot` (S3.2) instead of
> stamping it from the tag, runs from *Actions → Release → Run workflow*,
> does a dry run on pull requests that touch the pipeline, checks the
> exported Linux build plays and the installer installs and uninstalls, and
> takes the release notes from `CHANGELOG.md`. Every PR also runs the smoke
> test (`.github/workflows/ci.yml`, `tools/smoke_test.sh`).
```yaml
name: Release
on:
  push:
    tags: ["v*.*.*"]
  workflow_dispatch:

permissions:
  contents: write

env:
  GODOT_VERSION: "4.7.2"   # must match the project
  GODOT_STATUS: "stable"

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Godot + export templates
        run: |
          V="${GODOT_VERSION}-${GODOT_STATUS}"
          BASE="https://github.com/godotengine/godot-builds/releases/download/${V}"
          wget -q "${BASE}/Godot_v${V}_linux.x86_64.zip"
          wget -q "${BASE}/Godot_v${V}_export_templates.tpz"
          unzip -q "Godot_v${V}_linux.x86_64.zip"
          sudo mv "Godot_v${V}_linux.x86_64" /usr/local/bin/godot
          TPL="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_STATUS}"
          mkdir -p "$TPL"
          unzip -q "Godot_v${V}_export_templates.tpz"
          mv templates/* "$TPL/"
      - name: Stamp version from tag
        run: |
          VER="${GITHUB_REF_NAME#v}"
          sed -i "s/^config\/version=.*/config\/version=\"${VER}\"/" project.godot
      - name: Import
        run: godot --headless --path . --import || true
      - name: Smoke test (bot plays, must have no script errors)
        run: |
          timeout 300 godot --headless --path . --quit-after 3000 -- --autoplay --god 2>&1 | tee smoke.log
          if grep -q "SCRIPT ERROR" smoke.log; then exit 1; fi
      - name: Export
        run: |
          mkdir -p build/windows build/linux build/macos
          godot --headless --path . --export-release "Windows Desktop" build/windows/KatanaShotgun.exe
          godot --headless --path . --export-release "Linux" build/linux/KatanaShotgun.x86_64
          godot --headless --path . --export-release "macOS" build/macos/KatanaShotgun.zip || echo "macOS export skipped"
      - uses: actions/upload-artifact@v4
        with:
          name: builds
          path: build/

  installer:
    needs: export
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: builds
          path: build
      - name: Install Inno Setup
        run: choco install innosetup -y --no-progress
      - name: Build installer
        shell: pwsh
        run: |
          $ver = "${{ github.ref_name }}".TrimStart("v")
          & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "/DAppVersion=$ver" installer\KatanaShotgun.iss
      - uses: actions/upload-artifact@v4
        with:
          name: installer
          path: dist/*.exe

  release:
    needs: [export, installer]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: art
      - name: Package
        run: |
          VER="${GITHUB_REF_NAME#v}"
          mkdir -p dist
          cp art/installer/*.exe dist/
          (cd art/builds/windows && zip -9 "$GITHUB_WORKSPACE/dist/KatanaShotgun-v${VER}-Windows-Portable.zip" KatanaShotgun.exe)
          (cd art/builds/linux && zip -9 "$GITHUB_WORKSPACE/dist/KatanaShotgun-v${VER}-Linux.zip" *)
          if [ -f art/builds/macos/KatanaShotgun.zip ]; then cp art/builds/macos/KatanaShotgun.zip "dist/KatanaShotgun-v${VER}-macOS.zip"; fi
      - uses: softprops/action-gh-release@v2
        with:
          files: dist/*
          generate_release_notes: true
          prerelease: ${{ startsWith(github.ref_name, 'v0.') }}
```
Notes:
- Make the Linux exe executable inside the zip (`chmod +x`).
- If the repo is private but releases should be public, change the
  `release` job to publish to the public releases repo (use
  `softprops/action-gh-release` with `repository:` and a token secret).
- Test the workflow with `workflow_dispatch` or a `-test` tag first.

### S4.3 Installer script `installer/KatanaShotgun.iss` (Inno Setup 6; reference)
```ini
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Generate ONE GUID for AppId and never change it (it identifies the app for upgrades/uninstall)
AppId={{REPLACE-WITH-A-NEW-GUID}
AppName=KATANA SHOTGUN
AppVerName=KATANA / SHOTGUN {#AppVersion}
AppVersion={#AppVersion}
AppPublisher=REPLACE-WITH-DEVELOPER-NAME
DefaultDirName={autopf}\KATANA SHOTGUN
DefaultGroupName=KATANA SHOTGUN
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=KatanaShotgun-v{#AppVersion}-Windows-Setup
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\KatanaShotgun.exe
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\KatanaShotgun.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\KATANA SHOTGUN"; Filename: "{app}\KatanaShotgun.exe"
Name: "{group}\Uninstall KATANA SHOTGUN"; Filename: "{uninstallexe}"
Name: "{autodesktop}\KATANA SHOTGUN"; Filename: "{app}\KatanaShotgun.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\KatanaShotgun.exe"; Description: "{cm:LaunchProgram,KATANA SHOTGUN}"; Flags: nowait postinstall skipifsilent
```
Notes:
- **No slash in file or folder names.** Use "KATANA SHOTGUN" for paths and
  shortcuts. The slash only appears in display text (`AppVerName`, the
  in-game title).
- Make `installer/icon.ico` from the project icon (multi-size 16–256 px; for
  example with Pillow or ImageMagick). Replace the placeholder icon with a
  proper KATANA / SHOTGUN icon when one exists.
- **Saves are NOT in the install folder.** They live in
  `%APPDATA%\KatanaShotgun` (`use_custom_user_dir`), so uninstalling or
  updating never deletes progress. Keep it that way, and don't add an
  uninstall step that removes them.
- Installing a newer version over an old one upgrades in place (same
  AppId).

### S4.4 Things to tell the developer about distribution
- **Windows SmartScreen:** an unsigned installer shows *"Windows protected
  your PC"*. Players click **More info → Run anyway**. Removing it needs
  **code signing**: an OV/EV certificate, or Microsoft's Azure signing
  service (roughly $10/month up to a few hundred dollars a year). Optional
  until a wider release. If added, keep the credentials in GitHub Secrets
  and sign in the `installer` job.
- **macOS:** without an Apple Developer account ($99/year) for
  notarization, Mac players see a Gatekeeper warning (right-click → Open).
  Optional.
- **Linux:** no signing needed.
- **Size:** about 120 MB per build (most of it the Godot engine); GitHub
  allows up to 2 GB per release file.
- Later: itch.io (butler) or Steam can be added as more release targets
  from the same pipeline.

## S5. Commands cheat-sheet (for Claude Code)
| Task | Command |
|---|---|
| Import / rebuild class cache | `godot --headless --path . --import` |
| Smoke test | `godot --headless --path . --quit-after 3000 -- --autoplay --god` |
| Unit tests (Gut) | `tools/unit_tests.sh` |
| Lint | `gdlint scripts test tools` (`pip install "gdtoolkit==4.5.0"`) |
| Licence notices | `godot --headless --path . -s res://tools/make_notices.gd` |
| Play a seed / wave / boss | `godot --path . -- --seed=0BAD-C0DE --wave=3 --boss=ninja` |
| Presentation showcase | `godot --path . -- --juicetest` |
| Capture frames (Windows, real GPU) | `godot --path . --write-movie out\f.png --fixed-fps 30 --quit-after 900 -- --juicetest` |
| Frames → mp4 | `ffmpeg -framerate 30 -i out/f%08d.png -i out/f.wav -c:v libx264 -pix_fmt yuv420p -c:a aac clip.mp4` |
| Local Windows export (needs templates) | `godot --headless --path . --export-release "Windows Desktop" build/windows/KatanaShotgun.exe` |
| Changelog notes | `tools/changelog.sh check` (new note: a file in `changelog.d/`) |
| Release | set `config/version` + `tools/changelog.sh release` (PR) → *Actions → Release → Run workflow* (`VERSIONING.md`) |

## S6. Developer decisions log (fill in as you go)
| Decision | Value |
|---|---|
| Repo visibility | Public (`ggbillyjoe3526/katanashotgun`; confirmed by the owner 2026-10-18) |
| Releases repo (if separate) | none: releases publish on the game repo |
| Developer / publisher name for the installer | `ggbillyjoe3526` (default until the owner picks one) |
| Godot version pinned | 4.7.2-stable |
| Music style | Fast (140 to 165 bpm), futuristic, energetic dark electronic bass music with an EDM feel, like Rezz: wobble basses, EDM drums, glitch edits, no string instruments (§10.2); placeholders regenerated to match, real tracks to follow (owner, 2026-10-18) |
| Version names | `0.1 Dev N` → `0.1 Beta N` → `0.1`; current `0.1 Dev 2` (owner, 2026-10-18; Dev 1 released 2026-10-18, Dev 2 set 2026-10-19; `VERSIONING.md`) |
| Changelog notes | one file per PR in `changelog.d/`, gathered into `CHANGELOG.md` at release by `tools/changelog.sh release`, so parallel PRs don't conflict (2026-10-18) |
| Code signing | not yet |
| Mac builds | built (universal, unsigned zip); optional, dropped if it causes trouble |
| Glory kill trigger | Press F (`finisher` action), like Doom 2016, instead of slashing a staggered enemy (owner, 2026-10-18) |
| Vertical movement | Ledge climb only for ledges the hands can reach; a plunge from high ground or off a jump pad on F that counts as a glory kill, always the katana; a higher double jump (owner, 2026-10-18). Default picked: brutes must be staggered to plunge; bosses can never be plunged (no glory kills on bosses, owner 2026-10-18) |
| Deflects | A deflected shot flies straight back to whoever fired it and hurts them (owner, 2026-10-18; §3.2) |
| Map direction | Vertical update of Shin-Kagura: concept A "The Well", with more height on the north deck and roof ring and a living city backdrop (owner, 2026-10-18; §8) |
| Boss reward drop rule | Every kill of a boss unlocks its next reward until its list is done; never random (owner, 2026-10-18) |
| Graphics presets | WEAK (old PCs, today's look), MEDIOCRE (a clear step up, default), INSANE (everything Godot offers, Forward+ renderer; ray and path tracing dropped). Every tier keeps the PS1 look (owner, 2026-10-18; §14.1) |
| Tougher boss movesets | Souls-style boss fights: sidesteps, delayed swings, an area move and a RED SIGNAL attack per boss, punish windows; the first cycle keeps the big moves for after the enrage (owner, 2026-10-18; §5.6) |
| Bosses: posture, no glory kills | Bosses have a posture bar (KAMAE) that aggressive play fills; a full bar breaks the boss and F lands the ONIKIRI blow. Bosses never get a glory kill; only the horde does (owner, 2026-10-18; §5.5) |
| Display defaults | Full screen at the display's resolution, VSync off, unlimited frame rate; the pixel look is kept at 4K (owner, 2026-10-18) |
| Level-up augments | Rule-changing cards that combine into named builds, with a RECOMMENDED tag on linking cards, like Balatro's Jokers (owner, 2026-10-18; §3.8) |
| Online | None: the game is fully offline, with no online leaderboards, accounts or servers. Players share seeds with each other (codes, and later small files) to race scores and more; that sharing is to be expanded (owner, 2026-10-18; §7.5) |
| Dev menu | A hidden developer menu on F10 with a switch for a plain, non-retro look, plus play-test tools; runs that use its cheats are never recorded (owner asked 2026-10-19; §16) |
| Retro look strength | The full PS1 look was too strong and the plain look too clean: a RETRO LOOK setting (OFF / LIGHT / FULL) with LIGHT as the default, a sharper, gentler middle; FULL stays as it was (owner asked 2026-10-19; §9.1) |
| How Claude works | claude.ai project threads in the cloud (no GPU) plus the owner's Windows PC for play-tests and GPU checks |


---

## 1. Influences: what to take, what not to take

| Source | Take | Do NOT take |
|---|---|---|
| Doom (2016) | Speed, brutality, **glory kills**, push-forward combat | Its exact pace (ours is slightly calmer) |
| Diablo 3/4 | Hordes, levelling, simple builds, numbers going up | Grinding, complex builds, loot |
| Counter-Strike / Valorant / League | Crisp hit feedback, headshots, quick reactions, **runs perfectly on weak hardware** | Competitive difficulty |
| Sekiro / Bloodborne | Over-the-top killshots, gore, deathblows | Punishing difficulty |
| FromSoftware (Souls/Elden Ring) | The slow, solemn "boss felled" / "YOU DIED" card; boss naming grammar | Their fonts, exact wording and names |
| Balatro | Suspense-building payoffs, count-ups, chips × mult, screen shake | Its visual style |
| Persona 5 | Energy: cut-ins, all-out finish splash, kinetic UI | **Its look** (no ransom-note letters, no red/black paper shards, no halftone comic style). Players said it looked copy-pasted. |
| Cyberpunk 2077 | Katanas in a neon city; the **Thermal Katana** as the katana's visual reference | Its IP, names and logos |
| PS1/PS2 era | Low-res, vertex wobble, affine textures, dithering, chunky pixel text | Realism |

---

## 2. Platform, engine and project setup

- **Engine:** Godot **4.7** (or the latest 4.x stable), **GDScript** (typed).
  Use C# or GDExtension only if profiling demands it for hot loops.
- **Renderer:** **Compatibility (OpenGL 3.3)**, for the widest hardware
  support (§14), on the WEAK and MEDIOCRE graphics presets. The INSANE
  preset runs on **Forward+** (Vulkan or Direct3D 12) for global
  illumination and volumetric fog (owner, 2026-10-18; §14.1).
  Godot picks the renderer at start-up from `user://renderer.cfg`
  (`application/config/project_settings_override`), so switching to or from
  INSANE takes a restart; a PC that can't run Forward+ falls back to OpenGL.
- **Targets:** Windows x86_64 first (the developer's PC is Windows x64), then
  Mac and Linux. Export Windows with `embed_pck = true` for a single exe.
- **Display:**
  - Project base size **960×540**, stretch mode `viewport`, aspect
    `expand`, stretch scale **2.0**, so the UI is laid out in **480×270**
    canvas units. Measured 2026-10-19: in `viewport` mode the stretch scale
    divides the drawn size, so this draws the whole window, 3D included, at
    **480×270** (8×8 screen pixels per game pixel on 4K), not 960×540 as
    this section used to say. That is RETRO LOOK FULL.
  - The **RETRO LOOK** setting (§9.1, `RetroLook`) picks how strong the
    look is; its default, LIGHT, draws the 3D view at about 540 lines
    (960×540 on 1080p and 4K) and the UI at the window's size, with the
    stretch mode `canvas_items`.
  - `default_texture_filter = Nearest`, MSAA off.
  - Add a render-scale setting for the 3D view.
- **Fonts:** rasterised at the 480×270 canvas size with **no antialiasing**,
  then upscaled with nearest filtering, so text is pixelated like the world.
  Set viewport `oversampling = false`, `oversampling_override = 1.0`; per font
  `antialiasing = NONE`, `hinting = NORMAL`, subpixel off, `oversampling =
  1.0`, MSDF off.
- **User data:** `application/config/use_custom_user_dir = true`,
  `custom_user_dir_name = "KatanaShotgun"`. The app name contains a slash, so
  never derive paths from it.
- **Window:** start full screen at the display's own resolution (borderless,
  up to 4K and beyond); F11 or Alt+Enter toggles windowed. Windowed mode is
  the biggest whole multiple of 960×540 that fits the screen (2880×1620 on
  4K), so the retro pixels stay square and sharp. The 3D view keeps its
  RETRO LOOK resolution at any screen size and is upscaled with nearest
  filtering, never smoothed: FULL's 480×270 exactly 8× on 4K and 4× on
  1080p (1440p gets slightly uneven pixel widths); LIGHT picks the whole
  number of screen pixels per game pixel that comes closest to 540 lines
  (4 on 4K, 3 on 1440p, 2 on 1080p). Higher resolution never smooths away
  the PS1/PS2 look. Pause
  when the window loses focus or the mouse capture is lost.
- **Frame rate:** unlimited by default with VSync off; the frame cap offers
  60, 75, 120, 144, 165, 240 and 360, and VSync can be turned on.

### 2.1 Input map (defaults; everything rebindable)
| Action | Default | Notes |
|---|---|---|
| `katana` | **LMB**, J | Left hand. Hold to keep slashing (input buffer 0.18 s) |
| `shotgun` | **RMB**, K | Right hand. Hold to keep firing at the cooldown rate |
| `move_*` | WASD + arrows | |
| `jump` | Space | Double jump |
| `dash` | Shift, Q | |
| `finisher` | **F** | Glory kill the staggered enemy near the crosshair, or plunge onto a foe below from high ground (§3.4) |
| `drink`, `can_next`, `can_prev` | **E**, mouse wheel | Soda cans, DEV-ONLY play-test (§19.1 #11): drink the selected can, pick another. Not in the rebind list yet |
| pause | Esc | |
| sensitivity −/+ | `[` / `]` | Shortcut; also in Settings |
| settings | Tab (title, pause) | Settings screen (§15.4) |
| quit game | Q twice (title) | Also QUIT on the title, QUIT GAME on pause and in Settings |
| fullscreen | F11 / Alt+Enter | |
| retry same seed | R (results screen) | |
| play a seed | S (title) | PLAY A SEED box (§7.5) |
| copy seed | C (pause, results) | Also COPY / COPY SEED to click (§7.5) |
| initials | A–Z, 0–9, Backspace, Enter | Results screen |

Controller support: **OPEN** (not requested; design the input layer so it
can be added).

---

## 3. Core loop and mechanics

**The rhythm:** blast → stagger → slash → glory kill (press F) → recharge. **The blade
charges the gun; the gun sets up the blade.**

### 3.1 Player
| Parameter | Value |
|---|---|
| Max HP | 100 (Kongo Heart augment +25 per rank) |
| Walk speed | 8.8 m/s, ground accel 70, air accel 28 (×0.3 above walk speed, to keep jump-pad and dash momentum) |
| Gravity | 26 m/s² |
| Jump / double jump | 9.4 / 10.6 m/s (1 extra jump, reset on landing, on jump pads and after a climb). The feet rise about 1.75 m, or about 4.0 m with the double jump at its top (measured at 60 Hz by `--movetest`). The double jump was 8.6 m/s (about 3.2 m in all); raised at the owner's request (2026-10-18) to make the vertical map's levels reachable. The double jump also adds 3 m/s toward the movement keys held (relative to the look direction), capped at 1.35× walk speed, so it never builds speed past that; with no keys held there is no push, so it can't carry the player off a ledge they didn't aim for (owner, 2026-10-18) |
| Ledge climb | Airborne, pushing into a ledge and looking within ~72° of it: grab it when its top is 0.3–2.0 m above the feet (hands overhead), the jump would not clear it by 0.15 m anyway, and the whole capsule fits up and over the edge. Then 0.2 s + 0.09 s per metre of rise: 60% lifts the body, 40% carries it over, keeping half walk speed forward. Katana and dash presses during it fire as it ends. Reach from flat ground: about 3.75 m with one jump, about 6.0 m with the double jump; **anything taller is never climbable** (`LedgeClimb`, `scripts/ledge_climb.gd`) |
| Dash | 2 charges, 21 m/s for 0.2 s, invulnerable for 0.3 s, recharge 1.4 s per charge (Idaten Drive: +1 charge), FOV kick +14 |
| Camera | FOV 88; trauma-based shake (decay 1.6/s, squared); strafe tilt; head bob; landing dip; FOV kicks |
| Capsule | radius 0.4, height 1.8, eye height 1.55 |
| Hit invulnerability | 0.12 s |
| Fall reset | below the map's `kill_y` (−20 on Shin-Kagura, under the metro floor), respawn at the map spawn |

### 3.2 Katana (LEFT hand, LMB): "DOJIGIRI"
- **3-hit combo:** left→right, right→left backhand, overhead chop.
  - Cooldown 0.32 s, or 0.45 s after the third hit. The combo resets if you
    don't swing for 0.65 s.
- **Hit area:** reach 3.4 m, half-arc 68°, vertical tolerance about the enemy's half height + 1.7 m.
- **Damage:** 50 per hit, ×the mutator (Masamune Edge: the third cut ×2).
  Poise damage 18, knockback 4.
- **Armour:** against armoured enemies (that aren't staggered) the katana does
  `armor` of its damage, with sparks and a clang (a Masamune heavy cut ignores armour).
- **Cleaves:** hits every enemy in the arc.
- **Charging the shotgun:** each katana kill gives +1 cell (+1 more per Blood
  Battery rank). Each deflect gives +1 cell.
- **Deflect:** a slash sends back hostile bolts within reach +2.2 m and the
  half-arc +0.35 rad. The bolt turns cyan and flies **straight back to the
  enemy or boss that fired it**, locked on until it lands, at 2.4× its speed
  (≥36 m/s), for **8× its own damage** (a gunner's 12-damage bolt returns for
  96; the Kurokage's shuriken 80, Tetsugumo's gatling bolt 56, Shuten's volley
  bolt 112, all scaled with the wave like the shot was). On the way back it
  ignores cover and every other enemy. If the shooter is already dead, it
  takes the living enemy nearest the aim (dot product > 0.8), else flies
  straight. If its target dies mid-flight it takes the next one along its
  path. Poise damage 140, knockback 12. On the deflect: hitstop 0.07 s, a
  light screen flash, "DEFLECT!"; on arrival: a cyan impact and a crack,
  plus hitstop 0.05 s if it kills. Its kills are tagged "RETURN TO SENDER"
  (points ×1.5).
  (Owner, 2026-10-18: a deflect always goes back and hurts the shooter, never
  just knocks the shot away. The damage scales with the bolt so the gatling's
  many weak bolts can't shred a boss.)
- **Perfect deflect** (play-test experiment, §19.1 #3; built 2026-10-19,
  awaiting the owner's verdict): a slash that catches a bolt **0.15 s or
  less** before it would hit the player is **PERFECT**. "Would hit": along
  its straight path it reaches the player's body (bolt radius + 0.5 m
  around the chest), or passes within 0.6 m of that (the near edge of a
  fan). The normal deflect is unchanged; a perfect one adds:
  - **Return damage ×12** instead of ×8 (a gunner's bolt 144, a shuriken
    120), so it also fills a boss's KAMAE 50% more (§5.5).
  - **+2 cells** instead of +1.
  - A tally row, **PERFECT DEFLECTS n × 150**, on top of its DEFLECTS row.
  - The feel: a ringing steel clang (`deflect_perfect`), a white flash
    (0.35, scaled by the flash slider), hitstop 0.1 s, shake 0.2, white
    sparks and the popup **"PERFECT DEFLECT!"** (white; repeats count up).
    It flies back white-hot with a white trail.
  - **Signature volleys:** each boss has one volley meant to be deflected
    perfectly, drawn with a big **white halo** (Kurokage's shuriken fan,
    Tetsugumo's signature round, Shuten's fan volley; §5.2). The first
    perfect deflect on a volley earns the **big KAMAE hit: +20% of the
    bar** when the bolt lands (once per volley, ×1.5 in a punish window like
    all KAMAE), plus the stamp **PERFECT** (cyan, top lane, as for the RED
    SIGNAL dash) and a short slow motion (×0.35 for 0.3 s). The first
    signature volley of a run (once the deflect hint has shown) shows the
    hint "WHITE BOLTS: DEFLECT AT THE LAST MOMENT FOR A PERFECT".
  - Yata Mirror copies of a perfect bolt carry its damage but no KAMAE
    bonus. Values live in `scripts/bolt.gd` (`PERFECT_*`, `SIGNATURE_*`).
  - KAMAE drains more slowly as the boss loses HP (owner, 2026-10-19; §5.5).
- **Hit feel:** hitstop 0.045 s + 0.012 per enemy hit (up to 4), trauma
  0.22, slash trail, slice sound.
- **A slash just hits a staggered enemy** (full damage, armour ignored, so it
  can kill it outright). The GLORY KILL is its own key, F (§3.4).
- **Look:** see §9.6. The glowing edge flares on each swing.

### 3.3 Shotgun (RIGHT hand, RMB): "RAIJIN-12" arc shotgun ("shotgun taser")
- **Gameplay is exactly a shotgun.** Presentation is electric.
- **Pellets:** 10 hitscan pellets per blast (×2 on an Inazuma Overload blast).
  - Spread: a random disc of radius 0.085 rad. Range 48 m.
  - Damage 13 per pellet × falloff × mutator. Falloff is
    `clamp(1 − (dist − 7)/22, 0.3, 1)`.
  - **Headshot ×2:** a pellet counts as a headshot if it hits above the
    enemy's `head_y`. The blast counts as a headshot (popping the head on a
    kill) if any pellet hit the head and ≥3 pellets hit that enemy.
- **Effect per enemy:** all pellet damage is summed into one hit.
  - Poise damage = that damage × (1 + 0.6 per Ikazuchi Surge rank).
  - Knockback 6 + 8 per Ikazuchi Surge rank.
  - Kagutsuchi Flame ignites the target (§3.6).
- **Ammo is CELLS.** 4 max to start (+2 with Inazuma Overload). Each blast uses
  1 cell. Below 2 cells, they recharge by 1 every 2.5 s (the Yomi Blackout
  mutator turns this off).
- **Empty:** a 0.3 s cooldown, the "empty" fizzle sound and a "NO CHARGE – USE
  THE BLADE" flash.
- **Cooldown** 0.72 s. Trauma 0.32, recoil, FOV kick 4, hitstop 0.035 on hit,
  muzzle light (cyan-white).
- **Visuals:**
  - Every second pellet is a **jagged, forking lightning arc** from the muzzle
    to its impact point. Arcs live about 0.1 s and re-randomise their shape
    every 0.022 s.
  - Three short arcs spray off the electrodes on every blast.
  - Wall hits give blue sparks and a star flash.
  - Enemies hit are **electrified** for 0.45 s: a blue flicker, with small
    arcs crawling over the body every 0.04–0.11 s.
  - Shotgun kills add blue sparks, smoke and a final arc to the usual gore.
- **Sound:** an electric crack + crackling discharge + buzz + deep thump. A
  capacitor whine climbs into a lock "clack" as the drum turns (0.16 s after
  the shot). A fizzle when empty. A "zap" at the first enemy hit.
- **Look:** **PLACEHOLDER, final design OPEN.**
  - Current model: three electrode prongs, four capacitor coils (alternating
    glowing and copper) around an open glowing barrel core, a top heat sink,
    a cyan stripe, and a hex drum of six power cells that turns 1/6 per blast
    (ease-out-back).
  - The coils flare on the blast, sit dim while recharging, then hum when
    ready. With no cells they sputter. Idle arcs crackle between the prongs
    every 0.25–1.1 s.
  - Ten LED cell gauges sit on the side.
  - After a shot: recoil kick, then a roll as the drum turns.

### 3.4 Glory kills (Doom 2016 style)
**Trigger:** pressing **F** (the `finisher` action, rebindable) while a
**staggered** enemy is in reach, like Doom (2016). This replaces the old
"execution" and the earlier slash trigger (owner's request, 2026-10-18).
- **Reach:** within 4.5 m of the enemy's body, within 60° of the crosshair,
  with no wall in between. Of several, the one nearest the crosshair is
  taken. The current target is kept out to 5.5 m and 80° so the prompt never
  flickers at the edge.
- **Window:** the whole stagger (`stagger_time`, 1.8–3.2 s by enemy; unchanged).
- **Input buffer:** 0.18 s, as for the katana: pressing F just before an
  enemy staggers or comes into reach still counts.
- **Prompt:** while a target is in reach, a gold key cap with the bound key
  and "GLORY KILL" ("ONIKIRI" on a boss whose KAMAE is broken, §5.5) sits in a fixed spot under the
  crosshair (§9.7), and that enemy's stagger marker turns gold and grows.

**Plunge (owner's request, 2026-10-18):** a glory kill from above, always
with the katana. The same `finisher` key and prompt ("PLUNGE").
- **When:** airborne, the floor you last stood on is at least **2.0 m above
  the foe's feet** or a jump pad threw you up since you last stood on a
  floor (owner, 2026-10-18), you are still at least **1.2 m above them**, they are
  within `1.5 + 0.75 × drop` m (at most 7 m) of you horizontally (past their
  body), within 35° of the crosshair (kept to 45°), with nothing in between.
  A plain jump or double jump from the foe's own level never qualifies; a
  jump from a high surface does, as stepping off it would.
- **Who:** horde enemies only: any grunt or gunner; brutes are armoured and
  must be staggered first. **Never bosses** (the owner, 2026-10-18: bosses
  get no glory kills; their fights end on a posture break instead).
- **Wins** over a glory kill on the same press.
- **The finisher:** a dive onto the foe at 24 m/s (0.12–0.3 s, real time),
  blade raised in a reverse grip; the stab (pose, slice + slam + gore,
  upward blood geyser, floor sparks, hitstop 0.07, trauma 0.6, impact frame
  0.06, land dip); the kill 0.1 s later (gore `split`, kill tag
  **SAKAHOKO DROP**); the rip-out at +0.28; you step down off it to the floor
  at +0.16 to +0.4; length dive + 0.5 s.
- First time a plunge is lined up, the hint "HIGH ABOVE A FOE?  PRESS F TO
  PLUNGE" shows once.

**On start:**
- Executions +1, **+3 cells**, **heal 20** (×2 under the Akatsuki mutator).
- The player is **invulnerable**, input and mouse look are locked, and
  velocity is zero.
- The world goes to **slow motion ×0.25 for 1.0 s**. The finisher itself
  runs in **real time**.
- **Camera:** lunge 0.13 s (ease-out cubic) to a stand point
  `enemy + dir_to_player × (radius + 0.85)` (or +1.25 for brutes and
  bosses). Then lock yaw and pitch on the enemy over 0.1 s.
- The enemy is pinned (frozen AI, facing the player), and its stagger marker
  is hidden.
- **Presentation:** the KIRI glory-kill look (§9.8: cross cuts, the picture
  cut, a diagonal letterbox, the GLORY KILL card with its points), data
  streaks, an impact frame on each beat, FOV −10, the dash whoosh.

**Finisher selection:**
| Situation | Finisher | Beats (seconds from start) | Gore |
|---|---|---|---|
| Boss with its KAMAE broken (the ONIKIRI, §5.5) | X-cut then point-blank blast | 0.12 slash, 0.26 slash, 0.46 aim, 0.56 blast + kill; length 0.95 | The blow, or full kill |
| Brute | Climb up, chop the skull, blast down into the neck | 0.02 raise overhead, 0.20 chop, 0.42 aim down, 0.52 blast + kill; length 0.95; the camera rises 0.9 m | headpop |
| Plunge (see above) | Dive, stab down through the collarbone, rip out | dive 0.12–0.3, stab at the dive's end, kill +0.1, rip +0.28; length dive + 0.5 | split |
| Player airborne and >0.9 m above the enemy | Falling overhead cut | 0.02 raise, 0.16 chop, 0.20 kill; length 0.72 | split |
| Behind (enemy facing · to-player < −0.35) | Stab through the back, rip upward | 0.12 thrust, 0.38 rip up, 0.50 kill; length 0.82 | split |
| Front (50/50) A | Impale, then the shotgun under the chin | 0.12 thrust, 0.36 aim under the chin, 0.48 blast + kill; length 0.82 | headpop |
| Front B | Decapitating slash, then blast the chest | 0.12 neck slash, 0.38 aim, 0.46 blast + kill; length 0.80 | execution |

**Each beat:**
- Viewmodel pose (thrust, rip up, overhead, chop, chin, point, down, aside,
  ready) or a slash animation, plus its sound.
- A blood burst, an enemy reaction (squash, flash, lurch), hitstop 0.05–0.06,
  trauma 0.3–0.5 and an impact frame 0.05 s.
- Blast beats fire the shotgun visuals (5 arcs to the head or chest) and its
  sound.

**The kill beat:**
- `enemy.execute(dir, gore_mode)`: hitstop 0.09, execution sound, trauma
  0.75, execution flash, impact frame 0.09, FOV zoom.
- Kill tag "GLORY KILL", points ×2, +4 extra health orbs.
- Hyakunin-giri staggers every enemy within 9 m.

**Bosses never get a glory kill** (owner, 2026-10-18). F on a boss whose
KAMAE is broken plays the boss finisher above as the **ONIKIRI** blow (§5.5):
- It deals **20% of max HP** with a blood geyser and a big damage number; the
  break ends and the boss is knocked back. At ≤20% HP left it kills.
- The holographic cut-in "ONIKIRI!" plays as it starts (no stamp at the
  blow, so the cut-in is read in full).
- It heals and charges cells like a glory kill but doesn't count as one.

**On end:** release the enemy if it is alive, keep 0.35 s of invulnerability,
hop back (−dir × 3 + up 2), katana cooldown 0.12.

### 3.5 Stagger and poise (all enemies)
- Each enemy has **poise**. Damage reduces it. When it hits 0 the enemy is
  **STAGGERED** for `stagger_time`: a pulsing marker, dim eyes and a windup
  sound. Hint the first time: "STAGGERED! PRESS F FOR A GLORY KILL" (the
  bound key's name).
- Poise regenerates once no hits land for 2.0 s. It regains 35% of max per
  second.
- The shotgun is the main stagger tool. Armoured enemies (brutes) need it.
- **Bosses have no poise** and are never staggered by hits or Hyakunin-giri;
  they have the KAMAE bar instead (§5.5).

### 3.6 Damage over time (Kagutsuchi Flame)
Burn lasts 3 s at 10 × rank dps, ticking every 0.5 s, with embers. Kill tag
"CREMATED".

### 3.7 Health orbs
- Drops: grunt 30% chance of 1; gunner 50% chance of 1; brute 4; Shuten 12.
  Glory kills add +4.
- Each orb heals 6 and is pulled toward the player.

### 3.8 Run level and augments (in-run, resets each run)
- XP comes from kills (grunt 10, gunner 18, brute 60, Kurokage 320, Tetsugumo
  420, Shuten 500). XP to the next level = `60 + (level − 1) × 40`.
- **Each level-up** pauses the game (tree paused) and offers **3 augments**
  (it opens once any centre-screen moment has finished: FINISH, the payout,
  a boss card, a stamp; see §9.9),
  drawn as a seeded Fisher–Yates pick from the cards not yet at max rank (and
  whose `requires` card, if any, is owned). Choose with click or 1/2/3.
  Several pending level-ups chain.
- **Augments change a rule of the loop**, never a plain +% number (owner,
  2026-10-18: picks should build a way of playing, like Balatro's Jokers).
- **Builds:** every card but Kongo Heart sits in one or two named builds of
  three cards. Builds are labels only: no hidden set bonus.
  - An offered card that shares a build with a different card you own shows a
    gold **RECOMMENDED** tab above it, a gold border, and a brighter sting as
    it deals. A rank-up of an owned card is not a link.
  - **Linked offers:** once you own a build card, if no linking card is among
    the three drawn, the first linking card in the shuffled order takes the
    last slot (no extra RNG draw). Same seed and same picks give the same
    offers.
  - Each card's bottom lines name its builds with the count you would own
    after picking ("RONIN 2/3"). Picking the second card of a build pops
    "<BUILD> LINKED"; the third stamps "<BUILD> COMPLETE" once the cards
    close. The pause screen lists your builds.

| id | Name | Tag | Max | Effect |
|---|---|---|---|---|
| fork | RAIJIN'S FORK | SHOTGUN | 1 | From each of the first 4 enemies a blast hits, an arc leaps to the 2 nearest enemies within 7 m it missed: 40% of that enemy's blast damage (min 15), same stagger rules |
| ikazuchi | IKAZUCHI SURGE | SHOTGUN | 2 | Blasts stagger 60% harder per rank and knock back +8 per rank |
| inazuma | INAZUMA OVERLOAD | SHOTGUN | 1 | +2 max cells. The blast that spends the last cell fires 20 pellets and staggers every non-boss it hits (bosses take ×3 poise) |
| dragon | KAGUTSUCHI FLAME | SHOTGUN | 2 | Arcs set enemies alight (burn, §3.6) |
| hitodama | HITODAMA CHAIN | SHOTGUN | 1 | Requires Kagutsuchi Flame or Homura Edge. A burning enemy that dies ignites every enemy within 5 m |
| hachiman | HACHIMAN FOCUS | SHOTGUN | 1 | Spread 0.04 rad (from 0.085); falloff starts at 18 m (from 7 m) |
| yoichi | YOICHI'S MARK | SHOTGUN | 1 | A headshot blast (§3.3) refunds its cell |
| gasha | GASHADOKURO BURST | SHOTGUN | 1 | A shotgun headshot kill explodes: 30 damage within 5 m and staggers non-bosses |
| edge | MASAMUNE EDGE | KATANA | 1 | The third combo cut does ×2 damage, ignores armour and deals 100 poise |
| wave | SUSANOO'S WAVE | KATANA | 2 | Every (4 − rank) slashes launch a piercing blood blade (26 m/s, 40 + 15 × rank damage); with Masamune Edge every heavy cut launches one too |
| yata | YATA MIRROR | KATANA | 1 | A deflected bolt flies back to its shooter as usual and two copies fan out ±0.35 rad beside it at the same speed and damage, with no target (no extra cells, count or popup) |
| homura | HOMURA EDGE | KATANA | 1 | Katana hits ignite (burn rank 1); burning enemies take katana damage ×1.5 |
| chimatsuri | CHIMATSURI STEEL | KATANA | 2 | Heal 1 HP × rank per enemy the katana hits; healing past full HP banks, every 6 HP banked = +1 cell |
| battery | BLOOD BATTERY | KATANA | 2 | Katana kills charge +1 extra cell per rank |
| kurama | KURAMA LEAP | GLORY | 1 | Glory kill reach 9 m (kept to 10 m). The lunge takes 0.13 s × distance / 4.5 m (max 0.26 s) and every beat shifts back by the extra |
| chain | HYAKUNIN-GIRI | GLORY | 1 | Glory kills stagger every enemy within 9 m |
| kamaitachi | KAMAITACHI RING | GLORY | 1 | A glory kill fires 8 blood blades flat out from the body (60 damage each) |
| taiko | TAIKO FRENZY | GLORY | 1 | A glory kill adds +5 combo and freezes the combo timer for 3 s |
| idaten | IDATEN DRIVE | DASH | 1 | +1 dash charge; every dash charges 1 cell |
| fujin | FUJIN'S RETURN | DASH | 1 | Shotgun kills (including Raijin's Fork leaps) refund one dash charge |
| dashcut | KAGE STEP | DASH | 2 | Dashing through enemies slices them (40 × rank) |
| utsusemi | UTSUSEMI SHELL | DASH | 1 | A hit that would hurt you spends a dash charge instead (0.4 s invulnerable); once every 3 s |
| chrome | KONGO HEART | BODY | 3 | +25 max HP and a full heal |
| sanzu | SANZU REPRIEVE | BODY | 1 | Once per wave, a killing blow leaves you on 1 HP with 1.5 s invulnerability |

| Build | Cards | How it plays |
|---|---|---|
| STORM RUNNER | Idaten Drive, Fujin's Return, Inazuma Overload | Blast, kill, dash, recharge, blast: never stop moving |
| THUNDER CHAIN | Raijin's Fork, Ikazuchi Surge, Inazuma Overload | One blast staggers a whole pack |
| INFERNO | Kagutsuchi Flame, Homura Edge, Hitodama Chain | Fire spreads through the crowd |
| HEADHUNTER | Hachiman Focus, Yoichi's Mark, Gashadokuro Burst | Mid-range headshots that pay for themselves |
| RONIN | Masamune Edge, Susanoo's Wave, Yata Mirror | Count to three; the blade does almost everything |
| BLOOD ENGINE | Chimatsuri Steel, Blood Battery, Sanzu Reprieve | The katana feeds health and cells; live on the edge |
| EXECUTIONER | Kurama Leap, Hyakunin-giri, Kamaitachi Ring | Glory kill to glory kill across the rooftop |
| SHOWSTOPPER | Taiko Frenzy, Hyakunin-giri, Ikazuchi Surge | Stagger everything, glory kill for score |
| GHOST | Kage Step, Utsusemi Shell, Idaten Drive | Dash through everything, untouchable |

Tag colours: KATANA cyan, SHOTGUN electric blue, GLORY hot pink, DASH acid
green, BODY pale gold; links and RECOMMENDED in gold.

Debug: `--augments=id,id:2|all` starts a run with cards picked; `--cardtour`
deals every card for a layout check.

---

## 4. Enemies

Common to every enemy:
- They spawn with a vertical beam, drop in from about 7–9 m up, land with
  sparks, then chase.
- Attacks are always **telegraphed**: a windup, glowing eyes and a sound.
- Steering keeps them apart and slides them along walls when stuck.
- `damage_mult = 1 + (hp_scale − 1) × 0.5`.

| Enemy (in-game name) | HP | Speed | Poise / stagger | Armour | Points | Behaviour |
|---|---|---|---|---|---|---|
| **Grunt** ("Ashigaru") | 45 | 5.8 | 22 / 1.8 s | none | 100 | Rushes in. Melee windup 0.5 s, hits 11 within 2.7 m in front. Recovers 0.55 s, cooldown 0.9–1.5 s |
| **Gunner** ("Teppo") | 80 | 4.8 | 45 / 2.2 s | none | 150 | Strafes and keeps 8–17 m away. With line of sight, windup 0.72 s, then fires a deflectable bolt (11 m/s, 12 damage). **From wave 6: a 3-bolt fan** (±0.12 rad). Cooldown 2.2–3.2 s. Hint: "SLASH INCOMING BOLTS TO DEFLECT THEM" |
| **Brute** ("Kanabo") | 520 | 3.8 | 160 / 2.8 s | 0.35 | 600 | Melee windup 0.82 s, hits 26 within 3.6 m + radius. **Charge:** roar, 0.8 s windup, 15.5 m/s dash for up to 1.15 s, hits 30 with big knockback, slams into walls. Charge cooldown 6–8.5 s. Hint: "KANABO BRUTES ARE ARMORED: SHOTGUN THEM TO STAGGER, THEN GLORY KILL" |

Size and mass: grunt and gunner radius 0.45, height 1.8, head_y 1.52 (gunner
mass 1.3); brute radius 0.75, height 2.6, head_y 2.12, mass 3.5.

Bodies are segmented low-poly humanoids built from boxes: hips, torso, head,
arms and legs as separate parts, so they can dismember (§9.4). Each type has
its own colours and glowing eyes. Animation is procedural: walk cycle,
windups, staggers.

---

## 5. Bosses

### 5.1 Rules
- **Every 3rd wave is a boss wave** (3, 6, 9, …). A boss wave has no mutator.
  (A proposal to spread bosses across map stages is in §6.4; not built.)
  Its intro reads "BOSS INCOMING" with an alarm, then the **boss intro card**:
  the name and epithet slide in on a band, with the boss_intro sound and the
  boss's own music.
- **Cycle order:** cycle 1 is Kurokage and Tetsugumo in seeded order, then
  Shuten last. Later cycles are a seeded shuffle of all three.
- **Boss HP scale:** `1 + 0.45 × (cycle − 1) + 0.03 × (wave − 3)`.
- **Reinforcements** every 7 s (Tetsugumo 10 s): 1–2 grunts if fewer than 4
  adds are alive. Tetsugumo can also call 3 adds herself.
- **Enrage at 50% HP:** speed ×1.2 (Shuten goes to 5.6), faster specials, a
  roar, and a "<NAME> IS ENRAGED" message.
- **No glory kills on bosses:** pressure breaks their KAMAE, then F lands
  the ONIKIRI (§5.5).
- **Boss bar:** top centre, showing "NAME – EPITHET", the HP bar and the
  KAMAE bar.

### 5.2 The bosses

**Kurokage, Blade of the Null Signal** (the ninja)
- Felled line: **SHADOW DELETED**.
- HP 2600, speed 5.2, radius 0.5, height 2.1, head_y 1.72, KAMAE 900, stagger
  2.6 s, armour 0.55, XP 320, points 5000.
- **Dash-slash chain:** 2 dashes (3 when enraged). Each has a floor
  telegraph line 16 m long (neon). Windup 0.62 s (0.42 enraged), shortened on
  follow-ups. Each dash hits 20 with knockback.
- **Shuriken fan:** deflectable, 13 m/s, 10 damage, spread 0.16 rad. His
  signature volley: the whole fan is white-hot (§3.2 Perfect deflect).
- **Blink:** vanishes in smoke and reappears behind you.
- **Melee combo:** 2 hits (3 enraged), 16 damage each.
- Strafes at mid range. Specials every 3.2–4.6 s (2.2–3.2 enraged).
- Look: brighter suit with neon piping, a long glowing blade and a trailing
  scarf.

**Tetsugumo, Chrome Broodmother** (the spider mech)
- Felled line: **MACHINE DECOMMISSIONED**.
- HP 4400, speed 2.6, radius 1.7, height 3.6, head_y 2.5, KAMAE 1400, stagger
  3.2 s, armour 0.35, XP 420, points 7000, mass 14.
- **Sweeping gatling:** windup, then a sweep of 7-damage, 14 m/s bolts that
  can be deflected. The sweep ends on her signature volley: one heavy
  white-hot round straight at the player (12 m/s, 14 damage; §3.2 Perfect
  deflect).
- **Missile strikes:** beeps, then several missiles land at red-ring
  telegraphs around the player (2.6 m radius, 20 damage, ~1.5 s delay each).
- **Stomp:** within 6 m. A 12 m shockwave that does 22 damage; jump over it.
- **Calls her brood:** 3 adds (skipped if more than 6 enemies are alive).
- Keeps 8–15 m away and strafes. Specials every 4.2–5.6 s (3.0–4.2 enraged).
- Look: six legs, gatling, missile pods, glowing core. It explodes on death.

**Shuten, the Overclocked Daemon** (the oni)
- Felled line: **DAEMON PURGED**.
- HP 5200, speed 4.4 (5.6 enraged), radius 1.05, height 3.4, head_y 2.8,
  KAMAE 1600, stagger 3.0 s, armour 0.5, XP 500, points 8000, mass 9.
- **Melee:** 2–3 hit combo, windup 0.7 s (0.45 on follow-ups), 32 damage each
  within 4.6 m + radius, with knockback.
- **Leap slam:** a 24 m shockwave that does 26 damage; jump over it. Hint:
  "JUMP OVER THE SHOCKWAVE".
- **Charge:** like the brute's.
- **9-bolt fan volley:** enraged only. 14 damage, spread 0.13 rad. His
  signature volley: every bolt is white-hot (§3.2 Perfect deflect).
- Specials every 5–7 s (3.5–5 enraged).

### 5.3 Boss death sequence ("loud, then quiet")
1. The boss dies with huge gore (Tetsugumo explodes). Slow motion ×0.12 for
   2.6 s. **The music cuts to silence** (a fast fade).
2. **FINISH splash** (0–0.82 s): see §9.8.
3. Every remaining add **shorts out**: frozen in place, facing as it was,
   electrified for 3 s. After 0.6 s of game time they chain-explode one by
   one every 0.12 s.
4. At **1.25 s**, the **souls card** with the boss's felled line (gold) and a
   small subtitle "NAME – EPITHET", with the "felled" sound. It lasts 4.6 s
   (§9.8).
5. At **5.4 s** the combat playlist resumes on the next track.
6. The wave-clear tally waits until the card is nearly done. It includes the
   **BOSS BOUNTY** row and fireworks at the cash-out (§7.3).
7. **Boss rewards** (§11.2) are shown after the tally. **Not built yet.**

### 5.4 Boss naming (applies to all future bosses too)
Bosses use FromSoftware naming *grammar* with a cyberpunk theme and a
Japanese myth or history root (§13). **Never reuse FromSoftware names.**
- Patterns:
  - **Name, the Epithet** (Shuten, the Overclocked Daemon).
  - **Name, Title of Something** (Kurokage, Blade of the Null Signal).
  - **Name, Title** (Tetsugumo, Chrome Broodmother).
  - **Title + Name** (Overseer Halvard).
  - **Group or descriptive** (Gridlock Sentries).
  - **Ominous and abstract** (Mother Server).
- Each boss has its own fixed felled line, in the form "<NOUN> <PAST
  PARTICIPLE>" with a cyber flavour (SHADOW DELETED, MACHINE DECOMMISSIONED,
  DAEMON PURGED).
- **Variants** keep the name and change the epithet or state, each with its
  own felled line. Examples: "Kurokage, Ghost Build", "Tetsugumo, Queen of
  the Scrapyard", "Shuten, Unbound".
- Pool of future boss names (original ideas):
  - The Firmware Pontiff
  - Overseer Halvard, Warden of the Grid
  - Netrunner Vex, the ICE Breaker
  - Gridlock Sentries
  - Sister Nyx, Mother of Clones
  - The Last Executive
  - Mirrorcode, the Copied Self
  - Okaasan, Matriarch of the Syndicate
  - Raiko, the Voltage Maiden
  - The Signal That Hungers
  - Iron Shogun Daimyo-X
  - Deadlink Hydra
  - The Static Choir
  - Ghostwire Ronin
  - Mother Server
  - Baron Kessler, Augment Collector
  - Carbon Saint Ilse
  - Kernel Wraith of the Undercity
  - Orochi Protocol, the Eight-Headed Network
  - Jorogumo, Silk-Server Matriarch
  - Gashadokuro, the Scrapyard Colossus
  - Nue, Chimera of the Grid
  - Tamamo, Nine-Tailed Phantom of the Wire

### 5.5 KAMAE and the ONIKIRI (boss posture; owner, 2026-10-18)
Bosses have a posture bar, **KAMAE** (a fighting stance). Fighting
aggressively fills it; when it is full the stance **breaks**, the boss
reels, and the player lands a devastating blow, the **ONIKIRI**. It replaces
glory kills on bosses entirely. Values live in `scripts/boss_kamae.gd`.
- **Size:** Kurokage 900, Tetsugumo 1400, Shuten 1600, × the boss's
  `damage_mult` (so later cycles take a little more).
- **What fills it** (poise damage × a factor per source): katana ×1.6 (an
  18-poise hit gives about 29, armour or not: the blade is the pressure
  tool), shotgun ×0.6 (a point-blank blast gives about 78, less at range),
  a returned bolt by its HP damage ×0.5 instead (about 48 for today's 95;
  steady for a returned gatling stream, a big swing for a shuriken fan; a
  PERFECT deflect on a boss's signature volley adds +20% of the bar, §3.2),
  MASAMUNE EDGE's heavy third cut ×1.0 (100), Susanoo's Wave and Kage
  Step ×1.0, burning nothing (explosions never
  hit bosses).
- **Glory kills nearby:** a glory kill on an add within **15 m** of the boss
  fills **12%** of its bar. The adds feed the boss fight.
- **Backing off:** after **2.5 s** without pressure the bar drains at **7%
  per second** at full HP. Gentle: a short retreat to heal costs little.
  A hurt boss steadies itself more slowly (Sekiro; owner, 2026-10-19, with
  Perfect Deflect): the drain scales with its HP, linearly down to **30%**
  of that at no HP (4.55%/s at half HP, 2.1%/s near death), so pressure
  sticks better as the fight goes on. `DRAIN_AT_NO_HP` in
  `scripts/boss_kamae.gd`.
- **The break:** at full, a heavy clang, hitstop 0.12, shake 0.5, an impact
  frame and the stamp **KAMAE BROKEN** (gold, in the top lane, §9.7). The boss reels (its
  STAGGER state, armour off) for its stagger time **+1.5 s** (Kurokage 4.1 s,
  Tetsugumo 4.7 s, Shuten 4.5 s). The first time, the hint "KAMAE BROKEN!
  PRESS F FOR ONIKIRI". The bar then shows the time left to strike, glowing
  gold to white.
- **The ONIKIRI:** F (the `finisher` action, same reach and buffer as a
  glory kill, red prompt "ONIKIRI") plays the boss finisher (§3.4): 20% of
  max HP, or the kill at ≤20%. When it kills, the boss falls "loud, then
  quiet" (§5.3) and the kill tag reads ONIKIRI.
- **After a break** (blow landed or window missed) the bar is empty and fills
  again. No limit on breaks; at the bot's relentless pace a first-cycle boss
  breaks once or twice per fight.
- **The bar:** under the HP bar, a gold "KAMAE" label and a bar that
  fills the rest of the boss plate's width from the middle out; it runs white-hot from 80%. The word never
  moves or changes. The first boss shows the hint "KEEP ATTACKING TO FILL
  ITS KAMAE BAR - A FULL BAR BREAKS IT".

### 5.6 Boss movesets (owner, 2026-10-18)
Bosses fight like Souls and Sekiro bosses: they read the player, step out of
lazy attacks, mix fast strings with held swings, and each has one area move
and one **RED SIGNAL** attack. Every move is telegraphed and answered with
the core verbs (dash, jump, deflect, katana pressure), and every big move
leaves a punish window that feeds KAMAE. Code: `scripts/boss.gd` (all three
bosses are `Boss` now), floor hazards in `scripts/boss_hazard.gd`. Move
names below are design labels; only "RED SIGNAL" and "PERFECT" appear on
screen.

**Shared:**
- **Sidestep:** aimed at from more than 7 m (+ radius) for 0.35 s, the boss
  steps out of the line (cooldown 4 s; 6 s for the run's first boss). Never
  from up close and never mid-attack (only from its chase).
- **Delayed swings:** 30% of melee windups (Kurokage's and Shuten's combos,
  Tetsugumo's stomp) hold 1.7× as long; the pose rises slower and the eyes
  stay dim, then flare with a hiss 0.22 s before the hit.
- **Punish windows:** every recovery of 0.8 s or more (after a dash chain,
  gatling, missiles, a summon, stomp, slam, charge, area move or RED SIGNAL) drops the
  armour for the whole recovery (+0.2 s on the first boss), dims the eyes,
  and KAMAE fills ×1.5 meanwhile.
- **RED SIGNAL:** a spinning red diamond over the head, an alarm, then a
  beep 0.2 s before it lands. It can't be deflected or traded with: get
  clear, or dash through it. Being dashing when its hit would connect is a
  **PERFECT**: a cyan stamp, a short slow motion (×0.35 for 0.4 s) and +15%
  KAMAE. First time, the hint "RED SIGNAL: GET CLEAR, OR DASH THROUGH IT AT
  THE LAST MOMENT". Started from 3 to 22 m away (Shuten 3 to 9.5 m, his
  grab's reach). Cooldown 14 s (×0.9–1.2); area moves 8 s (×0.9–1.2).
  Cutting one short (a KAMAE break) clears its red marks at once, and a
  felled boss takes its floor hazards with it.
- **Pacing:** in the first cycle (waves 3, 6, 9) the area move and RED
  SIGNAL wait for the enrage at 50% HP; the run's first boss also telegraphs
  them 25% longer. From the second cycle (wave 12) bosses use everything
  from the start. Sidesteps, held swings and punish windows are always on.
- **Seeds:** a boss rolls its dice from `hash(run_seed × 13 + wave)`, so the
  same seed gives the same fight without drawing from the wave stream.

**Per boss:**

| Boss | Sidestep | Area move | RED SIGNAL |
|---|---|---|---|
| Kurokage | Afterimage: smoke where he stood, 0.22 s at 18 m/s to the side | **Smoke ring** (within 5 m of him): smoke at his feet, a 5 m full-circle cut after 0.7 s, 18 damage; step out or jump. Recovery 0.9 s | **NULL CROSS** (0.9 s): he vanishes and three red lines (18 m, 60° apart) cross where you stand; he reappears at the first, then dashes along each in turn (34 m/s, 26 damage, 0.25 s between). Recovery 1.2 s |
| Tetsugumo | Back-leap: jumps away and lands with a 7 m shockwave (12 damage) | **EMP field** (any range): three 2.6 m cyan zones (on you and 3.5–5 m either side) crackle 1.2 s, then stay live 1.8 s, 12 damage every 0.6 s; jumping clears them. Recovery 0.8 s | **BROOD BARRAGE** (1.0 s, pods glowing): a 7.5 m ring of 10 missiles (1.2 s), a 4.5 m ring of 6 (1.6 s) and one in the middle (2.0 s), 20 damage each; both rings share one gap, the way out, opening towards the arena's middle (±0.6 rad). Recovery 1.2 s |
| Shuten | Shoulder barge: 0.3 s at 14 m/s to the side | **Fissures** (within 14 m): five fire lines (14 m, 1.6 m wide) crack out in a star from his fist after 0.8 s, 24 damage; jump them or stand between. Recovery 1.0 s | **DAEMON GRAB** (1.0 s, from 9.5 m or closer, aims until 70%): a 0.45 s lunge at 17 m/s that grabs and hurls for 34 damage. A whiffed grab leaves him open 1.8 s. Recovery 1.2 s |

All damage × the boss's `damage_mult`.

---

## 6. Waves, mutators and difficulty

### 6.1 Difficulty philosophy
- **Difficulty rises the further you get:** more and tougher enemies, harsher
  mutators, tougher bosses each cycle.
- The **opening waves of every run stay easy and welcoming** (low floor).
  Going deep is where skill shows (high ceiling).
- Content earned from rewards (new maps, boss variants, mutators) can be
  tougher.
- **The persistent Player Level never changes difficulty.**
- The current curve below is the prototype's. **Tune the full curve by
  playtesting** (OPEN), keeping wave 1–3 gentle.

### 6.2 Wave director (prototype formulas)
- `hp_scale(w) = 1 + 0.06(w − 1) + 0.05 × max(0, w − 9)`.
- **Composition (normal wave):**
  - grunts = `(5 + 2w) × mut.grunt_count`
  - gunners = 0 if w < 2, else `min(1 + (w − 2), 9) × mut.gunner_count`
  - brutes = 0 if w < 4, else `1 + (w − 4)/3`, + `mut.extra_brutes`
  - Grunts and gunners are shuffled together (seeded). Brutes are inserted at
    seeded positions after the first third.
- **Spawning:**
  - Max alive `min(8 + 2w, 22)`.
  - Groups of 1–3 every `max(0.8, 1.8 − 0.06w)` s.
  - Spawn points are 11–46 m from the player (18 points on the rooftop map).
- **Flow:** intro (until the HUD countdown is done; 6 s fallback) → spawning
  → cleared once the queue is empty and none are alive → tally (until the HUD
  tally is done; 12 s fallback) → next wave.
- **On clear:** +2 cells, the mutator is cleared, the storm stops.
- **First wave hint:** "KATANA KILLS CHARGE THE SHOTGUN – KEEP BOTH HANDS
  BUSY".

### 6.3 Mutators (seeded, from wave 2, 35% skip chance, never on boss waves)
In-game names drop macrons (§13). A roll always makes two draws from the
wave stream (chance, pick), never repeats the previous wave's mutator, and
only picks mutators whose `min_wave` has come (the harsher ones wait so
waves 1 to 3 stay easy). The pool grew from 9 to 15 on 2026-10-18 at the
owner's request for more variety.

| id | Name | Effect | Score × | From wave |
|---|---|---|---|---|
| overdrive | OKURI-INU HUNT | Enemies move 25% faster | 1.5 | 2 |
| glass | MURAMASA'S CURSE | You deal and take +50% damage | 1.3 | 2 |
| bloodmoon | AKATSUKI | Enemies ×1.4 HP; glory kills heal double | 1.4 | 2 |
| drymag | YOMI BLACKOUT | No passive cell recharge | 1.3 | 2 |
| swarm | HYAKKI YAKO | 60% more grunts, at 70% HP | 1.2 | 2 |
| snipers | TEPPO VOLLEY | Double the gunners | 1.3 | 2 |
| ironclad | KANABO VANGUARD | Two extra brutes | 1.4 | 2 |
| storm | RAIJIN'S STORM | Lightning, thunder and heavy rain, and every 3.5–6 s a strike lands within 2.5 m of you: a red ring for 1.2 s, then 16 damage in 2.4 m (enemies in it take 32) | 1.4 | 3 |
| grudge | ONRYO'S GRUDGE | Each non-boss enemy that dies leaves a red ring that bursts 1.1 s later: 14 damage in 2.2 m (enemies take 28, so they chain); at most 6 rings at once | 1.3 | 3 |
| plated | KABUTO PLATE | Grunts and gunners have armour 0.4: the katana does 40% until they are staggered | 1.3 | 4 |
| matsuri | MATSURI RUSH | The combo window is 2 s instead of 4 s | 1.4 | 2 |
| kanashibari | KANASHIBARI | Dashes take twice as long to recharge | 1.3 | 3 |
| hannya | HANNYA'S WRATH | A non-boss enemy below half HP enrages once: speed ×1.4, damage ×1.3, red eyes | 1.3 | 4 |
| umibozu | UMIBOZU SWELL | Up to 60% more enemies alive at once, spawning twice as often | 1.4 | 4 |
| senryo | SENRYO BOUNTY | Headshot and glory kills score ×2; every other kill scores half | 1.2 | 2 |

Score multipliers are shown with one decimal, so they are set to one
decimal. Removed 2026-10-18: JOROGUMO'S BITE (kills heal 2 HP, enemies hit
30% harder), too close to Akatsuki's heal-for-risk trade. IDATEN'S HASTE was
renamed OKURI-INU HUNT so it no longer shares a root with the Idaten Drive
augment. Mid-wave hazards (storm strikes) draw from `Game.rng_hazards`,
reseeded from the seed at every wave start, so a wave's length never shifts
later waves. Clearing a wave defuses every pending ring, so nothing hurts you
during the tally.

The mutator name shows under the wave label on the HUD, with its multiplier.
Debug: `--mutator=id` forces one on every regular wave.

### 6.4 Map stages and the boss schedule (PROPOSAL, not built; owner idea, 2026-10-18)
**Status: an idea to build once a second map exists. Nothing here is in the
game yet.** Today a boss comes every 3rd wave (§5.1) and the seed picks one
map for the whole run (§7.5). The open decision is in §19.

**The idea, in the owner's words (2026-10-18):** "Maybe each map has its own
boss. For example, if a boss appears every 3rd wave then essentially the map
changes after every boss defeat." And: "first boss on 10th wave / map 1,
second on 15th and third on 20th (both map 2). The idea is that bosses become
more frequent but no more than every 3rd wave and each map has more bosses
than previous." And: "Seeds can also determine which order maps/bosses
appear." He asked for it to be documented and balanced before it is built.

**How it would play.** A run becomes a journey through **stages**. Each stage
is one map. Stage 1 holds 1 boss, stage 2 holds 2, stage 3 holds 3, and so
on. The last boss of a stage is that map's own boss, its **guardian**;
felling it ends the stage, and after its tally and reward card the run moves
to the next map. The other bosses in a stage are **rematches** with bosses
already felled earlier in the run, so every new boss arrives as a stage's
climax. Difficulty never resets on a new map: it follows the wave number, as
today. (Working words for this section; any player-facing name for a stage
comes from §13 when it is built.)

**Rules that hold in every version of the schedule:**
- Never two boss waves closer than 3 waves apart (the owner's floor).
- The gaps between bosses only shrink or stay the same as a run goes on.
- Waves 1 to 3 are never boss waves, and stay as easy as today (§6.1).
- Each stage holds at least as many bosses as the one before (one more each
  stage, up to a cap so the scenery keeps changing; default cap 4).
- A boss wave still has no mutator (§6.3).
- The same seed gives the same map order, the same boss on the same wave and
  the same rematches (§7.5).

**Two schedules.** Boss waves, with the stage each belongs to (| = map
change):

| | Stage 1 | Stage 2 | Stage 3 | Stage 4 | After |
|---|---|---|---|---|---|
| Today (one map) | 3, 6, 9, 12, 15… | | | | every 3rd |
| Owner's sketch | 10 | 15, 20 | 24, 28, 32 | 35, 38, 41, 44 | every 3rd |
| **Balanced (recommended)** | **5** | **9, 13** | **16, 19, 22** | **25, 28, 31, 34** | every 3rd, 4 per stage |

The sketch's stages 3 and 4 extend the owner's numbers with the same rule
(gaps of 10, then 5, then 4, then 3). The balanced schedule's gaps are 5,
then 4, then 3 from stage 3 on.

**What a run pays, by the wave a player dies on** (bosses felled / BOSS
BOUNTY chips before the tally mult / Player Level XP from bosses at 250
each; §7.3, §11.1). Bosses are also the only source of unlocks (§11.2), one
per kill:

| Dies on wave | Today | Owner's sketch | Balanced |
|---|---|---|---|
| 6 | 1 / 6,000 / 250 | 0 / 0 / 0 | 1 / 10,000 / 250 |
| 11 | 3 / 36,000 / 750 | 1 / 20,000 / 250 | 2 / 28,000 / 500 |
| 16 | 5 / 90,000 / 1,250 | 2 / 50,000 / 500 | 3 / 54,000 / 750 |
| 21 | 6 / 126,000 / 1,500 | 3 / 90,000 / 750 | 5 / 124,000 / 1,250 |
| 31 | 10 / 330,000 / 2,500 | 5 / 194,000 / 1,250 | 8 / 274,000 / 2,000 |

**Why the balanced schedule is recommended:**
- **The sketch hides the showpiece.** A player who dies before wave 10 never
  meets a boss, and bosses are the game's centrepiece (market research,
  2026-10-18). Nine regular waves in a row also means nine mutator rolls
  with no change of rhythm.
- **The sketch halves the payoff.** Fewer bosses means half the boss XP and
  half the unlocks for the same play, so new players level and unlock
  much more slowly. The balanced schedule stays close to today's totals
  while still spreading the bosses the way the owner described.
- **Wave 5 is a fair first boss.** Waves 1 to 3 stay easy, brutes first
  appear on wave 4 (§6.2), and the first boss comes one wave later, still
  with the softer first-meeting rules below.
- Both keep the owner's shape: fewer bosses early, more per map later, never
  closer than every 3rd wave.

**Seeded order, kept fair** (owner, 2026-10-18: "Seeds can also determine
which order maps/bosses appear"):
- **Map order:** the seed shuffles the maps at run start. A map is not used
  again until every map has had a stage; after the last map the seed
  shuffles them again for the next lap, never repeating the map just left.
- **A fair first stage:** each map is marked as a fair opener or not. Stage 1
  is drawn only from openers (readable layout, short sightlines, no long
  falls near spawns). Shin-Kagura is an opener. A map built to be harder
  (for example a tall vertical climb) can be marked "not before stage 2".
- **Guardians:** each map has its own guardian boss. Until a map has one,
  the seed picks its guardian from the bosses not yet met this run. The
  run's first boss is never the heaviest: today SHUTEN can't be first
  (§5.1 keeps that rule), so a map whose guardian is SHUTEN is not an
  opener.
- **Rematches:** drawn by the seed from bosses already felled this run,
  never the same boss twice in a row.
- **Scaling depends on the wave, not on the boss or map**, so whatever order
  a seed deals, every boss on a given wave is scaled the same:
  - Boss HP scale `1 + 0.065 × (wave − 3)`: ×1.13 at wave 5, ×1.39 at
    wave 9, ×1.85 at wave 16, ×2.43 at wave 25, ×3.02 at wave 34. This
    replaces the cycle formula (§5.1), which only works when bosses come
    every 3rd wave; it lands near today's values at each depth without
    today's jumps at waves 12, 21 and 30.
  - Damage keeps half the HP scale's increase, and KAMAE scales with HP, as
    today.
  - **First meeting:** the first time a boss is met in a run, before wave
    12, it keeps big moves for after its enrage and the run's first boss
    telegraphs 25% longer (today's first-cycle rules, §5.6, tied to the
    meeting instead of the cycle).
- **Drawn up front:** the map order and every stage's boss list come from
  the seed at run start, from their own hashed stream (like the boss dice,
  hash of the seed and the stage), never from draws made during play, so
  nothing the player does can shift them.
- **Not from unlocks:** the journey uses every map in the game, never only
  the maps a profile has unlocked. Otherwise two friends with different
  unlocks would get different runs from one seed, which breaks seed sharing
  (§7.5). This would take maps out of the boss reward pool (§11.2): you
  reach a map by playing, not by unlocking it.

**How it meets the other systems:**
- **Waves and difficulty:** `hp_scale` and the line-ups keep following the
  wave number across map changes (§6.2). Each map sets its own max alive
  and spawn points (a small map holds fewer at once).
- **Mutators:** boss waves stay mutator-free. The first wave on a new map
  has no mutator either (default, so the player can read the new layout);
  the roll still makes its two draws so the stream stays in step. The
  no-repeat rule and every `min_wave` carry across maps.
- **End-of-wave tally:** unchanged. A guardian wave pays BOSS BOUNTY like
  any boss wave. The map change comes after the tally and the reward card,
  so "loud, then quiet" (§5.3) stays intact.
- **The map change:** a short travel card naming the next map, a quick
  glitch out and in (§9.9), the new map built behind it with its shaders
  warmed up before the first wave, so combat never hitches. HP, cells, run
  level and augments carry over; the old map leaves no nodes, timers,
  tweens or signal connections behind.
- **Boss rewards:** unchanged: every kill unlocks that boss's next item
  (§11.2), rematches included.
- **Run suspend:** the snapshot is taken after the map change, so CONTINUE
  RUN opens on the new map. It also stores the stage number and the bosses
  met so far; the map order and boss lists re-derive from the seed. A run
  saved before this ships continues by its wave number (wave 7 resumes in
  stage 2), through a save migration.
- **High scores:** comparable within a version, as today. A seed shared
  between different game versions may deal a different journey (maps
  added), as noted for seed codes in §19.

**Open questions for the owner:** in §19.

**Checks to run when it is built:**
- A unit test over 500 seeds and waves 1 to 100: no boss on waves 1 to 3,
  never two boss waves less than 3 apart, gaps never grow, stage k holds
  min(k, cap) bosses, the guardian is always last, stage 1 is always an
  opener, and the run's first boss is never SHUTEN.
- The same seed twice, and once with a suspend and continue at every map
  change: the same maps, bosses, rematches, waves and offers.
- A 10-minute autoplay run (`--god`, with a debug flag to start at a late
  stage) that crosses at least two map changes with zero script errors and
  no leftover nodes.
- An old run snapshot still loads.
- On the owner's PC: the map change has no hitch and loads quickly;
  the first boss on wave 5 feels fair to a new player; a rematch feels
  harder than the first meeting.
- Docs in the same PR: §5.1 and this section, `docs/boss-roster.md` and the
  Boss Roster doc (shared rules: arrival, HP scale, pacing), and the wiki
  (Bosses, The Map, Waves and Mutators, Seeds, Home).

---

## 7. Scoring, combo and high scores

### 7.1 During a wave
- **Combo:** each kill adds +1 and resets a **4.0 s** window. Combo mult =
  `1 + min(combo × 0.1, 4)` (max ×5).
- **Kill points** = base points × combo mult × mutator score.
  - Base: grunt 100, gunner 150, brute 600, Kurokage 5000, Tetsugumo 7000,
    Shuten 8000.
  - Modifiers: glory kill ×2, deflect kill ×1.5, headshot kill ×1.5.
- **Kill popup:** the tag and points, e.g. "GLORY KILL +240", "HEADSHOT +390",
  "KANABO DOWN", "RETURN TO SENDER", "CREMATED", "KAGE STEP", "SUSANOO'S
  WAVE".
- **Kill tick sound:** pitch `1 + min(combo, 40) × 0.03`.

### 7.2 Combo milestones
At 10, 20, 30, 50, 75, 100, 150, 200 and 300. ×10 is a stamp; ×20 and up get
the holographic cut-in (§9.8).

### 7.3 End-of-wave tally ("chips × mult")
- **Chips (rows):**
  - WAVE CLEAR 250 × wave
  - KILLS n × 25
  - GLORY KILLS n × 200
  - HEADSHOTS n × 75
  - DEFLECTS n × 100
  - PERFECT DEFLECTS n × 150 (play-test experiment, §3.2)
  - BOSS BOUNTY 2000 × wave (boss waves only)
  - Rows only appear if non-zero (WAVE CLEAR always shows). Stats are deltas
    since the wave started.
- **Mult:** `(1 + 0.1 × wave)`, then ×1.5 if FLAWLESS (no damage taken this
  wave), then × the mutator score.
- **Payout** = round(chips × mult). It is added to the score at once, but the
  HUD holds it back until the cash-out slam, then rolls it in.
- **Presentation:** §9.8.

### 7.4 High scores
- Local top 10 entries `{name (3 chars), score, wave, seed}`, sorted.
  - Kept in the profile save (§11.3). A prototype `user://scores.json` is
    imported once. The score is kept the moment the run ends (as `---`),
    so quitting before typing initials doesn't lose it.
- The live HUD does not show the best score (the Focus layout, §9.7); the
  title (BEST, and the HI-SCORES panel) and the results screen do. Passing the best score triggers the
  "NEW HI-SCORE" cut-in once per run.
- **Results:** a qualifying score asks for initials (A–Z, 0–9; Enter
  confirms; blanks become "-"), then the table appears with the new entry
  highlighted. **R** retries the same seed; a click or Enter starts a new
  seed. **P** (or RUN CARD in the results row) saves a run card
  (§19.1 #10).

### 7.5 Seeds
- A 31-bit run seed, shown as **XXXX-XXXX** hex (so it starts with 0 to 7).
  It can be forced with `--seed=XXXX-XXXX`.
- **PLAY A SEED** (built 2026-10-19): a title menu item (or **S**) opens
  a box to type or paste a seed. Typing takes 0-9 and A-F (the dash fills
  itself in, a first character of 8 to F is refused); PASTE or Ctrl+V finds
  the first seed in the clipboard text ("SEED 0BAD-C0DE" works). PLAY or
  Enter starts a run on it at once; BACK or Esc closes; CLEAR empties.
  Left alone, runs keep random seeds. With a suspended run waiting, PLAY
  asks twice and then ends that run the way N does (its XP counts). The box
  holds every key while open. Mouse alone or keyboard alone both work.
- **COPY** puts the run's seed on the clipboard: COPY beside the seed on
  the pause screen, COPY SEED in the results row, or **C** there.
- Separate RNG streams:
  - `rng_map = hash(seed × 3 + 1)`: map pick, palette, weather, cover layout,
    signs.
  - `rng_upgrades = hash(seed × 7 + 3)`: augment offers (one shuffle per
    offer, so the same picks give the same offers).
  - **Per-wave streams**, reseeded from the seed and the wave number at every
    wave start (`Game.seed_wave`), so nothing that happens in one wave, nor
    how long it lasts, can shift a later wave:
    - `rng_waves`: the wave's plan (mutator, line-up, boss order), drawn only
      when the wave starts.
    - `rng_spawns`: spawn points, spawn groups, boss reinforcements.
    - `rng_combat`: shotgun pellet spread, which glory kill plays, where
      health orbs scatter.
    - `rng_hazards`: storm strikes.
  - Each per-wave stream is seeded from `hash([seed, wave, tag])`, one tag
    per stream, so nearby seeds never share a stream a few waves apart.
  - Every enemy's own dice (attack timers, strafing, orb drops) come from
    the seed, the wave and its place in the wave's spawn order; a boss's
    from `hash(seed × 13 + wave)` (§5.6).
  - `rng_fx`: presentation only (sparks, flashes, sound variations, grunt
    looks). Randomized, never seeded, never used for gameplay.
- Nothing calls Godot's global `randf()`, `randi()`, `shuffle()` or
  `pick_random()`: a unit test fails the build if anything does
  (`test/unit/test_seeds.gd`). `tools/seed_check.sh` (in CI) plays one seed
  twice with the autoplay bot and fails if the waves or offers differ.
- The music playlist order also comes from the seed.
- **The same seed and the same play give the same run**, and however a wave
  is played, the waves after it keep their line-ups, mutators and bosses.
  Keep cosmetic randomness out of the gameplay streams.
- Planned: a daily seed. (Mentioned early; not confirmed. **OPEN**.) If
  built, it is made offline from the date, since the game never goes
  online (owner, 2026-10-18).
- **Sharing seeds** between players, offline, is a direction to expand
  (owner, 2026-10-18): racing a friend's score on the same seed, and more.
  §19.1 lists the ideas to try.

---

## 8. The map: Shin-Kagura Rooftop (the one map for now)

- **Setting:** the neon rooftops of **Shin-Kagura** ("New Kagura"; kagura is
  the sacred Shinto dance), a cyberpunk Japanese megacity under a striped
  synthwave sun.
- **Vertical update ("The Well", concept A, picked by the owner 2026-10-18;
  `scripts/maps/well.gd`, `WellMap`).** Concepts and renders:
  `design/vertical-map/` in the claude.ai project's shared files (not in
  the repo).
  - A 64×64 m roof (`half = 32`). Player spawn (0, 0.1, 24). Boss spawn
    (0, 0, −17), on the roof between the shaft and the north deck.
  - **Six floor heights.** The roof's centre is cut open: a 24 m shaft drops
    to a **metro platform at −10**, with **service blocks** (north, south)
    and **balconies** on legs (east, west) at **−5**. The **roof ring** is at
    0. A **torii bridge** crosses the shaft at **+5** between two side
    **catwalks** (+5). The **north deck** (+5) steps up to a **shrine tower**
    (+10) and a **beacon cap** (+13, the highest point), with a water-tank
    platform (+8) and an antenna terrace (+6.2) beside it.
  - **Roof-ring features:** a 3 m stairwell hut, a billboard gantry on legs
    (+5), a 3 m crate and a 6 m crate stack, a sheer 7.5 m vent tower (never
    climbable), 1.2 m planters with palms.
  - **Step heights** (sized for the ledge climb and plunge: a 5 m ledge is
    in reach of a double jump, 7 m is not):
    1.2 m hop, 3 m mantle, 5 m grab ledge (amber lip, colour `ffa21f` in
    every palette), 7 m+ sheer. Every level also has a ramp route.
  - **Geyser pads (9, fixed, never seeded).** The metro floor's (launch
    28 m/s up, 2.5 toward the bridge) throws the player up to the bridge.
    Eight more, added at the owner's request (2026-10-22: "more chances to
    jump into the air and do a plunge attack" on every level), launch
    straight up at `WellMap.PAD_LIFT` = 22 m/s (about 9.3 m): two on the
    service blocks' lamp-free corners (±9, −5, ±10), two on the south roof
    (±8, 0, 17), two on the roof beside the shaft's north corners (±19, 0,
    −11.5) and two at the catwalks' north ends (±24.5, +5, −18). Each stands
    on one floor, at least 3 m from spawns, 2.5 m from leap-link ends, 5 m
    from the boss spawn and 2.5 m from props (so the world detail is placed
    as before), with open air over it for the whole launch
    (`test_well_map.gd`, and `--movetest` launches the player off every
    pad). Only the metro pad has a real lamp; the new ones lay a floor glow
    instead, so the map's light count is unchanged. A pad fires only for a
    body within 0.6 m of its own floor height, so a pad on a catwalk never
    fires for someone on the roof below it. Layout board:
    `design/geyser-pads/` in the project's shared files.
  - **Spawns (18):** metro tunnels and freight lifts below, a lift in the
    stairwell hut and roof hatches: enemies walk out of these
    (`ground_spawns`, `Arena.spawn_clearance`). The rest are sky drops on the
    roof, catwalks, deck, gantry and tower, with spawn beams as before.
  - **Enemy pathing:** the map bakes a navmesh from its colliders at build
    (`Arena._build_navigation`, about 0.1 s) with **leap links** across each
    grab ledge. Enemies follow the path (`Enemy._steer`), use ramps, drop
    off ledges, and at a link going up they crouch for 0.35 s (sparks and a
    windup sound) and leap. Close on the same level they still run straight
    at the player. Boss blinks and reinforcements land on the nearest
    walkable floor (`Arena.safe_point`).
  - **Stacked floors:** `floor_height_at(x, z, below)` returns the floor under
    the caller, so gore, decals and missile rings land on the right level.
  - **Falls:** the player resets below −20, enemies below −18 (`kill_y`).
- **World detail (`WorldDetail`, owner's pick 2026-10-19: concept look "B
  Built Up" with "C Neon Haze"'s haze and light; renders in
  `design/world-detail/` in the project's shared files).** Built at the end
  of the layout, before the navmesh bake:
  - **Shapes:** raised floor plates on the 2 m grid over every grid floor of
    6 m² or more (top `LIFT` = 0.05 m; grates, hazard-painted and slightly
    higher plates mixed in; about 7% of cells open; cells under hatches,
    lifts, the pads, drains and floor neon stay bare). Plated floors report
    the plates' top from `floor_height_at` (each platform's `lift`), so
    blood, telegraphs, gibs and cans sit on them. Walls get a cornice and a
    band (kept below the amber lips' glow), a foot plinth, ribs, copper
    pipes, AC units with status lights, vending machines, lit shutters and
    hanging blade signs; faces with a grab lip only get ribs. On the roof:
    pipe benches along the parapet, vents, AC boxes and crates, drains,
    skylights, a hokora shrine, antennas, and cables with paper lanterns.
  - **Solid or overhead.** Anything a body would walk into is solid and taller
    than the navmesh climb (0.5 m), so enemies path round it; everything on
    walls hangs above 2.3 m. A solid prop is only placed if `_free` passes:
    on one floor, inside nothing, 2.5 m from every spawn point and the
    player spawn, 5 m from the boss spawn, 1.5 m from every leap-link end,
    off every ramp and its landings, and never within 5 m of a wall whose
    top is more than 6 m above the prop's floor but within the prop's height
    + 6.3 m (the climb rule: a prop must not make a sheer wall reachable).
  - **Air and light:** the run's fog colour becomes a haze
    (`WorldDetail.haze`: the palette fog towards accent 3, lighter), set as
    `Psx.fog_color` before anything is built; far materials fog from 25 to
    260 m; ambient 0.7 (from 0.95) with a soft pre-lit glow (`self_light`)
    on wall, steel and new surfaces; lamps 1.5× brighter with a light pool
    under each; street lamps; glow strips under low neon; mist in the shaft,
    a cloud deck below the roof edge, beams, steam, floating dust; baked
    contact shadows at every wall foot.
  - **Water (after the weather roll, `Arena._after_weather`):** puddles only
    where rain collects: open cells, drains, the parapet foot, the foot of
    tall walls, low spots, and the metro floor. Clear weather: metro floor
    only; heavy rain: all wall feet and 1.25× sizes. Skylights have glass.
    These are the **only reflective surfaces** (owner, 2026-10-19:
    "Reflections should only be on surfaces that would actually have
    reflections"). `PuddleMirror` mirrors a camera under the player's floor
    that draws only bright things (unlit neon, signs, the lit city; render
    layer 20) into a texture for `puddle.gdshader`; water on another level
    shows a dark sky sheen. WEAK: mirror off (sheen only); MEDIOCRE: half
    the 3D view's size; INSANE: full size (capped at 1280×720).
  - **Cost** (cloud software renderer, seed 4242, roof view): WEAK +30 draw
    calls and +34k triangles; MEDIOCRE +260 draw calls, mostly the mirror's
    pass over the map's neon. Merged into one mesh per material; WEAK also
    hides dust, steam and beams. Its own RNG: puddle shapes take the seed
    without drawing from `rng_map`, so seeds play as before.
  - Debug: `--nodetail` (bare map), `--rain=0|1|2`, `--worldshot`.
- **Backdrop (`CityBackdrop`, presentation only):**
  - A ring of towers turned to face the roof: lit windows, neon corner and
    floor strips, setbacks, rooftop crowns (beacons, water tanks, helipads,
    billboards), seeded signs and ads, and six corporation logos (§13).
  - Moving parts: four lanes of flying-car traffic (capped per Quality
    preset, §14), a monorail passing south of the roof, an ad blimp,
    searchlights, and a sun that drifts slowly (a 10-minute sweep, kept in
    the skyline's gap to the north).
  - Draws **one** number from `rng_map` and keeps its own RNG after that, so
    it can never shift gameplay (§7.5). Tower bodies, strips and traffic are
    MultiMeshes; nothing in it casts light.
  - **The City Is Watching** (`CityWatch`, §19.1 #9, on trial): news
    drones that gather with the combo and city screens with the live score
    and the seed's best initials.
  - The older layers stay: the far skyline MultiMesh, a sky hologram, neon
    palms, and the synthwave sky shader (palette gradient, striped sun with a
    seeded azimuth, ridge mountains with a rim light, stars, a moon).
- **The flat rooftop** (`scripts/maps/rooftop.gd`, a torii platform, catwalks
  at 3.2 m, 4 jump pads, seeded crates and obelisks) is no longer in
  `MapRegistry`; `WellMap` extends it for its materials and sky.
- **Weather (seeded via `rng_map`):**
  - 35% clear, 45% light rain, 20% heavy rain.
  - The RAIJIN'S STORM mutator adds heavy rain, lightning flashes and
    thunder.
  - Rain uses a particle field plus two quiet ambient loops (light, and a
    heavy layer added in storms) far back in the mix; see §10.3.
- **The map API** (keep it): maps extend an `Arena` base class.
  - Helpers: `_solid`, `_platform` (registers floor height), `_ramp`,
    `_neon`, `_neon_box_edges`, `_light`, `_halo`, `floor_height_at`, plus
    weather and storm.
  - Maps register in `MapRegistry` (`create_for_seed(rng)`).
  - Each map sets `map_name`, `half`, `player_spawn`, `boss_spawn`,
    `spawn_points` and `jump_pads`, and uses `pal` (palette) and `rng`
    (seeded). Multi-level maps also set `floor_base`, `kill_y`,
    `enemy_reset`, `ground_spawns`, `use_navigation` and `nav_links`.

---

## 9. Presentation

### 9.1 World look: retro PS1/PS2
- **RETRO LOOK setting** (Settings → Video; `scripts/retro_look.gd`;
  owner, 2026-10-19: the full look was too strong, the plain look kept the
  game good-looking but lost the PS1/PS2 feel). Three levels; the tuning
  lives in `RetroLook.LEVELS` and reaches the shaders as four globals:

  | | FULL | LIGHT (default) | OFF |
  |---|---|---|---|
  | 3D drawn at | 480×270 (`viewport` stretch) | about 540 lines: window ÷ whole number (`canvas_items`, 3D scale 1/n, post-process blocks of n×n) | window size |
  | `psx_retro` (affine × 0.55 lit / 0.4 unlit, fringe, scanlines) | 1.0 | 0.35 | 0 |
  | Nearest texels | yes | no (smooth, PS2-like) | no |
  | `psx_snap` (vertex grid, share of the 3D view's own pixels) | 0.6 (as before: 162 lines) | 0.67 (360 lines at 540) | 0 (no wobble) |
  | `psx_levels` (colour levels, Bayer 4×4 dither) | 48 | 64 | 0 (none) |
  | `psx_pixel_lines` (post-process blocks) | 0 | 540 | 0 |

  Why LIGHT is the default: the owner liked the plain look but wanted a bit
  of PS1/PS2 kept, so LIGHT keeps sharp square pixels at twice FULL's
  resolution (the 960×540 §2 always intended), a wobble under half the size
  of FULL's and faint dither and fringe, and drops the blocky
  warping textures that made the full look noisy. FULL is unchanged, for
  players who want it. Old saves move to LIGHT; a player who had the dev
  menu's plain look on gets OFF (settings v4). Gameplay never reads it.
  Limits: Godot's 3D scale stops at 25%, so on a 4K screen LIGHT already
  draws at that floor (960×540) and RENDER SCALE below 100% changes nothing
  there; elsewhere a render scale below 100% softens LIGHT's blocks a
  little (the block centres no longer land on 3D pixel centres).
- **PSX lit shader:**
  - Vertex snapping (grid = 3D view size × `psx_snap` / snap; the 3D view
    size shrinks with render scale).
  - Affine UV warp (uv × w varying).
  - **Per-vertex lighting.**
  - Fog, world-space planar UVs for boxes, and emission (from colour or
    texture).
  - A `flash` and `flash_color` uniform for hit flashes and the blue shock
    flicker.
- **Other shaders:**
  - Unlit: energy, flicker, uv scroll, fog amount, and `near_discard` so gore
    never covers the lens.
  - Alpha-scissor cutout for decals.
  - Additive FX: billboard option, a `reveal` uniform for slash arcs,
    vertex colour.
- **Post-process** (a full-screen canvas shader on a layer below the HUD, so
  the UI isn't dithered):
  - colour levels `psx_levels` (48 on FULL) + Bayer 4×4 dither 0.6;
    saturation 1.22; contrast 1.08
  - vignette 0.5; scanlines 0.07 and resting edge chromatic aberration 1.2,
    both × `psx_retro`
  - red damage pulse at the edges; white flash; desaturate on death
  - **impact frames** (§9.8)
  - **combo heat:** extra aberration and saturation, and accent-coloured dots
    creeping in from the edges as the combo climbs:
    `heat = clamp((combo − 4)/40, 0, 1)`
- **Textures:** procedural, small, nearest-filtered on FULL (the shaders
  pick the nearest texel; LIGHT and OFF filter smoothly). Floor, panels, concrete,
  windows, containers, hazard, grate, signs and ads (seeded variants),
  splats, glow, star, noise, cloth, skin, lacquer, jump pad, ring, grid,
  chrome.

### 9.2 Colour: vibrant, neon, bold, MULTI-COLOUR (critical feedback)
- **The current palettes lean too heavily toward purple. Fix this.**
  - The game must always show **multiple strong colours at once**: cyan,
    magenta, hot pink, electric blue, acid green, amber, orange-red. It must
    never be a single-hue wash.
  - Signs, neon tubes, UI, effects and the sky should not all share one hue.
    Purple can be one colour among many, not the base of everything.
- **The multi-colour base (built, `scripts/palette.gd`).** Five palettes,
  picked by `rng_map` (one draw, so the rest of the map stream never moves).
  Each sets sky top/mid/horizon, sun top/bottom, fog, ambient, grid, floor,
  mountain and **six accent hues**. `neon_a/b/c` are the first three accents
  (the HUD and effects use them; `neon_c` is always bright enough for text).
  The big areas (sky top, fog, ambient, floor) stay dark and fairly neutral
  so the accents carry the colour; the sky gradient crosses at least two hue
  families.

| Palette | sky_top | sky_mid | horizon | sun top→bottom | fog | ambient | grid | floor | accents (a, b, c, then 3 more) |
|---|---|---|---|---|---|---|---|---|---|
| SUNSET DRIVE | 060b2e | a3195b | ff7a2a | ffe14d→ff2a8a | 161a30 | 565c82 | 2af6ff | 0c0e1e | ff2a8a 2af6ff ffc23a 3d6bff 9dff3a ff4a1f |
| MIAMI NIGHTS | 050a2a | 1d3590 | ff6ec7 | fff07a→ff4f6e | 0f1c32 | 4a6688 | 3dfcd8 | 08101e | ff4fb8 3dfcd8 ff9e3d 4d8bff c6ff3d b45cff |
| ULTRAVIOLET | 05021a | 24127a | 2fd0ff | e8ff6a→ff3d9e | 12112c | 54568a | 9dff3a | 0a0a1c | b44dff 4df0ff e8ff3a ff3d9e 3dff8a ff7a1f |
| BLOOD CHROME | 05060c | 1e2a40 | ff3b2b | ffd27a→ff1f4d | 171a22 | 66687a | ff2b4a | 100c10 | ff2b4a 29e7ff ffb52b ff3df0 3d7bff b8ff3d |
| TOXIC TOKYO | 020818 | 064a50 | ff3da8 | f6ff7a→19ff9c | 0b1c1e | 46666e | 19ffc1 | 061012 | 19ffc1 ff3df2 f6ff4a ff7a1f 2f8bff ff3d5a |

  ULTRAVIOLET keeps its name as a blacklight look: violet is its one purple
  accent, surrounded by UV-reactive cyan, acid yellow, pink and green.
- **Rules every palette must pass** (`Palette.problems()`, run on every
  palette by `test/unit/test_palette.gd`): at least 5 accents, each a strong
  neon (saturation ≥ 0.6, value ≥ 0.8) and at least 25° of hue from every
  other; at most one purple accent (hue 255–300°); `neon_c` luminance ≥ 0.5;
  fog and ambient saturation ≤ 0.75 and fog value ≤ 0.25; sky_mid and
  horizon at least 30° apart; at most two of the large areas (sky top, sky
  mid, fog, ambient, floor, mountain) purple.
- **Accent distribution:** maps take colours with `Arena._accent(i)` or pick
  from `pal.accents`, never just neon a/b/c. On the rooftop each perimeter
  side, catwalk, crate and obelisk gets its own hue; signs, building edges,
  palms and lit windows pick from all six; the torii keeps one hue (neon_a)
  and jump pads stay neon_c so they read as one kind of object.
- **Palette unlocks** (boss rewards) can be **tints** over the multi-colour
  base (a warm sunset tint, a toxic green tint, a cold chrome tint), so every
  palette stays colourful.

### 9.3 Viewmodel (first-person hands)
- **Katana in the LEFT hand, shotgun in the RIGHT hand.** This matches the
  mouse buttons. **FINAL.**
- The root is scaled to 0.5 so the weapons sit inside the player's collision
  radius and never clip into walls.
- **Katana idle:** pos (−0.5, −0.44, −0.6), rot (−0.55, 0.3, −0.3).
  - Three slash poses lerped with ease-out cubic: 0.13 s swing, 0.04 s hold,
    0.2 s return.
  - The edge glow flares on each swing. A slash trail mesh (arc, reveal
    animation).
- **Shotgun idle:** pos (0.36, −0.3, −0.52), rot (0.04, 0.16, 0.05).
  - Fire: 0.05 s kick back and up (z +0.13, pitch +0.45), return by 0.2 s.
    Then a roll (−0.32 rad z) while the drum turns, 0.16–0.52 s.
- **Glory-kill poses** (katana pos/rot targets, lerped fast):
  - ready (−0.4, −0.3, −0.42 / −1.0, 0.5, −0.4)
  - thrust (−0.08, −0.16, −0.78 / −1.5, −0.1, 0)
  - rip_up (−0.05, 0.12, −0.6 / −0.15, 0, 0)
  - overhead (−0.1, 0.12, −0.32 / 0.45, −0.4, −0.3)
  - chop (0.02, −0.4, −0.6 / −2.25, −0.3, −0.3)
  - aside (−0.55, −0.5, −0.45 / −0.6, 0.6, −0.5)
  - plunge_raise (−0.12, 0.2, −0.36 / −2.0, 0.1, 0): blade-down grip, high
  - plunge (−0.04, −0.36, −0.68 / −2.35, 0.05, 0): driven down and in
- **Ledge climb:** both weapons reach up for the edge (katana +0.1, +0.22,
  −0.06, pitch −0.5; shotgun mirrored) for the first 30–60%, then press down
  on it (+0.08, −0.34, +0.1, pitch +0.8) until 85–100%. The camera dips
  (pitch −0.14, head −0.12 m) and rolls 0.045 on a sine over the climb.
- **Glory-kill poses** (shotgun):
  - ready (0.42, −0.4, −0.45 / 0, 0.25, 0.1)
  - chin (0.1, −0.2, −0.55 / 0.75, 0.05, 0)
  - point (0.12, −0.18, −0.62 / 0.05, 0.05, 0)
  - down (0.1, −0.12, −0.55 / −0.75, 0, 0)
- Sway spring from mouse motion, and head-bob.
- Cyber forearms (chrome, with neon stripes: magenta on the katana arm, cyan
  on the shotgun arm).

### 9.4 Gore (Sekiro / Bloodborne excess, Doom brutality)
- **Droplets:**
  - A CPU-simulated MultiMesh, cap 1800, with gravity 24.
  - Floor hits sometimes leave decals (22%). `near_discard` hides any
    droplet close to the lens.
  - The same pool is reused for sparks and embers.
- **Decals:** a ring buffer of 520 splats, with blood pools and scorch marks.
- **Gibs:** up to 110 duplicated body parts, with spin and blood trails.
  Plus neck/wound **emitters** (geysers), **mist** and **chunks**.
- **Dismember modes:**
  - execution: head flies up, neck geyser, big burst, pool
  - shotgun / explode / deflect: everything blown outward; a headshot pops
    the head into chunks
  - katana: sliced apart sideways, neck spray
  - **headpop** (glory kill): the head is destroyed, the body slumps, neck
    geyser
  - **split** (glory kill): the two halves fall apart sideways, big bursts
    and a vertical spray
- **Screen blood:**
  - Small, translucent splats (40–95 px at 480×270, alpha 0.7) near the
    screen edges for kills within 3.6 m (3 for a glory kill). They drip and
    fade over 1.4–2.4 s; at most 10.
  - They must **never block the centre of view**.
- Hitstop and slow motion are measured in real time (§15.3).

### 9.5 FX
- **Damage numbers:** Label3D, billboard, no depth test.
  - 16 px, or 32 px for crits and 100+ damage. Colours: yellow for headshots,
    grey for armoured hits, red for 100+.
  - Pop, rise and fade over 0.85 s. At most 40.
- **Lightning arcs:** jagged ribbon strips (camera-facing quads through
  midpoint-displaced points; core plus a wide faint glow; optional forks).
- **Spawn beams.** **Slash trails.** **Telegraph lines:** a floor line for
  Kurokage's dashes; red rings for missiles.
- **Shockwave rings:** a torus that grows; damage if not airborne.
  **Explosions:** light, flash, scorch, damage.
- **Health orbs:** green, homing.
- **Smoke.** **Missile strikes** with a falling missile.

### 9.6 Weapon looks (future reference)
- **Katana "DOJIGIRI":** visual reference is the **Thermal Katana from
  Cyberpunk 2077**, a heated blade whose edge glows **red-hot orange**. Make
  it our own design, not a copy. The prototype's cyan-edged katana is a
  **PLACEHOLDER**.
- **Shotgun "RAIJIN-12":** a detailed Blender model, **approved** as the
  game's shotgun (owner's request and approval, 2026-10-19; references were Bungie Marathon's "ALPHA M5"
  replicas, mood only: own shapes, no logos, slogans or text). Angular
  receiver, two flat stacked barrels with a plain square emitter at the
  muzzle (no prongs), a square power-cell drum under the receiver that turns
  a quarter turn per blast, slanted cooling vents, a normal trigger, red,
  gunmetal and off-white panels with small white markings. ~23k triangles
  (ceiling 30k), same pipeline and texture set as the katana. The idle
  crackle jumps between three points inside the emitter. The code-built gun
  remains only as the fallback if the model fails to load.
- **3D models:** everything else is built in code from primitive meshes.
  - At the owner's request (2026-10-19) the DOJIGIRI has a **highly
    detailed** Blender model that also looks good with the retro look off: ~13k
    triangles (ceiling 30k), fine detail baked into 2048 px colour,
    roughness/metal (ORM) and normal maps, plus a 256 px texture with the
    light painted in for RETRO LOOK FULL. Own shapes, no traditional katana
    look; the pommel, handle, collar and finger spur are one piece.
  - The glowing edge is one colour-neutral material ("edge") with UVs along
    the blade, so player colours and effects (Rewards looks) can drive it.
  - Pipeline: `assets/models/README.md`. Script-built in Blender, exported
    as glTF (.glb), drawn in Godot with `shaders/psx_model.gdshader` (PS1
    treatment on RETRO LOOK FULL, the full maps on LIGHT and OFF).
  - The owner approved it as the game's katana (2026-10-19). The code-built
    blade remains only as the fallback if the model fails to load.
  - The shotgun's model follows the same rules (above).
  - Other models stay code-built until the owner asks for one.

### 9.7 UI: cyberpunk, rendered pixel-retro
**Our own cyberpunk visual language, not Persona 5's.**
- **Faces** (all SIL OFL, bundled):
  - **Jersey 10:** all body text, labels, card text, tags and data. A true
    pixel face, drawn only at its own size (19 px, capitals 10 px) or a
    whole multiple, so every stroke is one even pixel wide. Numbers, seeds,
    tables and rolling counters use its fixed-width digits, which stop
    count-ups from jittering.
  - **Orbitron 900:** big display words and numbers only (×1.25 size boost);
    anything below its 16 px minimum is drawn in Jersey 10 instead.
  - **Michroma:** the big slow cards (glyph spacing +2); its small subtitle
    line is Jersey 10.
  - All are pixel-rendered (§2). Latin subsets only, so **in-game text has no
    macrons** (DOJIGIRI, not DŌJIGIRI). Optionally add a Latin-Extended
    fallback font and restore them.
- **Tech panels:**
  - Dark translucent glass (about 0.62–0.9 alpha), **chamfered corners**
    (top-left and bottom-right cut 4–14 px) and a thin neon outline.
  - Optional **corner brackets**, faint **scanlines**, a soft offset glow, and
    small **data tags** ("> SYS.EVENT", "> COMBAT LOG // PAYOUT").
- **Glitch text** (display moments):
  - Heavy letters that decode in from random characters, with a cyan/magenta
    RGB split, plus jitter and tear bars during the in/out burst.
  - Optional corner brackets and a tag above.
  - **Must follow the readability rule (§9.9).**
- **HUD layout: "Focus"** (owner's pick of three concepts, 2026-10-19:
  the old HUD was "a cluttered mess", text everywhere and overlapping; the
  game may be visually busy but the text may not). 480×270, 8 px margins.
  There are **no corner panels**: the corner text stands bare on a dark
  outline. Every kind of message has **one fixed lane**, and a new message
  replaces the one in its lane, so two messages never sit on each other. The
  flavour text all stays (callouts, warnings, stamps with their data tags,
  every juice screen). Mockups: `design/ui-redesign/B2-focus-*.png` in the
  project files.
  - **Top-left:** `WAVE 07`, and under it `14 LEFT` (hostiles left), grey.
    Jersey 10, 14 px apart.
  - **Top-right:** the score, Jersey 10 at twice its size (38 px), 7 digits.
    It rolls up, bumps (×1.2 at most) and turns gold on big gains. The best
    score is not on the live HUD; the NEW HI-SCORE cut-in still plays.
  - **Bottom edge:** the run XP as a 2 px purple hairline across the whole
    width. No "RUN LV" text (the level shows on the level-up screen).
  - **Bottom-left:** the wave's mutator and its multiplier, while one is on
    (hidden while the boss reward card is up).
  - **Centre: the vitals frame.** A square round the crosshair (48 px,
    drawn by four white corner brackets with 5 px arms, nothing in the
    middle), so it reads as part of the crosshair and never covers the enemy
    under it (owner, 2026-10-19: square, not round).
    - **Left edge: health**, a 3 px bar between the corners on a dark
      outline, filling bottom to top in red over dark red, with a white
      trail that drains slowly. Below 30% it pulses softly.
    - **Right edge: power cells**, one cyan block per cell, filled from the
      bottom, dark when empty; a newly charged cell flashes white.
    - **Bottom edge: dash charges**, lime pips (8×3, 4 px apart; 6×3 with
      four or more), a recharging pip partly filled.
    - The numbers sit just outside on small dark plates: the health number
      left of the frame (white, red below 30%; it never flashes) and the cell
      count right of it (cyan, red at 0).
    - The crosshair itself is the dot and ticks, with hit ticks on hit. The
      old katana and shotgun readiness arcs are gone (the approved Focus
      mockups have none; the frame replaced them).
    - FINISH, the wave payout and the boss-defeated card own the middle of
      the screen: the frame and its numbers step aside while they are up.
  - **Under the frame:** the combo (`x12`, from ×2) on a dark plate, with
    its timer as a 1 px line under the number; it pops each kill and heats
    from yellow to pink to rainbow at ≥50. Under it, the **glory kill
    prompt**, centred, 58 px below the crosshair, while a staggered enemy is
    in reach (§3.4): a gold key cap with the bound key ("F") and "GLORY KILL",
    "PLUNGE", or "ONIKIRI" on a broken boss (red-edged, §5.5), on a dark
    plate. It pops in over 0.1 s, then holds still; only the key cap's glow
    pulses. It fades in 0.08 s when the target is lost and is gone during the
    finisher.
  - **Right of the frame: kill callouts** (HEADSHOT, RETURN TO SENDER,
    DEFLECT, upgrade news...) as HIJACK chips (§9.8), from 32 px right of
    the frame, newest on top, at most 3, 16 px apart, 1.4 s each. The stack
    slides rather than jumps, and a repeat of the newest callout counts up
    ("DEFLECT! x3") instead of stacking.
  - **Left of the health number:** a steady red-edged "NO CHARGE" plate when
    the shotgun is fired with no cells.
  - **Top centre: the boss bar**, a 220 px plate between the wave and the
    score: the boss's name (red), its HP bar with a white trail, and the
    KAMAE row under it (§5.5). On a screen too narrow for it between the
    corners, it drops under the top row.
  - **The top lane:** just under the top row (and under the boss bar while
    it is up). The big moments go here, one at a time: KIRI cards (combo
    milestones, GLORY KILL with its points, ONIKIRI!), HIJACK blocks (KAMAE
    BROKEN, the boss name card), stamps (PERFECT, build links, FIGHT), boss
    messages ("<NAME> IS ENRAGED"), the holographic cut-in and the wave
    intro band. A newer one replaces the one showing, except that a combo
    milestone never replaces a glory kill's card.
  - **The bottom lane: warnings and hints**, bottom centre, ending 24 px
    above the bottom edge. A warning ("MISSILES INBOUND", "RED SIGNAL", the
    shockwave) is a full-width red HIJACK band (§9.8). A hint is on a dark
    plate edged in yellow: the head line yellow and the rest of the
    sentence is white on the line under it; a hint is split at its first
    dash, colon, "!" or "?". 4.5 s, each shown once. The boss reward card
    also deals into the bottom of the screen; a hint waits until it (or
    FINISH, the payout or the boss-defeated card) has gone.
- **Menus: "Focus"** (approved with the HUD, 2026-10-19; mockup
  `design/ui-redesign/B2-focus-3-menus.png`). Words, not buttons: each menu
  is a list of plain Jersey 10 words on a dark outline, straight over the
  scene, grey at rest and white with a 2 px cyan marker bar beside the one
  the mouse points at (the first item is marked until then). Every word is
  a click target; an item's key, if it has one, shows dim after it
  (`PLAY A SEED [S]`). Plates appear only where there is a table to hold.
  Shared in code as `MenuList` (`scripts/ui/menu_list.gd`).
- **Title screen:**
  - The **KATANA / SHOTGUN** logo, top left on two lines (Orbitron 32 px):
    KATANA flies in from the left and SHOTGUN from the right (0.3 s). Then a
    **neon blade cuts the "/"** in front of SHOTGUN (0.32–0.39 s), with a
    swing and slice sound, shake, data streaks and a shard burst. The slash
    occasionally glints.
  - Under it, the menu (16 px apart): START RUN (or CONTINUE WAVE n and
    NEW RUN [N] when a run is suspended, §11.3), PLAY A SEED [S], HI-SCORES,
    ARMORY, HOW TO PLAY, SETTINGS [TAB], QUIT [Q]. A click anywhere else, or
    Enter or Space, also starts (or continues) the run.
  - HI-SCORES (top 5), ARMORY (§11.2; click a row or press 1 or 2) and
    HOW TO PLAY (the controls, a key column and what each does) open on a
    plate beside the menu, one at a time; choosing the open one again, or a
    click away from the menu, closes it.
  - Bottom left: `BEST 0386418     PLAYER LV 6`, with the Player Level's XP
    as a 2 px hairline under it (§11.1). Bottom right: the version.
  - The title music plays while the camera drifts.
- **Pause:** dim, "PAUSED" (Orbitron 24 px) top left, and under it RESUME,
  ARMORY (opens the armory plate under the menu), SETTINGS [TAB] and QUIT
  GAME (no Q here: Q is a dash key mid-run). A click anywhere else resumes.
  Your builds so far sit on a plate top right. Bottom left: `SEED 548A-8455
  [C] COPY`; bottom right: the mouse sensitivity, which [ and ] change; a
  hint over the seed if the mouse fails to lock. Music ducks to −20 dB. The
  live HUD hides and the big messages freeze until you resume.
- **Quit:** QUIT on the title, QUIT GAME on the pause screen and the
  settings footer closes the game, saving the profile and settings first.
  The first press only arms it ("QUIT?  CLICK AGAIN" in red for 3 s) so a
  stray click or key never quits. A run in progress continues from its last
  between-wave save (§11.3).
- **Level-up:**
  - Dim the screen, "LEVEL UP" stamps in, "CHOOSE ONE  -  CLICK OR PRESS
    1 / 2 / 3" under it, and three **augment cards** (136 px wide, 10 px
    apart; as tall as the tallest text dealt, at least 150 px). Each card is
    a dark square plate with a hard shadow in its tag's colour: a ribbon in the tag's colour across the top with
    the tag and the card's key (1/2/3) in dark letters; the name in white;
    for cards with more than one rank, rank pips and "RANK n" in the tag's
    colour; the description in grey; and, over a rule on the bottom edge,
    the build lines ("STORM RUNNER 2/3", gold on a linking card). A linking
    card wears a gold RECOMMENDED tab above its top edge and a gold outline
    (§3.8).
  - **Card text must read at a glance** (owner, 2026-10-18: card text was
    hard to read; 2026-10-19: cards keep their full text). All card text is
    Jersey 10 at 19 px, lines 15 px apart, with no outline on the solid
    near-black plate. Card copy stays under 58 characters (a Gut test
    checks).
  - **Animation (HIJACK, §9.8):** cards open from a scan line one by one
    (staggered 0.11 s, with a "deal" sound each), then hold still: until one
    is taken, an open card is never squashed or scaled, so its pixel text
    stays sharp. Hovering lifts the card 3 px and edges it in its tag's
    colour.
  - **Picking is deliberate** (owner, 2026-10-18: cards were taken by
    accident). Input is ignored for 0.45 s after the cards appear, and the
    cursor starts below them. The first click or 1/2/3 **selects** a card
    (lifted 6 px, white outline) and a gold-edged plate under the cards asks
    "TAKE <NAME>?  CLICK AGAIN OR PRESS n"; clicking it again, pressing its
    key again or Enter **takes** it. Clicking off the cards clears the
    selection.
  - Taking punches the card (a flash of its tag colour), the others
    collapse and are shoved aside, a chime plays, and the pick applies after
    0.34 s.
  - Virtual cursor (mouse captured). Music ducks to −16 dB.
- **Results (death) screen:** §9.8 "Death".

### 9.8 Game-feel moments ("juice") and their timings
Everything runs in **real time** (unaffected by slow motion and hitstop).
**Every moment must obey §9.9.**

**Two styles** (owner's pick from the concept GIFs in
`/mnt/project-files/design/juice-concepts/`, outside the repo, 2026-10-19): "mostly HIJACK and KIRI". Shared rule:
*shapes lean, words don't* (a word only tilts or stretches during its landing,
under 0.1 s; while held it is level and still on a solid plate).
- **KIRI ("the cut")** for **combo milestones, glory kills and ONIKIRI**
  (`KiriCard`). A top-lane card arrives on a blade slash: the slash crosses
  the lane first (0.06 s), the plate is wiped on along it (0.07 s), leaning
  forward (top edge 10 px right), dark, with a solid echo in the accent
  colour 9 px behind it during the slam and 5 px after, a 2 px accent top
  edge, a bottom edge and a blade tip in the word's colour, and an optional
  tag tab ("CHAIN SYNC"). The word (Orbitron 20, 24 for the big milestones,
  32 for ONIKIRI!) slams from 2.6x and tilted (about 12°) to level in
  0.08 s, then holds still for its read time + 0.15 s. With a tag tab the
  plate sits 13 px lower, so the tab stays off the boss bar. Exit (0.16 s): the plate is sliced along its middle and the
  halves slide 46 px apart as it fades. Sparks from the slash head, shake.
  Big ones also **cut the 3D picture** along the slash: the two sides slip
  up to 10–16 px apart and close over 0.22–0.4 s (with a white seam on
  ONIKIRI), following the shake slider.
- **HIJACK ("broadcast takeover")** for **kill callouts, warnings, LEVEL UP,
  the boss intro and KAMAE BROKEN** (`HijackBlock`, `HijackFx`,
  `HazardBand`). Messages sit on solid neon blocks with dark letters and a
  hard offset shadow, straight lines only. A block shows one frame (0.05 s)
  of test-card colour bars where it will be, opens from a scan line in
  0.06 s, and its word lands with a horizontal stretch 2.2x to 1 in 0.08 s;
  a dark tag chip with a red dot can sit above it, a sub chip below. Exit
  (0.14 s): torn into seven strips that whip left and right. Big moments
  roll the picture (tracking bands shoved sideways, 0.1–0.15 s) and some
  flash one frame of negative.
- **FINISH stays as it was** (below), plus the **red negative** from the
  OFUDA concept: the 3D picture behind it goes two flat tones, dark ink and
  red, split by brightness, for 0.9 s (inverted 0.05–0.1 s at full flash),
  and the overlay's red tint thins from 78% to 30% so the negative shows.
  SHADOW DELETED and the souls card are unchanged.
- All the flashes (colour bars, static, negative, seam, invert, the white
  core of the slashes) follow the flash comfort slider and are gone at 0;
  the picture cuts and rolls follow the shake slider. The pause screen
  freezes every one of these pieces where it is, like the stamps.

- **HUD shake:** the whole UI root shakes. Max 12 px, decays `×exp(−9t)`.
  Big moments add 2–12.
- **Data streaks** (anime focus lines, cyberpunk style): dashed neon
  wedges rushing in from the screen edges, re-rolled every 0.033 s.
  - Strength 0–1, decay 3.5/s.
  - Used on dash (0.55), glory kills (1.0), FIGHT, cut-ins and FINISH.
- **Impact frames:** for 0.05–0.12 s the 3D picture snaps to three flat tones
  (black / accent / white, alternating inverted every 0.03 s), with extra
  fringe. Used on glory-kill beats, FIGHT and FINISH.
- **Kill burst:** at the enemy's screen position, neon pixel fragments plus a
  hex target-lock ring with ticks snapping shut. Bigger for non-grunts and
  glory kills.
- **Stamps:** text slams in.
  - From 2.2–4× scale to 1 in 0.07–0.09 s (accelerating), then a short
    squash that settles within about 0.2 s, a still hold, and a 0.2 s fade
    with slight growth (glitch stamps glitch out as they fade).
  - The hold is never shorter than the read time (0.5 s + 0.05 s per
    character). A new stamp replaces any stamp in the same screen region.
  - On impact: shake, sound and optional sparks.
- **Wave intro:**
  - 0.00 s: a full-width tech band (brackets) in the top lane snaps open in
    0.14 s.
  - "WAVE 04" decodes in (Orbitron 20, with tag "> SECTOR SHIN-KAGURA //
    HOSTILES INBOUND", or "> WARNING // HIGH-VALUE TARGET" on boss waves).
  - From 0.32 s the mutator types itself out at 55 chars/s on two lines
    inside the panel ("NAME // SCORE xN", then the description; clean
    letters, type ticks, no blinking cursor), 14 px apart. The band sits
    under the top row and grows to fit, ending above the vitals frame.
  - Countdown **3 / 2 / 1** at 1.20 / 1.75 / 2.30 s: bracketed glitch stamps
    at the band's right end (each replaces the last), pitched count sound 1.0
    / 1.12 / 1.26.
  - **FIGHT** at 2.85 s, in the top lane where the band was (35 px, brackets,
    tag "> ENGAGE", impact frame, data streaks, shard burst, "go" sound). The
    intro is then "ready" and spawning begins. The band fades out in 0.1 s
    as FIGHT slams in.
  - Boss waves skip FIGHT; the boss intro card appears instead. HIJACK: a
    boss wave starts with a **signal takeover** (full-screen colour bars
    with torn rows for 0.06 s, then 0.06 s of static over a red tint, and a
    tracking roll), and "BOSS INCOMING" scrolls in huge outlined red letters
    (96 px, 55% opacity, 70 px/s) under the HUD while the band is up.
- **Boss name card (HIJACK):** another takeover, a frame of negative and a
  roll, then the name on a dark block (Orbitron 28, white letters) with a
  hard red shadow, a "HIGH-VALUE TARGET" tag chip above and the epithet on a
  red chip below. It holds 3.0 s in the top lane, then tears out; the name
  scrolls huge behind the HUD as above. A newer top-lane message replaces it.
  - A riser sound under normal intros; an alarm under boss intros.
- **Combo milestones (KIRI):** every milestone is a KIRI card "X10 COMBO"
  (tag "CHAIN SYNC") in the top lane, its colour climbing with the combo,
  tilting alternate ways; from ×20 it also cuts the picture (12 px), and
  from ×30 the word is 24 px. While the boss name card, a glory kill's card,
  FINISH or a panel is up, milestones play their sound only (the HUD combo
  counter still shows the number), so nothing is covered.
- **Glory kills (KIRI):** three cuts across the whole screen (0.05 s apart,
  the middle one in the second colour), the picture cut along a 0.45 slope
  (10 px, 0.3 s), data streaks, and a **diagonal letterbox**: dark wedges
  that slide in from the edges in 0.08 s, the top one 40 px thick on the
  left and 14 px on the right, the bottom one the mirror, each with a 2 px
  neon edge and a 3 px band of the other colour. At 0.14 s the card "GLORY
  KILL" (or "SAKAHOKO DROP" for a plunge) lands; when the kill's points
  come in, "+380" opens under the word in gold instead of a callout, and
  the card holds long enough to read it.
- **ONIKIRI (KIRI):** two red cross cuts corner to corner, the picture cut
  16 px with a white seam, red and gold letterbox, then "ONIKIRI!" (32 px,
  red word, gold echo).
- **KAMAE BROKEN (HIJACK, owner 2026-10-19):** a frame of negative (0.07 s),
  a tracking roll, sparks off the boss bar, then "KAMAE BROKEN" in dark
  letters on a gold block with an orange shadow (holds 1.1 s).
- **Holographic cut-in** (1.0 s, long enough to read its text; now only
  for NEW HI-SCORE and REWARD UNLOCKED):
  - A full-width comm-feed strip in the top lane (70 px, chamfered, cyan top edge and accent
    bottom edge, hazard ticks) snaps in from the side in 0.08 s, holds still,
    and snaps out in 0.09 s.
  - A **codec-style portrait box** (78 px) with the **protagonist's visored
    mask** as a neon wireframe hologram: helmet, cheek plates, vents, a hot
    accent visor with two sharp white eyes. The hex grid, scanlines and
    sweeping scan bar stay inside the portrait box.
  - Large glitch text beside it ("NEW HI-SCORE", "REWARD UNLOCKED")
    on plain dark glass. (The old "LINK//KAGE-07" and "SYNC n%" data lines
    were dropped: they changed every frame and crowded the text.)
  - RGB-split ghosts on entry and exit only, a "cutin" whoosh-shing sound
    and data streaks.
  - Alternates sides. A centre stamp replaces it, and it replaces a centre
    stamp, so the two never show at once.
- **End-of-wave tally** (Balatro-style, on a tech panel 260 px wide, centred
  but never above the top lane, so the score it counts into stays in view; no
  scanlines behind the numbers; rows 15 px apart):
  - 0.09 s: title "WAVE 04 // CLEAR" decodes in (tag "> COMBAT LOG //
    PAYOUT"), with a stamp sound and shake 4.
  - Rows deal in from 0.32 s, every 0.2 s: they slide in, values count up
    over 0.16 s with a pop, and each plays a "deal" sound with rising pitch.
  - Then the **CHIPS** (cyan) and **MULT** (red) boxes appear. Chips count up
    over 0.3 s with ticks.
  - Each extra multiplier (FLAWLESS ×1.5, mutator ×n) **punches** the mult
    box every 0.35 s: scale, flash and wobble, a note label, a rising "mult"
    sound, shake.
  - A FLAWLESS stamp sits slightly rotated on the panel's top-left corner,
    clear of the title and its tag.
  - Then the **TOTAL** counts up over 0.8 s, *accelerating* (k²), with 16
    ticks rising in pitch 0.9 → 2.4 and a slow swell in scale (suspense).
    The digits never shake.
  - **Cash-out slam:** "cash" sound, shake 9, gold and cyan confetti
    fountains at both sides of the total, a small flash, and the held points
    roll into the HUD score with ticks and a gold bump. Boss waves add 8
    fireworks.
  - Ready 0.9 s after the slam; fades over 0.3 s.
- **Boss killed:**
  - **FINISH splash** (0–0.92 s): a full-screen **"system breach"** overlay.
    - The red negative on the 3D picture (see "Two styles" above).
    - Alert-red tint (always red, whatever the palette; 30% over the
      negative, 78% with the flash slider at 0), a hex grid,
      scrolling warning chevron bands top and bottom, columns of hex data at
      the edges, tear slices.
    - A solid dark plate across the middle, with nothing busy behind the
      words: the "FINISH" glitch stamp (48 px, brackets, tag "> TERMINATION
      CONFIRMED") and "TARGET SIGNAL LOST" under it.
    - Impact frame 0.12 s, data streaks, a shard burst, shake 12, the
      "finish" hit sound (chord stab + crash + sub drop).
    - **Then a hard cut.**
  - **Souls card** (4.6 s, from 1.25 s):
    - A dark gradient band (88 px) fades in over 0.45 s.
    - One line of Michroma letter-spaced text in **gold** (1.0, 0.86, 0.55)
      appears letter by letter, left to right, over 0.12–0.87 s (clean
      letters, no scramble). It has a soft glow behind it and cyan/magenta
      ghosts that are wide on entry and settle to 1 px; once complete the
      line holds perfectly still (no stutter, no zoom). It fits 90% of the
      screen width by stepping the font size down, never by scaling.
    - A subtitle "NAME – EPITHET" (Michroma, readable size) fades in at
      0.9–1.6 s.
    - Everything fades over the last 1.1 s. It counts as "ready" at
      length − 0.45 s.
    - "felled" sound: glitch crunch, sub boom, a dark minor-add9 synth swell
      and long reverb.
- **Death ("YOU DIED", cyberpunk):**
  - The music cuts. At 0.6 s, the souls card **"FLATLINED"** in red (3.2 s)
    with the "flatline" sound (a heart-monitor tone over a low drone).
  - At 3.4 s, the results screen replaces the FLATLINED card and the live
    HUD (Focus layout, §9.7; mockup `B2-focus/3-menus-results.png`):
    - Top centre: FLATLINED (red, Orbitron 16 px), the score under it
      (Orbitron 32 px, white) and, for a new best, a gold NEW BEST chip.
    - A stats plate on the left, names grey and numbers right-aligned in
      white, 15 px apart. The stats appear **line by line** every 0.09 s with
      type ticks: wave reached, bosses slain, kills, glory kills, headshot
      kills, deflects, best combo, run level, time.
    - The **score counts up** from 0 over 1.2 s (smoothstep, ticks every
      0.05 s rising in pitch), then slams (cash sound, shake 8, burst, bump).
    - On the right, the HI-SCORES plate: four rows (rank, name, score, wave),
      this run's row lit gold (the top three and this run's row when it
      ranks lower). They show once the score has slammed. A qualifying score
      then asks for initials in its own row ("TYPE INITIALS + ENTER", the
      row pulsing, with the highscore sound and two fireworks).
    - Under it, the level plate: PLAYER LV and the run's XP gain, the XP bar
      the gain counts into (§11.1), the XP numbers, and the run's seed.
    - Once ready, a row of words along the bottom: [R] RETRY SEED,
      [CLICK] NEW RUN, [P] RUN CARD (then [O] OPEN FOLDER, §19.1 #10) and
      [C] COPY SEED.
  - The title music returns at −14 dB. Input is accepted after 2.4 s. The
    world desaturates and keeps running in slow motion (×0.35).
- **Hi-score:** passing the best score mid-run: one message, a "NEW
  HI-SCORE" cut-in, with the highscore sound and fireworks at the sides.
- **Kill callouts (HIJACK):** the newest is a solid chip in its colour with
  dark letters and a hard dark shadow (4, 3); when a newer one lands it
  turns into a dark plate with coloured letters and a 2 px coloured left
  edge. Each opens from a scan line in 0.06 s, holds still, and collapses
  back into a line over its last 0.12 s.
- **Warnings (HIJACK):** a full-width red emergency band in the bottom lane
  with 4 px hazard-stripe rows above and below, scrolling opposite ways. The
  head ("MISSILES INBOUND", Orbitron 16, 13 if too wide) in dark letters,
  landing with a 1.8x to 1 stretch; the rest of the sentence white on a dark
  chip under it. It opens from a scan line in 0.07 s, rolls the picture,
  holds 4.5 s and collapses in 0.14 s. Hints keep their yellow-edged plate.
- **LEVEL UP (HIJACK):** "LEVEL UP" in dark letters on a gold block with a
  hard lime shadow (6, 5) that opens from a scan line, the word stretching
  in. The cards are dark square plates with a hard shadow in their tag's
  colour (5, 5); they open from a scan line one by one (0.08 s each, 0.11 s
  apart, a "deal" sound each). The selected card's shadow turns gold and
  deeper (8, 8) and its ribbon white. Taking a card: one frame of negative,
  gold and lime sparks, the taken card punches, the others collapse into a
  line and are shoved aside, and the title block collapses.
- **Other:**
  - Cells flash when charged.
  - Dash adds data streaks. Executions flash white at 0.4 alpha. Damage
    shakes the HUD in proportion.

### 9.9 READABILITY RULE (critical feedback; this overrides any style choice)
The prototype's text effects are **too messy**. Text and numbers must follow
the aesthetic **and be instantly readable**. Anything that flashes on screen
must be readable at a glance; the player must never feel they missed
something.
- **Glitch only on the way in and out.** While held, text is **clean and
  still**: no scrambling, jitter, tears or flicker.
- **Decode-in ≤ ~0.1 s**, and **never on numbers that matter** (score,
  payouts, HP, cells, combo, wave, timers). Numbers stay crisp and stable.
- **RGB split** is a subtle accent (≤1 px at rest), never a double image.
  No overlapping copies that blur the letters.
- **Minimum sizes:** nothing important below a readable pixel size at
  480×270. Small data tags ("> SYS.EVENT", hex columns) are **decoration
  only** and never carry information the player needs.
- **High contrast:** a clean outline or a dark plate behind every word. No
  busy patterns (hex grids, scanlines, data columns) directly behind text.
- **One message per screen region at a time.** New messages replace old
  ones instead of stacking. Messages never overlap each other (e.g. never a
  stamp and a cut-in with the same text at once).
- **Hold long enough to read:** roughly 0.5 s + 0.05 s per character for
  important flashes. Use fixed, predictable positions.
- **Short wording:** one to three words for flashes.
- **Acceptance test:** record gameplay, pause on any frame during a flash,
  and the text must be fully legible.

**How the UI meets the rule (implemented 2026-10-18):**
- Sizes at 480×270, chosen by rendering every face at every size: small
  text is Jersey 10 at 19 px (10 px capitals, one-pixel strokes; it is
  never drawn between sizes, where its pixels would turn uneven). Orbitron
  starts at 16 px (with +1 px glyph spacing everywhere, or neighbouring
  letters merge: "LI" read as "U") and Michroma at 16 px; below that the
  vector faces break the letter shapes (0 reads as A, O as D, uneven stems),
  so small text never uses them.
- Glitch text (`GlitchText`): decode capped at 0.1 s; digits and punctuation
  never scramble; no glitch bursts while held, only `glitch_out()` on the way
  out; RGB split 1 px at rest; a dark outline under every glyph.
- The Focus layout (§9.7, 2026-10-19) gives every kind of message a fixed
  lane, one message per lane; the corner text has a dark outline and the
  small readouts sit on dark plates. Layout is computed from the real text
  sizes, so nothing overlaps.
- Nothing blinks: warnings, prompts and NEW HI-SCORE are steady or pulse
  softly; low HP pulses the bar, never the number.
- Moving text holds still once it lands: no drift on cut-ins, no wobble on
  the LEVEL UP title, no jitter on the tally total.
- `--juicetest` also shows the boss name card, kill callouts, NO CHARGE, a hint,
  an ENRAGED message, a glory kill with its points, MISSILES INBOUND, KAMAE
  BROKEN, ONIKIRI and a plunge, for paused-frame checks.
- Nothing spills out of its panel or sits on other text (tidy pass,
  2026-10-18). The big moments take turns instead of stacking:
  - The level-up screen and the pause screen replace the live HUD (the pause
    screen also freezes stamps and cards where they are until you resume).
  - The level-up opens once FINISH, the wave payout, the boss-defeated card,
    the boss name card and any stamp have finished; a level-up earned on a
    wave's last kills opens after the payout, before the next wave's intro.
  - Kill tags and hints wait for the wave intro (an "<UPGRADE> ONLINE" tag
    appears at FIGHT) and are dropped while FINISH, the payout or the
    boss-defeated card is up; combo milestones play their sound only then.
  - Hints and warnings wrap when wider than the screen, in the bottom lane.
    A long mutator name in the payout stays inside the panel.
  - Results stats are two columns (names, numbers), so the numbers line up.
  - `--uiaudit` checks all of this while the game runs (see the README).

---

## 10. Audio

### 10.1 Mix priority (critical feedback)
**Music is the focus**, then combat SFX, then ambience. Use separate audio
buses (Music, SFX, Ambience, UI) with settings sliders. Duck music slightly
under big SFX moments, and **cut it** for the boss-death hush and the death
card.

**The mix (built; `default_bus_layout.tres`).** Five buses: Master, Music,
SFX, Ambience, UI. The mix levels live in the layout; the settings sliders
add on top of them, and music ducking lives on the music players, never on a
bus's volume.

| Bus | Level | Effects | Gets |
|---|---|---|---|
| Master | 0 dB | hard limiter, ceiling -1 dB | everything |
| Music | +2 dB | none | the two music players |
| SFX | -16 dB | high shelf -4 dB above 6.5 kHz (tames hiss in the placeholder SFX; drop it for professional SFX) | combat, movement, enemies, flow stingers |
| Ambience | -16 dB | high-pass 70 Hz, low-pass 6 kHz, compressor sidechained from Music (threshold -16 dB, 3:1) so ambience ducks under the music | rain beds, thunder |
| UI | -11 dB | none | menus, typing, tally and combo juice (each cue's `bus`, §10.5) |

Big hits (glory-kill execution, explosion, loud slams, boss entrance) pull
the music down 2 to 3 dB for about half a second (each cue's `music_duck_db`,
§10.5). Only a
cue played at -3 dB or louder ducks, and the duck can't retrigger for 1.5 s,
so a horde never keeps the music pinned down.

Measured on a 60 s autoplay run (seed 548A-8455, waves 1 to 2, Movie Maker,
`--record-mix`), integrated loudness: Music -19 LUFS, SFX -21 to -22, UI -25,
light rain -40, heavy rain -37, Master -17 with true peak under -1 dBTP. The
prototype mix measured -6 LUFS with peaks above 0 dBFS (clipping), the SFX
about 10 LU over the music, and heavy rain louder than the music.

### 10.2 Music: requirements for the real game
- The prototype's procedural tracks are **PLACEHOLDERS** for testing pacing
  and the music director. **They are not the soundtrack.**
- The final soundtrack must be **high production quality and professional:
  top tier, never basic, boring or low effort.** It is a headline feature,
  the way Doom (2016) and Persona 5 treat theirs. Properly composed,
  arranged, mixed and mastered, by a composer/producer or licensed.
- Style: **fast-paced, futuristic and energetic**, matching the game's speed
  (owner, 2026-10-18): about 140 to 155 bpm in combat, faster for bosses.
  The sound is **dark electronic bass music with an EDM feel; think Rezz**
  (owner, 2026-10-18, after rejecting clean synthwave and then guitars: **no
  string instruments**): heavy distorted, talking wobble basses over a clean
  sub, hard EDM kicks with sidechain pump and claps, hypnotic dark plucks
  and leads, zaps and drop impacts, and glitch edits (stutters, tape stops,
  reverses, gates, bitcrush). Distinct boss themes; a
  memorable title theme. It must not sound repetitive.
- **System requirements:**
  - Stems or intensity layers so the music can react (boss phases, enrage,
    combo heat, the hush after a boss dies).
  - Loop points for boss and title tracks.
  - A large enough pool of combat tracks that runs never repeat.
  - Crossfades and seeded playlist order.
- **Music director** (keep the behaviour):
  - Two players crossfading (2.5 s). A seeded shuffle of the combat
    playlist, advancing shortly before a track ends.
  - Per-boss themes: Kurokage → boss_0, Tetsugumo → boss_1, Shuten → boss_2.
  - A title theme.
  - `music_cut()` (a fast fade to silence) and `resume_combat()`.
  - Ducking: playing −6 dB base, pause −20, level-up −16, results −14.
- **Placeholder tracks** (prototype, generated):
  - combat_0 148 bpm minor [0,5,2,6]; combat_1 140 minor [0,6,5,6];
    combat_2 150 minor [0,3,5,4]; combat_3 144 dorian [5,6,0,0];
    combat_4 152 minor [0,5,3,4]; combat_5 146 dorian [0,2,6,5]. About
    95 to 100 s each.
  - boss_0 160 phrygian; boss_1 156 harmonic minor; boss_2 165 harmonic
    minor; title 118 dorian.
  - Sections: short intro, groove, lead, lead2, break, build, drop, lead,
    drop, short outro. Kicks four-on-the-floor or driving, hats in 16ths,
    basses in 16ths (octave, pulse or gallop) played by a formant wobble
    bass (its LFO runs on song time), an FM growl or a reese, with a sine
    sub underneath. Bass, sub, pad and plucks pump under the kick (the
    lead half as much). A
    hypnotic one-bar pluck sequence, a dark detuned lead or a screech for
    the melody, a dark filtered pad, clap rolls and zaps into each section,
    an impact on each drop. Most second bar ends outside the intro and
    outro (and some off-beats in drops) get a seeded glitch.
  - Every track is mastered to -14 LUFS (`tools/gen_music.py`), the level the
    mix in §10.1 was measured against.

### 10.3 Ambience (critical feedback)
- Ambience (rain, wind, city hum, neon buzz) is fine but **must sit far back
  in the mix and never become a constant hiss.**
- The prototype's rain loop read as annoying **"white noise"** (one 6 s
  full-band noise loop at -16 dB light and -8 dB heavy; 35% of its energy
  above 5 kHz). **Fixed:**
  - Rebuilt by `tools/gen_audio.py rain` as two 20 s stereo loops,
    `rain.ogg` and `rain_heavy.ogg`, made of patter, droplet, drip and a
    little low body, with slow gusts. Band-limited: under 0.2% of the
    energy above 5 kHz.
  - The rain still plays in 65% of runs. Light rain plays `rain` at -2 dB;
    heavy rain plays `rain` at -3 dB plus `rain_heavy` at -3 dB (Sfx
    `RAIN_DB`, `RAIN_HEAVY_DB`), on the Ambience bus, so it lands about
    20 LU (light) and 18 LU (heavy) under the music and ducks further while
    music plays.
  - Each layer drifts up to 6 dB below its level and back every 5 to 12 s,
    so it comes and goes.
  - Apply the same to any other bed and to noise baked into SFX (the SFX
    bus's high shelf tames the placeholder SFX).

### 10.4 SFX (all PLACEHOLDER, generated; replace with professional sound design)
- **Weapons:** shotgun (electric blast), recharge (capacitor whine + clack),
  empty (fizzle), zap (arc on a body), swing0–2, slice, deflect,
  deflect_perfect (a ringing clang), headshot (ding), wave_blade.
- **Gore:** gore0–2, gore_big, execution.
- **Movement:** dash, jump, land, jumppad.
- **Enemies:** enemy_shot, windup, roar, slam, spawn, blink, shuriken,
  gatling, missile, explosion, beep, alarm.
- **Player:** hurt, player_death, pickup.
- **Flow:** levelup, wave_clear, boss_intro, riser, coin, highscore, felled,
  flatline, finish, cutin.
- **UI:** ui_click, ui_hover, type.
- **Juice:** tick, stamp, chime, cash, count, go, mult, deal, fanfare.
- **Ambience:** thunder, rain loops (light and heavy layers).
- Pools: 20 2D and 20 positional 3D players, per-sound throttling (30–45 ms,
  on real time), random pitch variation from a presentation-only RNG.
- The same quality bar as the music applies.

### 10.5 Audio pipeline (built; ready for professional audio)
The game reads audio from data, so professional sound and music drop in
without code changes. `assets/audio/README.md` is the how-to for a sound
designer or composer (folders, delivery specs, replacing a cue, stems).
- **Cues:** one `SfxCue` resource per sound effect in
  `assets/audio/cues/<name>.tres` (variants, bus, trim, pitch variation,
  throttle, max voices, priority, 3D distances, music duck). `Sfx.play(name)`
  and `Sfx.play_at(name, pos)` look the cue up; a sound file with no cue yet
  still plays with defaults. `tools/make_audio_data.gd` creates missing cue
  and track files and never overwrites existing ones.
- **Voices:** fixed pools (20 2D, 20 positional; `VoicePool`). A cue at its
  max voices reuses its own oldest voice; otherwise a free voice; otherwise
  it takes the oldest voice of the lowest priority at or below its own; else
  it is dropped. Priorities: CRITICAL (player weapons including the arc
  zap, hurt, enemy telegraphs such as windup, roar and slam, flow stingers
  and boss moments), NORMAL (enemy shots and missiles, movement, UI), LOW
  (gore, spawns), AMBIENT (thunder). Voice caps per cue: gore0-2 2 each,
  gore_big, shotgun and gatling 3, swings 2, the rest 4 (UI hover 1).
- Stingers that must keep their pitch (levelup, wave_clear, highscore,
  fanfare, felled, flatline, boss_intro) have pitch variation off.
- **Music:** one `MusicTrack` resource per piece in
  `assets/music/tracks/<name>.tres` (role combat / boss + boss kind / title,
  stems, per-stem intensity, loop and loop offset, bpm, trim). The combat
  playlist is the combat tracks sorted by name, shuffled by the run seed.
- **Intensity layers:** stem 0 always plays; further stems fade in by music
  intensity (0 to 1): combo / 25, pinned to 1 while a boss is enraged, 0
  after a cut. Rises 0.8 per second, falls 0.15 per second. The placeholder
  tracks are single stems, so this is ready but not yet audible.

---

## 11. Progression and saving (CRITICAL)

Built in PR "Profile and save system" (2026-10-18): `Profile` autoload,
`scripts/save/`, `Rewards`, the results XP roll-up, the title armory and
CONTINUE RUN. The two OPEN items below run on the defaults stated there
until the owner decides.

The high score is not the only thing the player chases. There must be a
visible, persistent **Player Level**, and the game **must save** so progress
is never lost.

### 11.1 Player Level (persistent, profile-wide)
- **XP in:** every run pays XP into the profile at the end of the run, based
  on score, waves reached, bosses felled, glory kills and so on (formula
  **OPEN**; aim for a steady pace with the first levels coming quickly; never
  grindy).
  - **Default in use** (`scripts/save/progression.gd`): 60 per wave cleared,
    250 per boss, 4 per kill, 15 per glory kill, +1 per 500 points. Level
    1→2 needs 400 XP, each level after 150 more, flat from level 31.
    A first run that dies on wave 3 reaches level 2.
- **Seeing it rise:** after each run, the results screen counts XP into the
  level bar (Balatro-style roll-up). Every level gained gets a celebration (a
  holographic cut-in, a stamp, a sound). The level shows on the title screen
  and the results screen.
- **It unlocks NOTHING.** It exists purely to show progression. It never
  changes difficulty.
- **Two different levels:** label "PLAYER LV" (persistent) and "RUN LV" (the
  in-run augment level) clearly. Example: "PLAYER LV 23" vs "RUN LV 7". The
  live HUD shows the run's progress only as the XP hairline (§9.7); "RUN LV"
  is written on the results screen.

### 11.2 Boss rewards (the ONLY unlocks)
- **Felling a boss can earn a reward.** Rewards are the only thing that
  unlocks anything, and they add **no new mechanics or features**.
- **Reward pool:** cosmetics, **new maps**, **palettes** (tints, §9.2),
  **weapon and katana skins**, **mutators**, **boss variants**. No stat
  boosts, so seeded high scores stay comparable.
- **Presentation:** right after the boss tally, a holographic cut-in and an
  item card with the unlock's mythic name (§13). Save it to the profile
  immediately.
- **Where unlocks go:** maps, palettes, mutators and boss variants join the
  seeded pools. Skins and cosmetics are picked in a simple menu.
- **OPEN:** the drop rules (a guaranteed first-kill reward per boss? chance
  per kill? reward tables per boss and cycle?) and the full reward list.
  - **Drop rule decided** (owner, 2026-10-18; `scripts/rewards.gd`): each
    boss has an ordered list and every kill unlocks its next item until the
    list is done. Never
    random, so rewards never touch the seeded RNG. The first six are
    weapon looks: a katana edge and a shotgun coil per boss, picked on the
    title or pause screen (ARMORY: click a row, or 1 and 2). Palettes, maps, mutators and boss variants can
    join the lists once they exist.

### 11.3 Saving (critical)
- **Profile save:** Player Level and XP, unlocks, equipped cosmetics, high
  scores, settings and lifetime stats.
  - Auto-save at the end of every run, on every unlock, when settings change,
    and on quit.
- **Run save (suspend and resume):** quitting mid-run, or the game closing,
  must not lose the run.
  - Snapshot **between waves**: seed, wave, score, combo state, run level and
    XP, augments and ranks, HP, cells, dash charges, run stats and **RNG
    states** (the map and augment streams; the per-wave streams reseed from
    the seed when the next wave starts, §7.5).
  - On launch, offer **CONTINUE** (WAVE n) on the title. Delete the snapshot when the run ends,
    so a death can't be undone by reloading.
- **Robustness:**
  - A versioned format with migrations.
  - **Atomic writes** (write a temp file, then rename), and keep one backup.
  - Never wipe a profile when loading fails; fall back to the backup.
- Location `user://` (folder `KatanaShotgun`). Later, Steam Cloud or
  similar.
- **As built:** `profile.json` and `run.json`, each with a `.bak`. Every file
  is a header line (`KSAVE <kind> <version> <sha256>`) then JSON; a file
  that fails its checksum is skipped. Load order: a finished `.tmp`, the
  file, the backup. If every copy is bad they are renamed
  `*.corrupt-<time>` (never deleted) and a new profile starts. Debug runs
  (`--autoplay`, `--juicetest`, `--showcase`) use `user://debug/`. The run
  snapshot is taken after each wave's tally (and boss reward card), deleted
  the moment the player dies. Starting a NEW RUN over a suspended run pays
  that run's XP first. Format and API: `scripts/autoload/profile.gd`.

---

## 12. Maps (future; not the current priority)
Maps register in `MapRegistry` and the seed picks among the unlocked ones.
(Proposal, not built: a run moves to a new map after each map's boss,
§6.4.)
Planned (names from §13):
- **Tokaido Expressway:** a horizontal, **long, open, procedurally generated
  stretch** (an elevated highway / market street, after the old Edo–Kyoto
  road). It feels like charging down a corridor but stays open.
- **Takamagahara Spire:** a **vertical megastructure**. Start at the bottom of
  a cyberpunk skyscraper and fight floor by floor to the top (Takamagahara is
  the High Plain of Heaven).
- **Ryugu Arcade:** a mall/arcade interior (after the Dragon Palace of
  Urashima Taro).
- **Kurama Dojo:** a dojo in the rain (after Mount Kurama, where tengu taught
  swordsmanship).
- Possibly a highway overpass.

---

## 13. Naming bible: Japanese history and myth, in chrome
**Every name in the game** (bosses, maps, weapons, enemies, mutators,
augments, items, rewards, skins, palettes) blends **a Japanese mythic or
historical root with a cyberpunk twist**.
- Keep names readable: usually one Japanese word per name plus an English
  epithet or description.
- The meaning is explained in a short codex line (a codex is a later, light
  feature, **OPEN**).

**Sources:**
- **Kami and Shinto:** Amaterasu, Susanoo, Tsukuyomi, Raijin and Fujin,
  Izanagi and Izanami, Hachiman, Idaten, kagura, torii, shimenawa,
  Takamagahara, Yomi.
- **Yokai and folklore:** oni, tengu, kappa, tsuchigumo, jorogumo, nue,
  gashadokuro, yurei, onryo, kitsune, tanuki, tsukumogami, Yamata no Orochi,
  Ryugu-jo.
- **History and legend:** the Sengoku period, daimyo, shoguns, ronin,
  shinobi, the 47 ronin, Minamoto no Raiko, Yoshitsune and the tengu of
  Kurama, the Tokaido, Masamune, Muramasa, named blades.
- **Cyberpunk vocabulary:** chrome, neon, static, signal, null, ghost, daemon,
  kernel, root, firmware, cipher, wetware, overclocked, synthetic, augment,
  syndicate, grid, ICE, deadlink, mirrorcode.
- **Avoid:** real tragedies and wartime references (no "kamikaze"), and
  other people's well-known IP names.

**Names in use, and their roots:**
- Shin-Kagura (the city): kagura, the sacred dance, "New Kagura".
- Kurokage: "black shadow".
- Tetsugumo: "iron spider", a play on the tsuchigumo yokai.
- Shuten: Shuten-doji, the oni king of Mount Oe, slain by Minamoto no Raiko.
- **DOJIGIRI** (the katana): Dojigiri Yasutsuna, the blade said to have
  killed Shuten-doji. A story link to the boss.
- **RAIJIN-12** (the shotgun): Raijin, the thunder god.
- **SAKAHOKO DROP** (the plunge's kill tag): Ama-no-sakahoko, the heavenly
  reverse spear that Ninigi drove into the peak of Mount Takachiho when he
  came down from heaven.
- **Enemies:** Ashigaru (grunts), Teppo (gunners; the matchlock corps),
  Kanabo (brutes; after the oni's iron club).
- **Boss rewards** (§11.2, `scripts/rewards.gd`): KAGEROU EDGE (kagero, the
  heat haze), KITSUNEBI COIL (kitsunebi, fox-fire), KANAYAGO EDGE
  (Kanayago-kami, the deity of ironworking), AKAGANE COIL (akagane,
  copper), ONIBI EDGE (onibi, oni-fire ghost lights), RAIKO COIL (Minamoto
  no Raiko, who slew Shuten-doji).
- **KAMAE** (the boss posture bar): kamae, a fighting stance; literally
  "posture" in kenjutsu.
- **ONIKIRI** (the break blow): "oni-cutter", the name legend gives to
  blades that cut down demons, like Dojigiri against Shuten-doji.
- **Mutators and augments:** see §6.3 and §3.8. Mutator roots added
  2026-10-18: okuri-inu (the yokai dog that stalks travellers at night),
  onryo (a vengeful ghost), kabuto (the samurai helmet), matsuri (a
  festival), kanashibari (sleep paralysis, blamed on spirits), hannya (the
  jealous demon mask of Noh), umibozu (the sea giant that rises from calm
  water), senryo (a thousand ryo, a fortune). Augment roots added
  2026-10-18: Ikazuchi (the eight thunder kami of Yomi), Inazuma
  ("lightning"), hitodama (yokai soul-fire wisps), Hachiman (god of archery and
  war), Nasu no Yoichi (the archer who hit the fan at Yashima), Gashadokuro
  (the giant skeleton yokai), Yata no Kagami (the sacred mirror), Homura
  ("flame"), chimatsuri ("blood festival"), Kurama (the mountain where the
  tengu trained Yoshitsune), kamaitachi (the sickle-weasel wind yokai),
  taiko (the war drum), Fujin (the wind god; dash cards are wind, shotgun
  cards thunder), utsusemi ("cicada shell", the shinobi body swap), the
  Sanzu river (crossed by the dead). Retired with their effects: Long
  Reach, Vampiric Steel, Fujin Bank, High Voltage, Feedback Loop.
- **Corporations on the skyline** (§8, invented): AMATERASU DYNAMICS (the sun
  goddess), TENGU AEROSPACE (the winged mountain yokai), INARI FOODS (the
  kami of rice), TSUKUYOMI MEDIA (the moon god), OMOIKANE SYSTEMS (the kami
  of wisdom), KAPPA HYDRO (the river yokai).
  TSUKUYOMI LIVE is TSUKUYOMI MEDIA's news feed on the city screens and
  drones (The City Is Watching, §19.1 #9).
- **Soda cans** (§19.1 #11, all INARI FOODS drinks): KAZE RUSH (kaze,
  wind), KAMINARI SPARK (kaminari, thunder), SHIRANUI BLAZE (shiranui, the
  phantom sea-fires of Kyushu), MIKAZUKI ZERO (mikazuki, the crescent moon;
  also Mikazuki Munechika, one of the Five Swords Under Heaven), AKANAME RED
  (akaname, the yokai that licks clean what others leave), UZUME POP
  (Ame-no-Uzume, whose dance drew the sun goddess out of her cave), GAKI
  BLACK (gaki, the hungry ghosts never satisfied), YUKI CHILL (yuki-onna,
  the snow woman).

---

## 14. Performance (REQUIREMENT)
The game must be **incredibly well optimised and smooth**, like
Counter-Strike, League of Legends and Valorant, which run well even on old,
weak hardware.
- This is **not a compromise on visual quality**. The game isn't realistic;
  its art direction carries the look. **Cheap to render, expensive-looking.**
- **Targets:**
  - **Low-end** (a 2015-era laptop with integrated graphics): a locked
    **60 fps**.
  - **Mid-range:** **144+ fps**. **High-end:** 240+ uncapped.
  - **No hitches:** no shader-compile, load or garbage spikes in combat. 1%
    lows matter more than averages.
  - **Low input latency:** uncapped / VSync / frame-cap options and a
    low-latency mode.
  - Fast boot and load, a small install, low RAM use.
- **Guidelines:**
  - **Rendering:**
    - Low internal 3D resolution with a render-scale option; small
      nearest-filtered textures; simple shaders; per-vertex lighting; no
      real-time shadows by default.
    - **Few draw calls:** MultiMesh for repeated things (the skyline, gore
      droplets and decals already use it); merged static level geometry;
      shared materials.
    - **Warm up and precompile every shader and material at load**
      (ubershaders / pipeline cache) so the first explosion never hitches.
  - **Allocation:**
    - **No per-frame allocation in combat.** Pool enemies, bolts, FX, damage
      numbers, arcs, UI stamps, popups and shards.
    - The prototype still creates and frees many of these on the fly. Fix it.
    - **Hard caps** on everything that piles up, recycling oldest first;
      caps scale with the quality preset.
  - **Simulation:**
    - A fixed physics tick with simple shapes. Time-slice AI for distant
      enemies.
    - The tick stays at 60; **physics interpolation is on**
      (`physics/common/physics_interpolation`, jitter fix 0) so bodies glide
      between ticks on 144–240 Hz screens. The player's head (camera and
      viewmodel) is top level with interpolation off and is placed every
      frame on the body's interpolated position with the live mouse look.
      Anything that teleports calls `reset_physics_interpolation()`
      (respawn, the end of a finisher, pooled reuse).
    - Move hot loops (gore, mass AI) to typed GDScript, C# or GDExtension if
      profiling says so.
  - **Graphics presets** WEAK / MEDIOCRE / INSANE (ids `low`, `medium`,
    `high`) set effect counts, render scale and lighting, **never the art
    style** (§14.1).
  - **Effect caps per preset** (`scripts/quality.gd`; pools are built at the
    High size, the oldest effect is recycled when a cap is reached):

    | Cap | WEAK | MEDIOCRE | INSANE |
    |---|---|---|---|
    | Blood/spark droplets | 700 | 1800 | 2700 |
    | Floor decals | 220 | 520 | 780 |
    | Gibs and chunks | 50 | 110 | 160 |
    | Blood per burst | 50% | 100% | 150% |
    | Chunks per kill | 50% | 100% | 130% |
    | Damage numbers | 18 | 40 | 40 |
    | Lightning arcs | 36 | 96 | 128 |
    | Blood mist | 16 | 40 | 56 |
    | Smoke puffs | 20 | 60 | 80 |
    | Impact flashes | 16 | 48 | 64 |
    | Flying cars in the backdrop (40 exist) | 16 | 40 | 40 |
    | News drones (The City Is Watching) | 4 | 8 | 12 |

    Fixed at every preset: spawn beams 16, slash trails 8, explosion flashes
    12, explosion lights 4, kill callouts 3, screen blood 10. Health orbs are
    never capped (they heal); their pool grows. MEDIOCRE's caps sit above
    what a fight produces, so it shows the full prototype show; INSANE throws
    more blood and chunks per kill. Damage numbers stop at 40 so the screen
    stays readable. Boss-only effects
    (shockwave rings, missile markers, dash telegraph lines) are still built
    per use: they fire a few times a minute at most.
  - **Profiling:** test on real low-end hardware throughout. Set a frame-time
    budget per system. Add a debug perf overlay (fps, frame time, draw calls).


### 14.1 Graphics presets
Owner, 2026-10-18: WEAK is today's look, MEDIOCRE a noticeable step up,
INSANE "lives up to the name" and uses what Godot does best. Ray and path
tracing are dropped. Every tier keeps the PS1/PS2 direction (its strength is
the separate RETRO LOOK setting, §9.1): low resolution, vertex snap, Gouraud (per-vertex) lighting, the run's palette and the
dither post-process. Higher tiers add light, never realism.
`scripts/graphics.gd` applies the lighting to the map's Environment, moon and
lamps (live on a preset change); `scripts/quality.gd` holds the caps above.

| | WEAK (`low`) | MEDIOCRE (`medium`, default) | INSANE (`high`) |
|---|---|---|---|
| Renderer | Compatibility | Compatibility | Forward+ |
| Render scale it picks | 75% | 100% | 100% |
| Lighting | the map as built | the map as built | + global illumination (SDFGI: neon bounces onto floors), indirect light (SSIL), ambient occlusion (SSAO), soft moon shadows |
| Glow | the map's own | wider neon halos | HDR glow that only catches light brighter than white |
| Atmosphere | — | a faint additive haze around each lamp | volumetric fog lit by the lamps and moon |
| Puddles and glass (the only reflective surfaces, §8) | dark sheen, no mirror | mirrored at half size | mirrored at full size |
| Dust, steam, light beams (§8) | — | yes | yes |
| Edges | no MSAA | MSAA 2x | MSAA 4x |

- Forward+ shades the world with `psx_lit_hd` / `psx_cutout_hd`: the same
  surface, but fogged by the Environment's depth fog (the shader's own curve,
  10 to 100 m) so volumetric fog reaches it. Surfaces stay matte (no
  screen-space reflections: since 2026-10-19 only puddles and glass reflect,
  through `PuddleMirror` on both renderers). Far backdrops with their own long fog range keep the
  shader's fog. Effect shaders have `fog_disabled`, so they look the same on
  both renderers.
- Shadows and ambient occlusion are INSANE only. On Compatibility a
  shadowed light breaks the vertex-lit materials (the moon's light drops out,
  a shadowed lamp redraws per pixel, brighter) and SSAO barely changes a
  pixel; Forward+ ignores omni shadows on vertex-lit materials, so lamps
  never cast. Anything added to the tree after the map (foes, the player,
  effects) gets `gi_mode` DISABLED on Forward+ so SDFGI never bakes it;
  a map's own moving parts (the backdrop's traffic, monorail, blimp and
  searchlights) call `Graphics.moving()` for the same.
- Compatibility shades in sRGB space and Forward+ in linear, so on Forward+
  `psx_lit` works its emission out from sRGB colours and converts the sum
  to linear (emission 0.1 read 22 on Compatibility and 89 on Forward+
  before). Dry faces in `psx_lit_hd` have no specular, like the plain
  shader.
- HDR glow on Forward+ has no bloom: bloom or wide glow levels turn the whole
  picture milky.
- Switching to or from INSANE writes `user://renderer.cfg` and asks for a
  restart (the settings footer's QUIT GAME becomes RESTART GAME). Old saves
  on HIGH (the old default) move to MEDIOCRE (settings v3).
- Command line `--quality=` changes the preset for that run only and never
  writes the renderer file; pass `--rendering-method forward_plus` to try
  INSANE's renderer.

---

## 15. Architecture

### 15.1 Game flow
`title` → `playing` ⇄ `paused` / `levelup` → `dead` → results → (R: same
seed | click: new seed).
- **Title:** shows the map built from the next run's seed, with the camera
  drifting and the title music playing. PLAY A SEED starts a run on a typed
  or pasted seed instead (§7.5).
- **Starting a run:** captures the mouse, starts the combat playlist and
  begins wave 1.
- **Pause** on Esc, focus loss or mouse-capture loss (the tree pauses; UI
  and audio keep processing).
- **Level-up** pauses the tree while the cards are open.
- **Restart** reloads the scene with the next seed (or the same seed).

### 15.2 Systems (as in the prototype; keep or refactor)
| System | Responsibility |
|---|---|
| `Game` (autoload) | Run state: seeds and RNG streams, palette, mutator, score, combo, XP and level, augments, run stats and per-wave snapshot, high scores, hitstop and slow-mo, `real_dt` |
| `Sfx` (autoload) | SFX pools (2D and 3D), throttling, music director, rain ambience |
| `Main` | Builds the scene from the seed (map → gore → fx → director → player → post → HUD). Owns the flow, boss-kill and death sequences |
| `Arena` + maps, `MapRegistry` | Level geometry, sky, neon, weather, spawn points, jump pads, floor heights |
| `WaveDirector` | Waves, composition, spawning, boss cycle, reinforcements, tally data, phase gating on the HUD (intro/tally/card ready) |
| `Player` | Movement, katana, shotgun, cells, dash, glory kills, damage, autoplay bot |
| `Viewmodel` | Weapon models, animation, glory poses, arc idle |
| `Enemy` / `Boss` | AI state machine (SPAWN, CHASE, WINDUP, RECOVER, STAGGER, CHARGE_WINDUP, CHARGE, SLAM, VOLLEY_WINDUP, plus boss states DASH_WINDUP, DASH, BLINK, GATLING, MISSILE_WINDUP, STOMP_WINDUP), poise, armour, glory hold, shock, death and gore, boss enrage and death |
| `Bolt` | Hostile bolts and shuriken (deflectable), the player's blood blade |
| `Gore` | Droplets, decals, gibs, emitters, mist, chunks, dismember modes |
| `Fx` | Damage numbers, arcs, impacts, beams, shockwaves, orbs, telegraphs, missiles, explosions, smoke |
| `Hud` | HUD, title, pause, level-up, results, initials, plates, score roll-up, combo, heat |
| `Juice` | Stamps, shake, sparks, fireworks, wave intro, tally, souls card, cut-in, data streaks, kill bursts, FINISH, the KIRI cards and slashes, the HIJACK blocks, diagonal letterbox, `later()` real-time scheduler |
| UI pieces | `Shard` (tech panel), `GlitchText`, `CutIn`, `SpeedLines` (data streaks), `ShardBurst` (kill burst), `KiriCard`, `HijackBlock`, `HijackFx` (takeover, giant name), `HazardBand` (warnings) |
| `PostFx` | Post-process material, hurt/flash/impact/heat, and the juice layer's cut, roll, invert and red negative |
| `Psx`, `TexGen`, `Ui` | Material factory, procedural textures, fonts and UI helpers |
| `Profile` (autoload) | The profile and the suspended run (§11): Player Level and XP, unlocks, equipped looks, top 10, settings, lifetime stats. Crash-safe files through `SaveFile`, migrations in `ProfileMigrations`, run snapshots in `RunSnapshot` |
| `Palette`, `Mutators`, `Upgrades`, `Rewards`, `Progression` | Data tables |

### 15.3 Time
- Gameplay uses scaled delta. Presentation (UI, juice, glory-kill
  finishers, hitstop and slow-mo timers) uses **`Game.real_dt` = delta /
  last applied `Engine.time_scale`**. This works in Movie Maker too; don't
  use wall-clock time.
- `time_scale`:
  - slow-mo factor (glory kill 0.25; boss kill 0.12 for 2.6 s)
  - hitstop ≤ 0.04
  - 0.35 while dead
  - forced to 1 while paused

### 15.4 Recommended improvements for the full game
- Move data tables (enemies, bosses, augments, mutators, palettes, rewards,
  names and codex) into **Resources (`.tres`)** so they can be tuned without
  code. (Audio cues and music tracks are done: §10.5.)
- Use scenes where they help tooling (maps, UI screens), but keep the
  procedural look.
- Add an **event bus** for game events (kill, glory kill, wave start and
  clear, boss felled, level up) so juice, audio and stats subscribe instead
  of being called directly.
- **Pooling everywhere** (§14). Use typed GDScript throughout.
- A **Settings** screen:
  - Audio buses (Master, Music, SFX, Ambience, UI); sensitivity, FOV, render
    scale, quality preset, FPS cap, VSync.
  - Screen-shake and flash intensity sliders (accessibility), key rebinding,
    window mode.
  - **Mouse only** (owner, 2026-10-18): click tabs, options and the footer
    (BACK, DEFAULTS, QUIT GAME), drag or scroll sliders, click a key slot then
    press the new key (or click the slot with a mouse button), right-click a
    slot to clear it. No keyboard navigation and no key hints; Esc still backs
    out.
- **Profile and save system** (§11). **Rewards and unlock menu** (§11.2).

---

## 16. Debug, testing and tooling (keep these)
- **Command-line flags** (after `--`):
  - `--autoplay`: a bot plays (aims, strafes, slashes, glory-kills staggered
    enemies with the finisher key, shotguns, auto-picks augments) and logs
    one stats line every 2 s.
  - `--god`: no damage.
  - `--wave=N`, `--seed=XXXX-XXXX`, `--boss=ninja|mech|oni`, `--restart`
    (auto-restart after death), `--verbose-ai`. With `--autoplay` every wave
    start prints a `[plan]` line and every level-up an `[offer]` line, which
    `tools/seed_check.sh` compares between two runs of one seed (§7.5).
  - `--showcase` (+`--bosses`): a frozen model line-up and gore demo.
  - `--juicetest` (+`--juicestart=T`, `--verbose-juice`): plays every
    presentation moment back to back.
  - `--movetest` (with `--headless --fixed-fps 60`): a scripted course on
    real physics that checks jump heights, ledge climbs, walls too tall to
    climb and plunges, then exits 0 or 1. CI runs it as
    `tools/movement_test.sh`.
  - `--augments=id,id:2|all`: start the run with those level-up cards
    (ids in `scripts/upgrades.gd`); `--cardtour`: deals every card, three at
    a time, for a layout check, then quits.
  - `--menutour` (+`--uiaudit`): every Focus menu in turn (§9.7): the
    title with each side panel, a suspended run and QUIT armed; pause with
    builds and the armory; a level-up hand with a card chosen; the results
    with a new best and initials typed; then quits. Debug profile only.
  - `--palettetour` (+`--palette=NAME|0-4`): four fixed views of the arena,
    1.5 s each, then quits; `--palette=` also forces the palette in a normal
    run (debug only; the seed still draws its palette number).
  - `--citytour` (+`--quality=`): The City Is Watching (§19.1 #9) from six
    fixed views, 37 s in all: a fake combo calls the news drones in, the
    screens swap pages, the score passes a made-up seed record (WIL 60,000)
    for NEW BEST, then the combo breaks and the drones fly off; then quits.
    Nothing is saved.
  - `--cans`: soda cans on for this launch (§19.1 #11); `--cantest` (with
    `--cans`): starts a run, fills the hands with the next three flavours
    each wave and drinks one every 2.5 s, to see the drink and every effect.
  - `--seedentry`: opens PLAY A SEED on the title.
  - `--settings=audio|video|controls|comfort`: opens the settings screen on
    the title at that tab.
  - `--runcard` (+`--runcard-out=DIR`): ends a sample run, saves its run
    card from the results screen and quits (exit 1 if no card was saved);
    with `--runcard-out`, copies the card and two results-screen captures to
    DIR. Needs a renderer: `xvfb-run -a godot --path .
    --rendering-driver opengl3 -- --runcard` in the cloud.
  - `--record-mix=DIR`: records each audio bus to `DIR/<bus>.wav` on quit, to
    measure the mix (use with `--write-movie` so audio follows game time).
  - `--quality=low|medium|high`: the effect-count preset (§14).
  - `--perf`: shows the perf overlay, logs draw calls, live nodes and node
    churn every 2 s, and prints a summary at exit.
- **Perf overlay:** F3 in any build (fps, frame time, draw calls, nodes,
  new nodes per second, quality preset).
- **Dev menu:** F10 in any build, on the title, in a run (pausing first) and
  on the pause screen (`DevMenu`, settings in `DevSettings`). A developer
  tool, not a player feature: nothing on screen points to it, it is titled
  DEV SETTINGS, and F10 is reserved from key rebinding. Mouse only, like the
  settings screen.
  - LOOK: perf overlay, hide the HUD while playing, force a palette from
    the next run. Its plain-look switch became the player's RETRO LOOK
    setting (§9.1; owner, 2026-10-19), and nothing in the dev menu is saved
    any more.
  - RUN: god mode, autoplay bot, game speed (25 to 200%, menus keep real
    time), start wave, force a boss, force a mutator. Session only, so a
    cheat never carries into the next launch.
  - ACTIONS: skip the wave (kills every enemy), a level-up offer, every
    card at max rank, refill HP and cells, restart the seed, a new seed,
    the juice test.
  - **Dev runs:** a run with anything from RUN on, or an ACTION used, is a
    dev run (`Game.dev_run`, kept in its suspended snapshot). It writes no
    top 10 entry, no Player Level XP or lifetime stats, and no boss
    unlocks. A DEV tag under the score lists what is on; the menu says the
    same. Restarting from the menu pays the run on screen into the profile
    like an abandoned run first (unless it is a dev run), so no progress is
    lost. Debug flags: `--look=off|light|full` (`--plain` = off), `--dev=look|run|actions`.
- **Perf probe:** `tools/perf_bench.sh headless|render [wave] [frames]
  [quality]` runs the autoplay bot on a fixed seed with `--perf`. Draw calls
  and node counts are the same on any machine; frame times only mean
  something on real hardware.
- **Headless smoke test:**
  `godot --headless --path . --quit-after 3000 -- --autoplay --god`, which
  must log **zero script errors**. Run `--import` after adding assets or
  classes.
- **Frame and video capture:**
  `xvfb-run godot --path . --resolution 960x540 --write-movie out/f.png
  --fixed-fps 30 --quit-after N -- --juicetest` (or `--autoplay`), then
  ffmpeg the frames and `f.wav` to mp4.
- **Generators:**
  - `tools/gen_audio.py` (SFX, numpy/scipy/ffmpeg)
  - `tools/gen_music.py` (placeholder soundtrack)
  - Both are placeholders until real audio arrives.
- **Exports:**
  - `godot --headless --export-release "Windows Desktop"
    build/windows/KatanaShotgun.exe` (embed_pck); likewise `"Linux"`
    (`build/linux/KatanaShotgun.x86_64`) and `"macOS"`
    (`build/macos/KatanaShotgun.zip`).
  - There is no Web preset; the game is desktop only.
- Add: save-system tests (corrupt file, version migration, crash mid-write).
- CI and releases: see PART S (S4). The release workflow runs the smoke test
  before exporting.

---

## 17. Prototype status (v0.3): keep vs change

**Built and working:**
- All mechanics in §3–§7: katana, arc shotgun, cells, dash, jump, deflect,
  stagger, glory kills (6 finishers), burn, orbs, augments, mutators, waves,
  3 bosses, scoring, combo, tally, high scores with initials, seeds.
- The Shin-Kagura Rooftop map with weather.
- The PSX look and post-process; gore; FX.
- The cyberpunk UI (tech panels, glitch text, cut-ins, FINISH, souls cards,
  level-up animation, title animation).
- The music director and placeholder audio.
- Debug tools and a Windows export.

**Must change (feedback):**
1. **Readability (§9.9).** Rework GlitchText, stamps, cut-ins and the tally so
   text is clean while held, numbers never scramble, there are no
   overlapping duplicates, and tags are decoration only.
2. **Audio mix (§10.3).** The rain loop is far too loud; set up buses; music
   first. (Done: five buses, music on top, quiet layered rain; see §10.1.)
3. **Palettes (§9.2).** Too purple; make every scene multi-colour.
   (Reworked into a six-accent multi-colour base; see §9.2.)
4. **Pooling and performance (§14).**
5. **Katana model (§9.6).** Thermal-katana look (red-hot orange edge), our
   own design.
6. Copy cleanup: any text still saying "execution" should say "glory kill".
   The data still uses the internal id `executions`, which is fine.

**Not built:**
- Persistent Player Level, profile save, run suspend/resume, boss rewards
  and unlocks (§11).
- Settings menu, audio buses, key rebinding.
- Codex. New maps. Boss variants.
- The professional soundtrack and SFX.

---

## 18. Work list (prioritised)

### 18.1 Critical feedback fixes
- [ ] Readability rule across all UI and juice (§9.9), verified with the
      paused-frame test.
- [ ] Audio buses and the new mix; quiet, filtered, varied rain; music first
      (§10.1, §10.3).
- [x] Multi-colour palettes and accent distribution (§9.2). Feel on a real
      GPU still to be confirmed by the owner.
- [ ] Pool every runtime-spawned object; cap and recycle; shader warm-up;
      perf overlay; hit the frame-time targets (§14).

### 18.2 Progression and saving (critical)
- [x] Profile save with versioning, atomic writes and a backup (§11.3).
- [x] Player Level XP formula, results roll-up and level-up celebration
      (§11.1). The formula is a default until the owner decides (§19).
- [x] Run suspend/resume between waves, with CONTINUE RUN on the title
      (§11.3).
- [x] Boss rewards: drop rules, reward card, a simple cosmetics menu
      (§11.2). Drop rules and the list are defaults (§19); unlock pools for
      maps, palettes and mutators wait for that content.
- [x] Move high scores into the profile.

### 18.3 Quality of life
- [x] Settings screen (§15.4), key rebinding (LMB katana / RMB shotgun by
      default). Built in `scripts/settings.gd` and
      `scripts/ui/settings_menu.gd`; settings are stored in the profile
      (§11.3). Comfort: below 100% flashes, impact frames don't strobe.
- [x] Clear "PLAYER LV" vs "RUN LV" labelling.

### 18.4 Content (later)
- [ ] Thermal-katana redesign; final shotgun design (OPEN).
- [ ] Tokaido Expressway (procedural corridor), Takamagahara Spire
      (vertical), Ryugu Arcade, Kurama Dojo.
- [ ] Boss variants plus new bosses from the name pool.
- [ ] Professional soundtrack (stems and loops) and SFX replacement.
- [ ] Optional: a Latin-Extended font fallback to restore macrons; a codex
      of mythic names.

---

## 19. Open decisions (ask the developer; don't invent)
- The Player Level **XP formula** and pacing.
- **Perfect Deflect** (§19.1 #3, built 2026-10-19 as a play-test
  experiment, tuning in §3.2): keep, retune or drop it after playing.
- **Soda cans** (§19.1 #11, built 2026-10-19 as a DEV-ONLY play-test):
  keep, retune or drop them after playing; then whether they leave the DEV
  menu.
- **Map stages and the boss schedule** (owner idea, 2026-10-18; proposal
  in §6.4, built once a second map exists). To decide, with the defaults
  §6.4 recommends:
  1. The schedule: the balanced one (bosses on waves 5 | 9, 13 | 16, 19,
     22 | …) or the owner's sketch (10 | 15, 20 | …).
  2. Seeded map order with a fair-opener rule for stage 1 (recommended).
  3. Which boss guards which map. Default: KUROKAGE guards Shin-Kagura;
     TETSUGUMO and SHUTEN guard the next maps until those get new bosses.
  4. Maps leave the boss reward pool, so one seed deals every player the
     same journey (recommended).
  5. Up to 4 bosses per stage, then the maps repeat in a new seeded order.
  6. The first wave on a new map has no mutator (default yes); no extra
     heal on a map change (default).
- The full **boss reward** list (the drop rule is decided: every kill
  unlocks that boss's next reward, §11.2).
- The **final shotgun look** (the katana reference is decided: Thermal
  Katana style).
- The **full difficulty curve** past the early waves (tune by playtesting;
  waves 1–3 stay easy).
- **Controller support** (not requested yet).
- A daily seed, made offline from the date (mentioned early, not confirmed). Online leaderboards are ruled out: the game stays offline (owner, 2026-10-18).
- A **Steam** release and cloud saves.
- Whether in-game text gets macrons back (needs a fallback font).
- Repo visibility (public, or private plus a public releases repo), the
  publisher name, code signing, Mac builds (PART S).


### 19.1 Ideas to try (owner, 2026-10-18)
From the competitor research (claude.ai doc "KATANA / SHOTGUN: Market
Research"). The owner wants each built later as something to play-test; he
decides after trying it whether it stays. None is approved for a release
yet, and each needs a spec update with its tuning when it is built.
1. **Seed Duels.** The results screen gives a short code with the seed,
   initials, the game version and the score after every wave. A friend
   pastes it and plays the same seed with a rival line on the HUD ("vs WIL
   +2,350") and a head-to-head row in each tally. Offline: the code travels
   by hand. Put the version in the code (seeds break when the game
   changes) and mark a player's first attempt on a seed. Pasted into the
   PLAY A SEED box (§7.5).
2. **Two Hands, One Rhythm.** Alternating katana and shotgun kills earns an
   extra combo step and lights the matching hand on the HUD; a clean
   left-right-left chain gets a stamp. A bonus only, never a penalty, so
   katana-heavy builds stay good. Name to pick from §13 (candidate: NITEN,
   after Musashi's Niten Ichi-ryu).
3. **Perfect Deflect.** BUILT 2026-10-19, awaiting the owner's verdict
   after play-testing; tuning in §3.2 (Perfect deflect). A deflect in the
   last 0.15 s before a bolt lands is PERFECT: a ringing clang, a white
   flash, ×12 return damage, +2 cells, a tally row, and on each boss's white
   signature volley a +20% KAMAE hit. The normal deflect is unchanged.
   KAMAE also drains more slowly as the boss loses HP (Sekiro; owner,
   2026-10-19, §5.5).
4. **Bet on the wave.** The wave intro offers the seeded mutator and the
   player takes it (for its score multiplier) or passes; later waves may
   offer a second to stack. The same seed offers the same choices; harsh
   mutators keep their `min_wave`. One key press, so the wave start stays
   quick.
5. **On the beat.** Presentation snaps to the music's beat (tracks already
   store their bpm): glory-kill flashes, KAMAE BROKEN, combo stamps, the
   tally slam, neon and spawn-beam pulses. Only effects wait for the beat,
   never a hit or an input. The player never has to play in rhythm.

Ideas 6 to 10 build on the shared seed and work fully offline: players
swap a short code or a small file by hand. The seed entry box most of them
build on is in: PLAY A SEED on the title (§7.5).
6. **Challenge Codes.** A code carrying a seed plus rules the sender picked
   from what exists: mutators locked on for every wave, a starting build, a
   wave to reach and a score to beat. A "dare a friend" builder after a
   run. Challenge scores sit on their own board, never mixed with normal
   high scores.
7. **Ghost Ronin.** A small file of a run (the player's position and big
   moments, a few times a second) that a friend loads on the same seed:
   the run plays back beside them as a see-through neon ronin. A recording
   only; it never touches the run.
8. **Legendary Seeds.** A title-screen shrine of named, hand-picked seeds,
   each with bronze, silver and gold scores; a medal saved per seed. New
   seeds join with updates or as boss rewards. Re-check the list each
   update, since seeds change when the game changes.
9. **The City Is Watching.** Shin-Kagura reacts to the run: news drones
   gather as the combo climbs, billboards show kills and score live, and
   city screens show the top initials for this seed (yours, or the friend
   whose code is loaded). Presentation only, scaled by the graphics preset.
   **BUILT for play-testing (2026-10-19), awaiting the owner's verdict.**
   `CityWatch` (`scripts/maps/city_watch.gd`, one per `CityBackdrop`) and
   `CityScreen` (`city_screen.gd`). Tuning (constants in `city_watch.gd`):
   - **Drones:** one TSUKUYOMI news drone per 4 combo, capped per preset
     (WEAK 4, MEDIOCRE 8, INSANE 12, §14). Each is a 6 m rig (neon rotor
     rings, a lit belly, a white lens, a blinking red light, a soft glow
     round it) that flies in from the city over 2.6 s to its spot on a
     ring 22 to 26 m round a point 60% of the way from the roof's centre to
     the player (the point drifts after the player slowly), 17 to 23 m up:
     above everything on the roof (the beacon cap is +13) and the 13 m
     traffic lane, inside the 57 m one, so nothing flies through a drone.
     Drones face the player and point a faint light cone at them, at most
     20 m long and always ending 6 m or more short of the player. When the
     combo drops they stay 5 s, then one leaves every 0.8 s. Their lenses
     flash at combo 10, 25, 50, 75, 100, 150 and 200 and on a new seed best
     (lens only, scaled by the flash slider). Drone motion uses game time,
     so slow-mo and hitstop slow them too.
   - **Screens:** four 36 x 19 m screens on masts 59.5 m out, centred 40 m
     up so they clear the north deck and shrine tower from the south roof
     (north-north-west, north-north-east, west, east; all four on every
     preset, so WEAK never shows an empty frame). Each alternates TSUKUYOMI LIVE (score; kills, or the
     combo while it is 4+) for 7 s and the seed page (SEED code, the best
     saved initials, BEST score; OPEN / NO RECORD YET when none) for 5 s;
     odd screens start on the seed page, so the two north screens never
     both show it. Passing the seed's record shows NEW BEST /
     "<initials> BEATEN" on every screen for 4 s, once a run; after that
     the seed page reads THIS RUN / AHEAD OF <initials>. Page swaps
     squash the text to a line and back (0.16 s); held text is still,
     Jersey 10 at whole multiples of 19 px on a plain dark plate, and a
     line too long for the plate shrinks to fit. Timing uses real time.
   - The record is the best entry in the profile's top 10 on this seed
     (only top-10 runs are saved). A friend's record waits on Seed Duels
     (#1), which brings codes.
   - Presentation only: reads `Game` and `Profile`, writes nothing; its
     randomness comes from `Game.rng_fx`, never a gameplay stream or the
     backdrop's, so the run and the city's look are unchanged (unit test).
     Draw cost: drones 5 surfaces + 1 light MultiMesh, plates 1
     MultiMesh, masts and frames join the backdrop's batches, 3 Label3D
     per screen. Check it with `--citytour` (§16).
10. **Run Cards.** One key on the results screen saves a postcard image to
   the Pictures folder: seed code, score, wave, builds, bosses felled and
   the run's best moment, in the game's style. No internet.
   **BUILT (2026-10-19), awaiting the owner's verdict.** Once the results
   have counted up, **P** (for picture) or RUN CARD in the results row
   saves a 1920x1080 PNG to `Pictures\KatanaShotgun\` (the save
   folder's `run_cards` if there is no Pictures folder); the top right
   corner then says where it went and OPEN FOLDER (or **O**) shows it in the file
   manager, ready to drag into a chat. The card is drawn at the UI's 480x270
   and scaled 4x with hard pixels: the run's palette as a dithered sky,
   striped sun, skyline and floor grid, then dark plates holding the score,
   wave, best combo, kills, glory kills, time, bosses felled, builds linked
   (2/3) or complete, the best moment (the run's biggest end-of-wave payout,
   else its best combo), initials and table place if the run made the top
   10, Player Level, map, version and the seed as `XXXX-XXXX` in the pixel
   face (0 and D never look alike), the form the title's seed box takes. The
   skyline comes from the seed through its own RNG, never the run's streams.
   Code: `scripts/ui/run_card.gd`, `run_card_panel.gd`; check with
   `--runcard` (§16).
11. **Soda cans** (owner idea, 2026-10-19). INARI FOODS drinks found on the
   map, each a short, strong buff and then a shorter, milder "sugar crash".
   **BUILT as a DEV-ONLY play-test (2026-10-19), awaiting the owner's
   verdict.** It adds a pickup system on purpose (the owner signed off, §0.3);
   off by default, it is switched on in the DEV menu (F10, RUN tab, SODA
   CANS, from the next run; saved as `dev_cans` in settings.json). Off means
   no can is ever made and nothing draws a number. A run with cans keeps its
   XP and unlocks but makes no top 10 entry or lifetime best score (`Game.cans_run`), so seeded
   scores stay comparable; the DEV tag says CANS RUN: NO TOP 10.
   - **Where:** one can on waves 2 to 5, two from wave 6, none on boss
     waves, at spots picked from `Game.rng_cans` (reseeded per wave from the
     seed and the wave, so cans never shift enemies, mutators or offers) out
     of `Arena.pickup_spots()`: platform tops and edge spawn points at most
     12 m up with 2.2 m of open air above, two in a wave at least 8 m apart.
     Each can glows with a 7 m light pillar and a ground ring in its colour.
     Cans left on the floor vanish when the wave is cleared.
   - **Pickup:** walk within 1.5 m. Up to 3 in hand; with 3, cans stay on the
     floor and the hint lane says CANS FULL (at most every 4 s).
   - **Drink:** **E** (`drink`; not in the rebind list while dev-only, since
     the Controls tab holds 10 rows), the mouse wheel (`can_next`,
     `can_prev`) picks the can. 0.9 s: the shotgun drops to the hip, the can
     comes up, the katana's cut takes the top off at 0.32 s (fizz, a lid
     spinning away, a 0.03 s hitstop, the effect starts), the player downs
     it with the head tipped back, tosses it, and the shotgun is back. Both
     weapons wait (clicks buffer as usual), glory kills wait, movement,
     jumps and dashes do not. A press 0.2 s early counts. One effect at a
     time: a new drink replaces the current one and skips its crash.
     Effects run on game time.
   - **Reading it:** picking a can up (or wheeling to it) puts one line in
     the hint lane, head in the can's colour: its name (the first can of a
     run adds "E TO DRINK"; one that feeds a build you own adds FITS
     <BUILD>), then what it does, crash included. In hand, cans are small
     blocks under the cell number, the selected one bright and underlined.
     While one works, a timer runs along the vitals frame's top edge in its
     colour, then grey-red with CRASH over it. Opening one slams its name
     into the top lane, sprays its colour and flashes the frame's corners.
     The pause screen lists the cans in hand with full text. (A parallel
     thread is restyling the juice screens; can juice uses today's
     `Juice.stamp` and may be restyled with it.)
   - **Flavours** (`scripts/soda.gd`, all tuning there):

     | Can | Buff | Crash | Feeds |
     |---|---|---|---|
     | KAZE RUSH | 12 s: +25% move speed, dash recharge 2x | 5 s: dash recharge 1.5x slower | STORM RUNNER, GHOST |
     | KAMINARI SPARK | 15 s: katana kills +1 cell each | 5 s: shotgun cooldown x1.3 | THUNDER CHAIN |
     | SHIRANUI BLAZE | 12 s: katana hits set foes on fire | 5 s: move speed x0.85 | INFERNO |
     | MIKAZUKI ZERO | 15 s: headshots +50% | 5 s: damage dealt x0.85 | HEADHUNTER |
     | AKANAME RED | 12 s: katana hits heal 3 HP per foe | 6 s: health orbs heal half | BLOOD ENGINE |
     | UZUME POP | 12 s: combo never drops | the combo halves when it ends | SHOWSTOPPER |
     | GAKI BLACK (risk, wave 4+) | 15 s: kill score x2, damage taken x2 | none | any |
     | YUKI CHILL | 10 s: damage taken x0.7 | 5 s: katana cooldown x1.25 | RONIN |

     Natural pairings with mutators: YOMI BLACKOUT and KAMINARI SPARK,
     MATSURI RUSH and UZUME POP, SENRYO BOUNTY and MIKAZUKI ZERO; KANASHIBARI
     and KAZE RUSH cancel out. Multipliers stack with mutators and cards, no
     cap yet (play-test).
   - **Code:** `Soda` (data), `SodaCans` (runtime, `Game.cans`;
     `Game.boost(key)` and `Game.boost_flag(key)` are the hooks gameplay
     reads), `ViewmodelCan` (the hands), `SodaHud` (HUD). Sounds `can_pickup`,
     `can_open`, `can_gulp`, `can_crash` (placeholder, `tools/gen_audio.py
     cans`). Debug: `--cans` turns them on for a launch; `--cantest` (with
     `--cans`) starts a run, fills the hands with the next three flavours
     every wave and drinks one every 2.5 s; DEV menu CAN FLAVOUR forces a
     flavour and GIVE CANS fills the hands (both make a dev run).
   - **Open after play-testing:** keep, retune or drop; drink length;
     whether cans appear on boss waves; whether the drink key joins the
     rebind list (needs a scrolling Controls tab); stacking caps.


### 19.2 Standing apart from Mullet MadJack (owner, 2026-10-18)
Mullet MadJack is the closest rival players will name (retro anime
cyberpunk FPS, blade and shotgun, endless mode, 97% positive). It is a
3 to 4 hour comedy campaign of tiny rooms against a 10-second timer; its
reviews complain most about repetition and weak bosses. KATANA / SHOTGUN
is its opposite, and these five areas are the direction to strengthen
when planning work:
1. **Bosses are the showpiece.** KAMAE, real movesets and the ONIKIRI are
   our deepest system and their weakest point. Perfect Deflect (§19.1 #3)
   and the planned boss variants push it further.
2. **Big arena, big crowds.** Up to 22 enemies at once on a rooftop with
   six floor heights, against their small rooms. Keep the one map fresh
   (The City Is Watching, §19.1 #9) and add the planned maps.
3. **A game that lasts.** Endless waves, seeds shared between friends,
   Challenge Codes and Legendary Seeds give months of play, not a short
   campaign.
4. **Both hands, all the time.** Katana and shotgun always in hand, each
   feeding the other; Two Hands, One Rhythm (§19.1 #2) makes it the thing
   every clip shows.
5. **Our own mood.** Stylish, serious and mythic ("loud, then quiet"), not
   jokey. Don't add a timer, a story campaign or comedy because it worked
   for them.
Match them on the basics: a free demo, comfort options (shake and flash
sliders exist) and controller support (still an open decision, §19).

---

## 20. Acceptance checklist (definition of done for any change)
- [ ] It runs with **zero script errors** in the headless autoplay smoke
      test and a 10-minute autoplay run.
- [ ] The **same seed gives the same run** (map, palette, waves, mutators,
      bosses, offers).
- [ ] Wave 1–3 stays easy for a new player. Difficulty clearly climbs
      later.
- [ ] Every flash is **readable on a paused frame** (§9.9).
- [ ] **Music is clearly the loudest layer.** No constant hiss or white
      noise.
- [ ] **Several distinct neon colours** are on screen in every scene.
- [ ] Performance targets met on low-end hardware (§14), with no
      combat hitches.
- [ ] Progress survives a quit or crash at any point (once §11 lands).
- [ ] Hands: **katana left (LMB), shotgun right (RMB).**
- [ ] Names follow §13 (Japanese myth or history + cyberpunk, readable,
      never copied from FromSoftware or other IP).
- [ ] No new mechanics added without sign-off (§0.3).
- [ ] Changelog note added in `changelog.d/`. For releases: the tag pushed,
      CI green, the Release has the installer and zips, and the installer
      was tested by the developer at least once per release.
