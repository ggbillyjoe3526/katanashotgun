# Audio: how to drop in professional sound and music

All the audio in the game today is generated placeholder. This folder is set
up so a sound designer or composer can replace any of it without touching
code. Spec §10 has the rules; this page is the how-to.

## Where things live

| What | Where |
|---|---|
| Sound effect files | `assets/audio/<name>.wav` (or `.ogg`) |
| One settings file per sound effect ("cue") | `assets/audio/cues/<name>.tres` |
| Rain beds (looping ambience) | `assets/audio/rain.ogg`, `assets/audio/rain_heavy.ogg` |
| Music files | `assets/music/<name>.ogg` |
| One settings file per piece of music ("track") | `assets/music/tracks/<name>.tres` |
| Mixer (buses and their levels) | `default_bus_layout.tres`, shown in Godot's **Audio** tab at the bottom of the editor |

## Replace a sound effect

**Simplest:** save the new file over the old one with the same name, for
example `assets/audio/shotgun.wav`. Godot re-imports it when you switch back
to the editor. Done.

**With variants** (a few takes, so repeats never sound identical):
1. Put the files next to the original: `shotgun_01.wav`, `shotgun_02.wav`, ...
2. In Godot's FileSystem panel open `assets/audio/cues/shotgun.tres`.
3. In the Inspector, open **Streams**, add elements and drag each file in.
   One is picked per shot, never the same one twice in a row.

Each cue file also sets:
- **Bus**: SFX (combat), UI (menus, score tally, combo ticks) or Ambience.
- **Volume Db**: a trim on top of what the game asks for. Balance sounds here.
- **Vary Pitch**: the game adds a small random pitch change to most hits.
  Turn it off for tuned stingers.
- **Throttle Ms**: repeats closer together than this are skipped.
- **Max Voices**: how many copies may ring at once; a new one replaces the
  oldest copy.
- **Priority**: when all 20 voices are busy, a sound can only take over a
  voice of the same or lower priority. Player weapons, enemy telegraphs and
  big moments are CRITICAL, so a crowd of gore never cuts them off.
- **Unit Size / Max Distance**: for sounds placed in the world.
- **Music Duck Db**: the few biggest hits pull the music down for a moment.

## Add a new sound effect

1. Add the file to `assets/audio/` (for example `climb.wav`).
2. It already plays with default settings when the game calls
   `Sfx.play("climb")` (or `Sfx.play_at("climb", position)`).
3. To give it its own settings, create its cue file:
   `godot --headless --path . --import` then
   `godot --headless --path . -s res://tools/make_audio_data.gd`.
   The tool only creates missing files; it never overwrites your tuning.

## Replace or add music

**Replace:** save over `assets/music/<name>.ogg` with the same name.

**Add a track:** add the `.ogg`, run the tool above, then open its new file in
`assets/music/tracks/` and set:
- **Role**: `combat` (joins the shuffled playlist), `boss` (set **Boss
  Kind**: `ninja`, `mech` or `oni`), or `title`.
- **Loop** and **Loop Offset**: boss and title tracks loop; the loop jumps
  back to Loop Offset seconds, so an intro plays once. The loop end is the
  end of the file. Combat tracks don't loop; the playlist moves on and
  crossfades shortly before the end.
- **Volume Db**: a trim so tracks from different sources sit level.

**Stems / intensity layers:** put the stems in the track's **Stems** list.
Stem 0 is the base and always plays. Each further stem is a layer that fades
in as the fight heats up (a growing combo, an enraged boss) and drops out
slowly when it calms down. **Stem Intensity** sets, per stem, the intensity
(0 to 1) where that layer is fully in; 0.5 means "halfway up", 1.0 means
"only at full heat". All stems must be the same length and start together.

## Delivery specs

- **Sound effects:** WAV, 48 kHz, 16 or 24 bit. Mono for anything heard in
  the world; stereo is fine for UI and stingers. Peak at -1 dBFS, no silence
  at the start. Deliver every sound at full level and balance with the cue's
  Volume Db, not by rendering it quieter.
- **Music:** Ogg Vorbis, quality 6 or higher, 48 kHz stereo. Master around
  -14 LUFS integrated, true peak -1 dBTP or lower. Keep uncompressed masters
  outside the repository.
- **Ambience beds:** seamless loops, gentle, band-limited (nothing hissy above
  about 5 kHz), and quiet in themselves: they sit far behind the music.
- **Names:** lowercase, `snake_case`, no spaces or slashes.
- **Licences:** every sound or track made by someone else gets a line in
  `ASSETS.md` with its source and licence (spec rules: CC0, CC-BY or SIL OFL,
  or commissioned work the owner holds the rights to).

## The mix

Music is the loudest layer, then combat sound, then menu sounds, with
ambience far back (spec §10.1 has the levels and how they were measured).
The bus levels in `default_bus_layout.tres` are the mix; the volume sliders
in Settings add on top of them. To check a new sound in context, record a
run per bus and measure it:

```
godot --path . --write-movie out/run.avi --fixed-fps 30 --quit-after 1800 -- --autoplay --god --record-mix=out
```

This writes `out/master.wav`, `out/music.wav`, `out/sfx.wav`,
`out/ambience.wav` and `out/ui.wav` (before each bus's own level).
