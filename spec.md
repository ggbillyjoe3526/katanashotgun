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
  release `0.1`. The current version is `0.1 Dev 1`.
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
| Music style | Fast, futuristic, energetic synthwave/retrowave tempo, glitchy and distorted, with less synth: distorted guitars, reese and growl basses, glitch percussion (§10.2); placeholders regenerated to match, real tracks to follow (owner, 2026-10-18) |
| Version names | `0.1 Dev N` → `0.1 Beta N` → `0.1`; current `0.1 Dev 1` (owner, 2026-10-18; `VERSIONING.md`) |
| Changelog notes | one file per PR in `changelog.d/`, gathered into `CHANGELOG.md` at release by `tools/changelog.sh release`, so parallel PRs don't conflict (2026-10-18) |
| Code signing | not yet |
| Mac builds | built (universal, unsigned zip); optional, dropped if it causes trouble |
| Glory kill trigger | Press F (`finisher` action), like Doom 2016, instead of slashing a staggered enemy (owner, 2026-10-18) |
| Boss reward drop rule | Every kill of a boss unlocks its next reward until its list is done; never random (owner, 2026-10-18) |
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
  support (§14). Consider Mobile or Forward+ only if profiling shows a clear
  win without losing low-end support.
- **Targets:** Windows x86_64 first (the developer's PC is Windows x64), then
  Mac and Linux. Export Windows with `embed_pck = true` for a single exe.
- **Display:**
  - 3D internal resolution **960×540**, stretch mode `viewport`, aspect
    `expand`, stretch scale **2.0**, so the UI is laid out in **480×270**
    canvas units.
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
- **Window:** start windowed, F11 or Alt+Enter toggles fullscreen. Pause when
  the window loses focus or the mouse capture is lost.

### 2.1 Input map (defaults; everything rebindable)
| Action | Default | Notes |
|---|---|---|
| `katana` | **LMB**, J | Left hand. Hold to keep slashing (input buffer 0.18 s) |
| `shotgun` | **RMB**, K | Right hand. Hold to keep firing at the cooldown rate |
| `move_*` | WASD + arrows | |
| `jump` | Space | Double jump |
| `dash` | Shift, Q | |
| `finisher` | **F** | Glory kill the staggered enemy near the crosshair (§3.4) |
| pause | Esc | |
| sensitivity −/+ | `[` / `]` | Shortcut; also in Settings |
| settings | Tab (title, pause) | Settings screen (§15.4) |
| fullscreen | F11 / Alt+Enter | |
| retry same seed | R (results screen) | |
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
| Jump / double jump | 9.4 / 8.6 m/s (1 extra jump, reset on landing and on jump pads) |
| Dash | 2 charges, 21 m/s for 0.2 s, invulnerable for 0.3 s, recharge 1.4 s per charge (−0.3 s per Idaten Drive rank), FOV kick +14 |
| Camera | FOV 88; trauma-based shake (decay 1.6/s, squared); strafe tilt; head bob; landing dip; FOV kicks |
| Capsule | radius 0.4, height 1.8, eye height 1.55 |
| Hit invulnerability | 0.12 s |
| Fall reset | below y = −10, respawn at the map spawn |

### 3.2 Katana (LEFT hand, LMB): "DOJIGIRI"
- **3-hit combo:** left→right, right→left backhand, overhead chop.
  - Cooldown 0.32 s, or 0.45 s after the third hit. The combo resets if you
    don't swing for 0.65 s.
- **Hit area:** reach 3.4 m (+0.8 per Long Reach rank), half-arc 68° (+14° per
  rank), vertical tolerance about the enemy's half height + 1.7 m.
- **Damage:** 50 per hit, ×(1 + 0.35 per Masamune Edge rank), ×the mutator.
  Poise damage 18, knockback 4.
- **Armour:** against armoured enemies (that aren't staggered) the katana does
  `armor + 0.12 × Masamune rank` of its damage, with sparks and a clang.
- **Cleaves:** hits every enemy in the arc.
- **Charging the shotgun:** each katana kill gives +1 cell (+1 more per Blood
  Battery rank). Each deflect gives +1 cell.
- **Deflect:** a slash sends back hostile bolts within reach +2.2 m and the
  half-arc +0.35 rad. The bolt reverses toward the enemy nearest the
  crosshair (auto-aim if the dot product > 0.96), at ≥36 m/s, for 95 damage,
  turning cyan. Its kills are tagged "RETURN TO SENDER" (points ×1.5).
- **Hit feel:** hitstop 0.045 s + 0.012 per enemy hit (up to 4), trauma
  0.22, slash trail, slice sound.
- **A slash just hits a staggered enemy** (full damage, armour ignored, so it
  can kill it outright). The GLORY KILL is its own key, F (§3.4).
- **Look:** see §9.6. The glowing edge flares on each swing.

### 3.3 Shotgun (RIGHT hand, RMB): "RAIJIN-12" arc shotgun ("shotgun taser")
- **Gameplay is exactly a shotgun.** Presentation is electric.
- **Pellets:** 10 hitscan pellets per blast (+3 per Raijin's Fork rank).
  - Spread: a random disc of radius 0.085 rad. Range 48 m.
  - Damage 13 per pellet × falloff × mutator. Falloff is
    `clamp(1 − (dist − 7)/22, 0.3, 1)`.
  - **Headshot ×2:** a pellet counts as a headshot if it hits above the
    enemy's `head_y`. The blast counts as a headshot (popping the head on a
    kill) if any pellet hit the head and ≥3 pellets hit that enemy.
- **Effect per enemy:** all pellet damage is summed into one hit.
  - Poise damage = that damage × (1 + 0.6 per High Voltage rank).
  - Knockback 6 + 8 per High Voltage rank.
  - Kagutsuchi Flame ignites the target (§3.6).
- **Ammo is CELLS.** 4 max to start (+2 per Fujin Bank rank). Each blast uses
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
  and "GLORY KILL" ("DEATHBLOW" on bosses) sits in a fixed spot under the
  crosshair (§9.7), and that enemy's stagger marker turns gold and grows.

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
- **Presentation:** cinematic bars, data streaks, an impact frame on each
  beat, FOV −10, the dash whoosh.

**Finisher selection:**
| Situation | Finisher | Beats (seconds from start) | Gore |
|---|---|---|---|
| Boss | X-cut then point-blank blast | 0.12 slash, 0.26 slash, 0.46 aim, 0.56 blast + kill; length 0.95 | Deathblow, or full kill |
| Brute | Climb up, chop the skull, blast down into the neck | 0.02 raise overhead, 0.20 chop, 0.42 aim down, 0.52 blast + kill; length 0.95; the camera rises 0.9 m | headpop |
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

**Bosses:**
- The finisher deals a **15% max-HP deathblow**, with a DEATHBLOW stamp (or
  cut-in) and a blood geyser. The boss's stagger ends and it is knocked back.
- If the boss has ≤15% HP left, the deathblow kills it.
- A boss glory kill also triggers the holographic cut-in "DEATHBLOW!".

**On end:** release the enemy if it is alive, keep 0.35 s of invulnerability,
hop back (−dir × 3 + up 2), katana cooldown 0.12.

### 3.5 Stagger and poise (all enemies)
- Each enemy has **poise**. Damage reduces it. When it hits 0 the enemy is
  **STAGGERED** for `stagger_time`: a pulsing marker, dim eyes and a windup
  sound. Hint the first time: "STAGGERED! PRESS F FOR A GLORY KILL" (the
  bound key's name).
- Poise regenerates once no hits land for 2.0 s (bosses 1.4 s). It regains 35%
  of max per second (bosses 50%).
- The shotgun is the main stagger tool. Armoured enemies (brutes, bosses)
  need it.

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
- **Each level-up** pauses the game (tree paused) and offers **3 augments**,
  drawn as a seeded Fisher–Yates pick from the pool not yet at max rank.
  Choose with click or 1/2/3. Several pending level-ups chain.
- **Augments** (they change *how* a weapon behaves, never +2% stats):

| id | Name | Tag | Max | Effect |
|---|---|---|---|---|
| edge | MASAMUNE EDGE | KATANA | 3 | Katana damage +35%/rank; better against armour (+0.12/rank) |
| reach | LONG REACH | KATANA | 2 | Katana range +0.8 m and arc +14°/rank |
| wave | SUSANOO'S WAVE | KATANA | 3 | Every (4 − rank) slashes launch a piercing blood blade (26 m/s, 40 + 15 × rank damage) |
| vamp | VAMPIRIC STEEL | KATANA | 3 | Heal 1 HP × rank per enemy the katana hits |
| battery | BLOOD BATTERY | SYNERGY | 2 | Katana kills charge +1 extra cell per rank |
| pellets | RAIJIN'S FORK | SHOTGUN | 3 | +3 arcs (pellets) per blast |
| tube | FUJIN BANK | SHOTGUN | 3 | +2 max cells, charged immediately |
| dragon | KAGUTSUCHI FLAME | SHOTGUN | 2 | Arcs set enemies alight (burn, §3.6) |
| concuss | HIGH VOLTAGE | SHOTGUN | 2 | Blasts stagger 60% harder and knock back further |
| dash | IDATEN DRIVE | MOBILITY | 2 | +1 dash charge, faster recharge |
| dashcut | KAGE STEP | MOBILITY | 2 | Dashing through enemies slices them (40 × rank × edge bonus) |
| chain | HYAKUNIN-GIRI | SYNERGY | 1 | Glory kills stagger every enemy within 9 m |
| hotbarrel | FEEDBACK LOOP | SYNERGY | 1 | Shotgun kills refund one dash charge |
| chrome | KONGO HEART | BODY | 3 | +25 max HP and a full heal |

Tag colours: KATANA cyan, SHOTGUN electric blue, SYNERGY hot pink, MOBILITY
acid green, BODY pale gold.

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
- **Glory kill on a boss** = a 15% deathblow (§3.4).
- **Boss bar:** top centre, showing "NAME – EPITHET".

### 5.2 The bosses

**Kurokage, Blade of the Null Signal** (the ninja)
- Felled line: **SHADOW DELETED**.
- HP 2600, speed 5.2, radius 0.5, height 2.1, head_y 1.72, poise 290, stagger
  2.6 s, armour 0.55, XP 320, points 5000.
- **Dash-slash chain:** 2 dashes (3 when enraged). Each has a floor
  telegraph line 16 m long (neon). Windup 0.62 s (0.42 enraged), shortened on
  follow-ups. Each dash hits 20 with knockback.
- **Shuriken fan:** deflectable, 13 m/s, 10 damage, spread 0.16 rad.
- **Blink:** vanishes in smoke and reappears behind you.
- **Melee combo:** 2 hits (3 enraged), 16 damage each.
- Strafes at mid range. Specials every 3.2–4.6 s (2.2–3.2 enraged).
- Look: brighter suit with neon piping, a long glowing blade and a trailing
  scarf.

**Tetsugumo, Chrome Broodmother** (the spider mech)
- Felled line: **MACHINE DECOMMISSIONED**.
- HP 4400, speed 2.6, radius 1.7, height 3.6, head_y 2.5, poise 560, stagger
  3.2 s, armour 0.35, XP 420, points 7000, mass 14.
- **Sweeping gatling:** windup, then a sweep of 7-damage, 14 m/s bolts that
  can be deflected.
- **Missile strikes:** beeps, then several missiles land at red-ring
  telegraphs around the player (2.6 m radius, 20 damage, ~1.5 s delay each).
- **Stomp:** within 6 m. A 12 m shockwave that does 22 damage; jump over it.
- **Calls her brood:** 3 adds (skipped if more than 6 enemies are alive).
- Keeps 8–15 m away and strafes. Specials every 4.2–5.6 s (3.0–4.2 enraged).
- Look: six legs, gatling, missile pods, glowing core. It explodes on death.

**Shuten, the Overclocked Daemon** (the oni)
- Felled line: **DAEMON PURGED**.
- HP 5200, speed 4.4 (5.6 enraged), radius 1.05, height 3.4, head_y 2.8,
  poise 500, stagger 3.0 s, armour 0.5, XP 500, points 8000, mass 9.
- **Melee:** 2–3 hit combo, windup 0.7 s (0.45 on follow-ups), 32 damage each
  within 4.6 m + radius, with knockback.
- **Leap slam:** a 24 m shockwave that does 26 damage; jump over it. Hint:
  "JUMP OVER THE SHOCKWAVE".
- **Charge:** like the brute's.
- **9-bolt fan volley:** enraged only. 14 damage, spread 0.13 rad.
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
In-game names drop macrons (§13).

| id | Name | Effect | Score × |
|---|---|---|---|
| overdrive | IDATEN'S HASTE | Enemies move 25% faster | 1.5 |
| glass | MURAMASA'S CURSE | You deal and take +50% damage | 1.3 |
| bloodmoon | AKATSUKI | Enemies ×1.4 HP; glory kills heal double | 1.4 |
| drymag | YOMI BLACKOUT | No passive cell recharge | 1.3 |
| swarm | HYAKKI YAKO | 60% more grunts, at 70% HP | 1.2 |
| snipers | TEPPO VOLLEY | Double the gunners | 1.3 |
| ironclad | KANABO VANGUARD | Two extra brutes | 1.4 |
| storm | RAIJIN'S STORM | Lightning flashes, thunder and heavy rain | 1.25 |
| vampire | JOROGUMO'S BITE | Kills heal 2 HP; enemies hit 30% harder | 1.2 |

The mutator name shows under the wave label on the HUD, with its multiplier.

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
- The HUD shows "HI 0000000" centre top. Passing the best score triggers a
  stamp/cut-in "NEW HI-SCORE" once per run.
- **Results:** a qualifying score asks for initials (A–Z, 0–9; Enter
  confirms; blanks become "-"), then the table appears with the new entry
  highlighted. **R** retries the same seed; a click or Enter starts a new
  seed.

### 7.5 Seeds
- A 31-bit run seed, shown as **XXXX-XXXX** hex. It can be forced with
  `--seed=XXXX-XXXX`.
- Separate RNG streams:
  - `rng_map = hash(seed × 3 + 1)`: map pick, palette, weather, cover layout,
    signs.
  - `rng_waves = hash(seed × 5 + 2)`: line-ups, mutators, boss order, spawn
    choices.
  - `rng_upgrades = hash(seed × 7 + 3)`: augment offers.
- The music playlist order also comes from the seed.
- **The same seed and the same play give the same run.** Keep cosmetic
  randomness out of the gameplay streams.
- Planned: a daily seed. (Mentioned early; not confirmed. **OPEN**.)

---

## 8. The map: Shin-Kagura Rooftop (the one map for now)

- **Setting:** the neon rooftops of **Shin-Kagura** ("New Kagura"; kagura is
  the sacred Shinto dance), a cyberpunk Japanese megacity under a striped
  synthwave sun.
- **Arena:**
  - A 64×64 m rooftop (`half = 32`). Player spawn (0, 0.1, 24). Boss spawn
    (0, 0, −22).
  - A grid floor (emissive grid lines), a chrome perimeter with neon tops,
    and invisible walls.
  - **Torii shrine:** a 12×12 platform 2.4 m high, with ramps.
  - **Catwalk decks** on legs at x = ±24.5 (deck height 3.2 m). Enemies path
    under and around them.
  - **4 jump pads.**
  - **Seeded cover:** 4–6 neon-edged crates from 11 slots (one stacked), plus
    one of 3 obelisk layouts.
- **Backdrop:**
  - Buildings with neon roof edges, seeded signs and ads, a sky hologram, and
    a skyline MultiMesh with a gap to the north for the sun.
  - Neon palms.
  - A synthwave sky shader: palette gradient, a striped sun (seeded azimuth),
    ridge mountains with a rim light, twinkling stars, and a moon.
- **18 spawn points.** Enemies drop in from above with spawn beams.
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
    (seeded).

---

## 9. Presentation

### 9.1 World look: retro PS1/PS2
- **PSX lit shader:**
  - Vertex snapping (grid = viewport size × 0.6 / snap).
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
  - colour levels 48 + Bayer 4×4 dither 0.6; saturation 1.22; contrast 1.08
  - vignette 0.5; scanlines 0.07; edge chromatic aberration 1.2
  - red damage pulse at the edges; white flash; desaturate on death
  - **impact frames** (§9.8)
  - **combo heat:** extra aberration and saturation, and accent-coloured dots
    creeping in from the edges as the combo climbs:
    `heat = clamp((combo − 4)/40, 0, 1)`
- **Textures:** procedural, small, nearest-filtered. Floor, panels, concrete,
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
- **Shotgun "RAIJIN-12":** final look **OPEN**. The current model is a
  placeholder for the shotgun-taser idea.
- **3D models:** everything is built in code from primitive meshes for now.
  **Do not create models.**
  - Later, the developer may make **low-detail** Blender models (low poly,
    small textures; the game is low-res by design) if they clearly improve
    on the code-built ones.
  - Pipeline: glTF (.glb) → Godot → apply the existing PSX materials. Keep
    the code-built versions as fallbacks until each model is approved.

### 9.7 UI: cyberpunk, rendered pixel-retro
**Our own cyberpunk visual language, not Persona 5's.**
- **Faces** (all SIL OFL, bundled):
  - **Orbitron 900:** display text and big numbers (×1.25 size boost).
  - **Chakra Petch 600/700:** labels (×1.25).
  - **Share Tech Mono:** data, seeds, tables and rolling numbers (×1.5);
    monospaced digits stop count-ups from jittering.
  - **Michroma:** the big slow cards (glyph spacing +2).
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
- **HUD layout** (480×270, 8 px margins, each cluster on a tech panel with
  brackets):
  - **Top-left:** `WAVE 04` (Orbitron), `HOSTILES n` (mono), mutator name
    and multiplier. The seed is not on the live HUD (it was clutter); it is
    on the pause screen, the title and the results.
  - **Top-centre:** `HI 0000000` (mono, neon), which reads "NEW HI-SCORE"
    (steady, no blinking) once passed.
  - **Top-right:** score (mono, 7 digits) that rolls up, bumps (×1.2 at most)
    and turns gold on big gains. Below it, the combo `x12 COMBO` in dark
    letters on an accent plate that pops each kill (growing down and left,
    never into the score) and heats from yellow to pink to rainbow at ≥50,
    with the combo timer bar.
  - **Bottom-left:** HP number + HP bar (red, with a white "ghost" trail that
    drains slowly; pulses softly below 30%, the number never flashes) and dash pips.
  - **Bottom-centre:** XP bar and `LV n` (run level).
  - **Bottom-right:** **cell icons** (little power cells: body, terminal nub,
    highlight; newly charged cells flash and pop) and the "CELLS" label.
  - **Centre:** crosshair (dot + ticks) with **readiness arcs**: katana cyan
    on the left, shotgun on the right, empty when out of cells. Hit ticks on
    hit.
  - **Popups:** kill tags on dark plates to the right of the crosshair,
    newest on top (max 4), 1.4 s. The stack slides rather than jumps, and a
    repeat of the newest tag counts up ("DEFLECT! x3") instead of stacking.
    Out of cells shows a steady "NO CHARGE" plate to the left of the
    crosshair.
  - **Glory kill prompt:** 16 px under the crosshair, ending 8 px right of
    it so it clears the kill tags, while a staggered enemy is in reach
    (§3.4): a gold key cap with the bound key ("F") and "GLORY KILL" (or
    "DEATHBLOW" on a boss) on a dark plate. Pops in over
    0.1 s, then holds still; only the key cap's glow pulses. Fades in 0.08 s
    when the target is lost, and is gone during the finisher.
  - **Boss bar:** top centre under the HI score, 240 px, "NAME – EPITHET",
    on a dark plate.
  - **Hints:** bottom centre on a dark plate, above the run level, 4.5 s,
    each shown once.
  - **Messages:** a fixed spot under the boss bar (e.g. "<NAME> IS
    ENRAGED").
- **Title screen:**
  - The **KATANA / SHOTGUN** logo: KATANA flies in from the left and SHOTGUN
    from the right (0.3 s), on a tech panel. Then a **neon blade cuts the
    "/"** between them (0.32–0.39 s), with a swing and slice sound, shake,
    data streaks and a shard burst. The slash occasionally glints. Glitch
    bursts.
  - Subtitle "ARCADE HORDE SHOOTER – HOW FAR CAN YOU GET?".
  - A controls column and a HI-SCORES table (top 5).
  - "MAP · PALETTE · SEED" line and a softly pulsing "CLICK TO START".
  - The title music plays while the camera drifts.
- **Pause:** dim, "PAUSED", "CLICK TO RESUME", sensitivity readout, and a
  hint if the mouse fails to lock. Music ducks to −20 dB.
- **Level-up:**
  - Dim the screen, "LEVEL UP" stamps in, three **augment cards** (138×180
    tech panels, tall enough for a two-line name and a five-line description
    at a readable size; a tag ribbon in the tag colour with the [1]/[2]/[3]
    key beside it; then name, rank pips and description, each placed under
    the one above so nothing overlaps).
  - **Animation:** cards deal in from 190 px below with ±0.4 rad spin
    (ease-out-back, staggered 0.11 s, with a "deal" sound each), then sway.
    Hovering lifts and scales the card ×1.06 and tilts it toward the cursor.
    Picking punches the card, the others drop and fade, a chime plays, and
    the pick applies after 0.34 s.
  - Virtual cursor (mouse captured). Music ducks to −16 dB.
- **Results (death) screen:** §9.8 "Death".

### 9.8 Game-feel moments ("juice") and their timings
Everything runs in **real time** (unaffected by slow motion and hitstop).
**Every moment must obey §9.9.**

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
  - 0.00 s: a tech panel (74% of the width, brackets, scanlines) snaps open
    in 0.14 s.
  - "WAVE 04" decodes in (Orbitron, with tag "> SECTOR SHIN-KAGURA //
    HOSTILES INBOUND", or "> WARNING // HIGH-VALUE TARGET" on boss waves).
  - From 0.32 s the mutator types itself out at 55 chars/s on two lines
    inside the panel ("NAME // SCORE xN", then the description; clean
    letters, type ticks, no blinking cursor). The panel sits below the top
    HUD clusters and grows to fit.
  - Countdown **3 / 2 / 1** at 1.20 / 1.75 / 2.30 s: bracketed glitch stamps
    below the panel (each replaces the last), pitched count sound 1.0 /
    1.12 / 1.26.
  - **FIGHT** at 2.85 s, below the panel (40 px, brackets, tag "> ENGAGE",
    impact frame, data streaks, shard burst, "go" sound). The intro is then
    "ready" and spawning begins. The panel fades from 2.85 to 3.1 s.
  - Boss waves skip FIGHT; the boss intro card appears instead.
  - A riser sound under normal intros; an alarm under boss intros.
- **Combo milestones:**
  - ×10: a glitch stamp "X10 COMBO" (tag "> CHAIN SYNC") above the
    crosshair.
  - ×20 and up: the **holographic cut-in** instead of a stamp.
  - While the boss name card is up, milestones play their sound only (the
    HUD combo counter still shows the number), so the card is never covered.
- **Holographic cut-in** (1.0 s, long enough to read its text):
  - A full-width comm-feed strip (70 px, chamfered, cyan top edge and accent
    bottom edge, hazard ticks) snaps in from the side in 0.08 s, holds still,
    and snaps out in 0.09 s.
  - A **codec-style portrait box** (78 px) with the **protagonist's visored
    mask** as a neon wireframe hologram: helmet, cheek plates, vents, a hot
    accent visor with two sharp white eyes. The hex grid, scanlines and
    sweeping scan bar stay inside the portrait box.
  - Large glitch text beside it ("X20 COMBO", "DEATHBLOW!", "NEW HI-SCORE")
    on plain dark glass. (The old "LINK//KAGE-07" and "SYNC n%" data lines
    were dropped: they changed every frame and crowded the text.)
  - RGB-split ghosts on entry and exit only, a "cutin" whoosh-shing sound
    and data streaks.
  - Alternates sides. A centre stamp replaces it, and it replaces a centre
    stamp, so the two never show at once.
- **End-of-wave tally** (Balatro-style, on a tech panel 260 px wide, so it
  clears the HUD corner panels; no scanlines behind the numbers; rows
  15 px apart):
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
    - Alert-red tint (always red, whatever the palette), a hex grid,
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
    HUD:
    - The stats appear **line by line** every 0.09 s with type ticks: wave
      reached, bosses, kills, glory kills, headshot kills, deflects, best
      combo, level, time, seed.
    - The **score counts up** from 0 over 1.2 s (smoothstep, ticks every
      0.05 s rising in pitch), then slams (cash sound, shake 8, burst, bump).
    - Then either initials entry (with the highscore sound and two
      fireworks) or the HI-SCORES table.
  - The title music returns at −14 dB. Input is accepted after 2.4 s. The
    world desaturates and keeps running in slow motion (×0.35).
- **Hi-score:** passing the best score mid-run: one message, a "NEW
  HI-SCORE" cut-in, with the highscore sound and fireworks at the sides.
- **Other:**
  - Popups punch in at ×1.4 → 1 in 0.1 s with a brief bright flash, then
    hold still.
  - Cells flash when charged. Glory kills show cinematic bars (black, neon
    edges, scanlines, 26 px, in 0.08 s).
  - Dash adds data streaks. Executions flash white at 0.4 alpha. Damage
    shakes the HUD in proportion.
  - DEATHBLOW stamp on bosses.

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
- Smallest sizes at 480×270, chosen by rendering every face at every size:
  Orbitron 13 px (with +1 px glyph spacing everywhere, or neighbouring
  letters merge: "LI" read as "U"), Share Tech Mono 14 px, Chakra Petch 12 px
  (13 px for anything that matters), Michroma 12 px. Smaller sizes break the
  letter shapes (0 reads as A, O as D) and are not used for anything the
  player reads.
- Glitch text (`GlitchText`): decode capped at 0.1 s; digits and punctuation
  never scramble; no glitch bursts while held, only `glitch_out()` on the way
  out; RGB split 1 px at rest; a dark outline under every glyph.
- HUD clusters sit on darker glass (0.78) with no scanlines; layout is
  computed from the real text sizes, so nothing overlaps.
- Nothing blinks: warnings, prompts and NEW HI-SCORE are steady or pulse
  softly; low HP pulses the bar, never the number.
- Moving text holds still once it lands: no drift on cut-ins, no wobble on
  the LEVEL UP title, no jitter on the tally total.
- `--juicetest` also shows the boss name card, kill tags, NO CHARGE, a hint
  and an ENRAGED message, for paused-frame checks.

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
- Style: **fast-paced, futuristic, energetic synthwave/retrowave** that
  matches the game's speed (owner, 2026-10-18): outrun tempos (about 140 to
  155 bpm in combat, faster for bosses), driving kicks and 16th-note basses,
  **glitchy and distorted, with less synth** (owner, 2026-10-18): the tempo
  stays, but the lead instruments are distorted ones (palm-muted guitar
  chugs, a screaming guitar lead, reese and growling basses, glitch
  percussion and stabs) rather than clean synth pads and arps, and phrase
  ends are cut up with stutters, tape stops, reverses, gates and bitcrush
  bursts. Distinct boss themes; a
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
    basses in 16ths (octave, pulse or gallop) played by a reese or an FM
    growl. Doubled, panned, palm-muted guitar chugs follow the bass rhythm;
    the melody is a distorted guitar lead or a screech; glitch blips replace
    the arps and add off-beat percussion; pads only in intros, breaks and
    builds. Every second bar end (and some off-beats in drops) gets a
    seeded glitch.
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
  empty (fizzle), zap (arc on a body), swing0–2, slice, deflect, headshot
  (ding), wave_blade.
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
  in-run augment level) clearly. Example: "PLAYER LV 23" vs "RUN LV 7".

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
    title or pause screen (1 and 2). Palettes, maps, mutators and boss variants can
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
    states** (all three streams).
  - On launch, offer **CONTINUE RUN**. Delete the snapshot when the run ends,
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
- **Enemies:** Ashigaru (grunts), Teppo (gunners; the matchlock corps),
  Kanabo (brutes; after the oni's iron club).
- **Boss rewards** (§11.2, `scripts/rewards.gd`): KAGEROU EDGE (kagero, the
  heat haze), KITSUNEBI COIL (kitsunebi, fox-fire), KANAYAGO EDGE
  (Kanayago-kami, the deity of ironworking), AKAGANE COIL (akagane,
  copper), ONIBI EDGE (onibi, oni-fire ghost lights), RAIKO COIL (Minamoto
  no Raiko, who slew Shuten-doji).
- **Mutators and augments:** see §6.3 and §3.8.

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
    - Move hot loops (gore, mass AI) to typed GDScript, C# or GDExtension if
      profiling says so.
  - **Quality presets** (Low/Medium/High) cut effect counts and render scale,
    **never the art style**.
  - **Effect caps per preset** (`scripts/quality.gd`; pools are built at the
    High size, the oldest effect is recycled when a cap is reached):

    | Cap | Low | Medium | High |
    |---|---|---|---|
    | Blood/spark droplets | 700 | 1200 | 1800 |
    | Floor decals | 220 | 360 | 520 |
    | Gibs and chunks | 50 | 80 | 110 |
    | Blood per burst, chunks per kill | 50% | 75% | 100% |
    | Damage numbers | 18 | 28 | 40 |
    | Lightning arcs | 36 | 60 | 96 |
    | Blood mist | 16 | 28 | 40 |
    | Smoke puffs | 20 | 36 | 60 |
    | Impact flashes | 16 | 28 | 48 |

    Fixed at every preset: spawn beams 16, slash trails 8, explosion flashes
    12, explosion lights 4, kill tags 4, screen blood 10. Health orbs are
    never capped (they heal); their pool grows. High's caps sit above what a
    fight produces, so High looks like the prototype. Boss-only effects
    (shockwave rings, missile markers, dash telegraph lines) are still built
    per use: they fire a few times a minute at most.
  - **Profiling:** test on real low-end hardware throughout. Set a frame-time
    budget per system. Add a debug perf overlay (fps, frame time, draw calls).

---

## 15. Architecture

### 15.1 Game flow
`title` → `playing` ⇄ `paused` / `levelup` → `dead` → results → (R: same
seed | click: new seed).
- **Title:** shows the map built from the next run's seed, with the camera
  drifting and the title music playing.
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
| `Juice` | Stamps, shake, sparks, fireworks, wave intro, tally, souls card, cut-in, data streaks, kill bursts, FINISH, cinematic bars, `later()` real-time scheduler |
| UI pieces | `Shard` (tech panel), `GlitchText`, `CutIn`, `SpeedLines` (data streaks), `ShardBurst` (kill burst) |
| `PostFx` | Post-process material, hurt/flash/impact/heat |
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
- **Profile and save system** (§11). **Rewards and unlock menu** (§11.2).

---

## 16. Debug, testing and tooling (keep these)
- **Command-line flags** (after `--`):
  - `--autoplay`: a bot plays (aims, strafes, slashes, glory-kills staggered
    enemies with the finisher key, shotguns, auto-picks augments) and logs
    one stats line every 2 s.
  - `--god`: no damage.
  - `--wave=N`, `--seed=XXXX-XXXX`, `--boss=ninja|mech|oni`, `--restart`
    (auto-restart after death), `--verbose-ai`.
  - `--showcase` (+`--bosses`): a frozen model line-up and gore demo.
  - `--juicetest` (+`--juicestart=T`, `--verbose-juice`): plays every
    presentation moment back to back.
  - `--palettetour` (+`--palette=NAME|0-4`): four fixed views of the arena,
    1.5 s each, then quits; `--palette=` also forces the palette in a normal
    run (debug only; the seed still draws its palette number).
  - `--settings=audio|video|controls|comfort`: opens the settings screen on
    the title at that tab.
  - `--record-mix=DIR`: records each audio bus to `DIR/<bus>.wav` on quit, to
    measure the mix (use with `--write-movie` so audio follows game time).
  - `--quality=low|medium|high`: the effect-count preset (§14).
  - `--perf`: shows the perf overlay, logs draw calls, live nodes and node
    churn every 2 s, and prints a summary at exit.
- **Perf overlay:** F3 in any build (fps, frame time, draw calls, nodes,
  new nodes per second, quality preset).
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
- The full **boss reward** list (the drop rule is decided: every kill
  unlocks that boss's next reward, §11.2).
- The **final shotgun look** (the katana reference is decided: Thermal
  Katana style).
- The **full difficulty curve** past the early waves (tune by playtesting;
  waves 1–3 stay easy).
- **Controller support** (not requested yet).
- A daily seed and online leaderboard (mentioned early, not confirmed).
- A **Steam** release and cloud saves.
- Whether in-game text gets macrons back (needs a fallback font).
- Repo visibility (public, or private plus a public releases repo), the
  publisher name, code signing, Mac builds (PART S).

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
