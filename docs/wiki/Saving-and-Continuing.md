# Saving and Continuing

The game saves on its own. You never need to save by hand.

## What is saved

Your **profile** holds your Player Level and XP, unlocked rewards and the
looks you've picked, your top 10 high scores, your settings and lifetime
stats. It saves at the end of every run, on every unlock, when you change a
setting and when you quit.

## Quit mid-run and carry on later

- The game takes a snapshot of your run **between waves**, after each tally:
  your wave, score, cards, health, cells, dashes and the seed's position, so
  the rest of the run plays out exactly as it would have.
- Next time you start the game, the title offers **CONTINUE** from the
  start of the wave you were on. Click it to continue, or click **NEW RUN** (or
  press **N**) to start a new run instead.
- Starting a new run over a saved one still pays that run's XP into your
  Player Level, so nothing is lost.
- When you die, the snapshot is deleted. A death can't be undone by
  reloading.

## Safe saves

- Saves are written to a temporary file first and then swapped in, and each
  one keeps a **backup**. A crash or power cut mid-save never wipes your
  progress: the game loads the backup instead.
- Every save is checked when it loads. A damaged file is never deleted; it's
  set aside and the backup is used.
- Your high score is kept the moment a run ends, even if you quit before
  typing your initials.

## Where the files are

| System | Folder |
| --- | --- |
| Windows | `%APPDATA%\KatanaShotgun\` (paste it into the File Explorer address bar) |
| Linux | `~/.local/share/KatanaShotgun/` |
| macOS | `~/Library/Application Support/KatanaShotgun/` |

The files are `profile.json` and `run.json` (the suspended run), each with a
`.bak` backup. Uninstalling the game leaves them in place, so a reinstall
keeps your progress. To back up your progress, copy this folder.
