# The player wiki

This folder is the source of the game's GitHub wiki
(<https://github.com/ggbillyjoe3526/katanashotgun/wiki>). Each `.md` file is
one page, named like `Level-Up-Cards.md` (dashes become spaces in the page
title). `Home.md` is the front page, `_Sidebar.md` the menu on every page and
`_Footer.md` the line under it. This README is never published.

**Publishing:** `.github/workflows/wiki.yml` pushes the pages to the wiki on
every merge to `main`. Edits made in the wiki's web editor are overwritten, so
always edit here.

**Patch Notes is generated**, never written by hand: `tools/wiki.py build`
writes `Patch-Notes.md` from the `changelog.d/` notes waiting for the next
release, then every version in `CHANGELOG.md`.

## Keeping it current

Any change a player would notice updates the page that describes it, in the
same pull request: a card, mutator, boss, enemy, control, setting, score
rule, reward or map. New content gets a mention on its page; anything still
in an open pull request is written as **Coming soon**, never as live. When a
plan lands or changes, update `Roadmap.md` (and move a "Coming soon" note to
the live description).

- Write for players: second person, plain words, numbers from the code (the
  spec's tables are a good source). Game names in the game's spelling
  (`RAIJIN'S FORK`, `Kurokage`); no macrons.
- Link pages as `[Bosses](Bosses)` or `[Plunge](Glory-Kills#plunge)` (the
  anchor is the heading in lowercase, spaces as dashes, punctuation dropped).
- A new page gets a line in `_Sidebar.md`.
- Pictures go in `images/` and are shown with `![what it shows](images/name.png)`.
  Keep them small (a few hundred KB): they are published with every page.

## Checks

`python3 tools/wiki.py check` (CI runs it on every pull request) fails when:

- a link points to a page, heading or picture that doesn't exist,
- a page is missing from the sidebar,
- an in-game name (every card, build, mutator, reward, palette, boss name,
  title and felled line, and map) isn't mentioned on any page. The names come
  from the scripts listed in `NAME_SOURCES` in `tools/wiki.py`; add a script
  there when new content gets its own file.

On a pull request it also warns when a `changelog.d/` note is added but no
wiki page changed. `python3 tools/wiki.py build build/wiki` writes the pages
as they will be published, to preview locally.
