# Settings

Open **Settings** with **Tab** or the **SETTINGS** button on the title or
pause screen. Everything works with the mouse: click a tab, click the left or
right half of an option to change it, and drag or scroll a slider. Changes
apply at once and are remembered next time. **DEFAULTS** resets the tab you're
on (click it twice: the first click only asks, so a stray click never wipes
your key bindings); **BACK** (or Esc) closes the screen.

## Audio

Volume sliders for each part of the mix: **Master**, **Music**, **Sound
effects**, **Ambience** (rain and the city) and **Menus/HUD**.

## Video

| Setting | Choices | Default |
| --- | --- | --- |
| Window mode | Windowed, Full screen, Exclusive full screen | Full screen at your screen's resolution |
| VSync | On (no tearing) or Off (less input lag) | Off |
| Frame cap | Unlimited, or 60, 75, 120, 144, 165, 240, 360 fps | Unlimited |
| Graphics | WEAK, MEDIOCRE, INSANE (see [Graphics presets](#graphics-presets)) | MEDIOCRE |
| Retro look | LIGHT or OFF (see [Retro look](#retro-look)) | LIGHT |
| Render scale | 50% to 100% of the 3D view's sharpness. Lower runs faster | 100% (WEAK uses 75%) |
| Field of view | 70 to 110 | 88 |

Text uses a true pixel font drawn at 480 × 270, so its letters stay crisp
and even at any size (8 × 8 blocks on 4K) whatever the Retro look. The Video
tab names the screen it detected. **F11** switches between full screen and a
window.

**If the game runs slowly:** set Graphics to WEAK first, then lower the
Render scale. Press **F3** in a game to see your frame rate.

### Retro look

How strong the old-console (PS1/PS2) look is. Colours, glow, lighting and the
pixel-font HUD are the same on both.

![The same spot on LIGHT and OFF, at real 4K pixels](images/retro-look.jpg)

| | LIGHT (default) | OFF |
| --- | --- | --- |
| 3D picture | Drawn at about 540 lines (4 × 4 blocks on 4K, 2 × 2 on 1080p) | Your screen's full resolution |
| Wobbling shapes | Gentle | None |
| Textures | Smooth, a trace of warp | Smooth |
| Colour banding and dither | Faint | None |
| Scanlines and colour fringe | Faint | None |

There used to be a third, much chunkier FULL look. It was removed; if you had
it picked, the game now starts on LIGHT.

Pixels always stay square and sharp: the picture is scaled up in whole steps,
never smoothed.

### Graphics presets

Every preset keeps the same PS1/PS2 look (set its strength with
[Retro look](#retro-look)). The higher ones add light, not realism.

![The same spot on WEAK, MEDIOCRE and INSANE](images/graphics-presets.jpg)

Only things that would really reflect do: rain puddles and skylight glass.
Floors, walls and metal stay matte on every preset.

| | WEAK | MEDIOCRE | INSANE |
| --- | --- | --- | --- |
| For | Old laptops and integrated graphics | Most PCs | A strong graphics card |
| Light | The plain look | The plain look | Light that bounces (neon colours the floor), soft shadows from the moon, shading in every corner |
| Glow and air | The plain glow, no floating dust, steam or light beams | Wider neon glow, a soft haze around every lamp | Real fog that the lamps light up |
| Puddles and glass | A dark sheen, no reflections | Reflect the neon and the city | Reflect it sharper |
| Blood and chunks | Fewer | More | Even more per kill |
| Flying cars in the city | Fewer | All of them | All of them |
| Edges | Jagged | Smoother | Smoothest |

![A glory kill moment on WEAK, MEDIOCRE and INSANE](images/graphics-presets-fight.jpg)

**INSANE restarts the game.** It runs on a different part of Godot (the
Forward+ renderer, using Vulkan or Direct3D 12). When you pick INSANE, or
leave it, the **QUIT GAME** button at the bottom left of Settings turns into
**RESTART GAME**: click it twice and the game closes and opens again with the
new look. If you don't restart, the change happens the next time you start
the game. If your graphics card can't run INSANE's renderer, the game starts
on the basic one by itself and Settings tells you so.

## Controls

- **Mouse sensitivity** (the `[` and `]` keys change it in game too, and
  show the new value at the top of the screen for a moment).
- **Aim assist:** ON (default) or OFF. A slash pulls you onto an enemy just
  out of reach, and a shotgun blast that only just misses bends onto the
  body. See [Weapons](Weapons#aim-assist).
- **Key bindings:** two keys or mouse buttons for each of Katana, Shotgun,
  Glory kill (F), Jump, Dash and the four move directions.
  - Click a slot, then press the new key (or click the slot with the mouse
    button you want).
  - Right-click a slot to clear it.
  - Taking a key another action uses swaps the two.
  - Esc and F11 can't be rebound.

## Comfort

- **Screen shake:** how much the camera and HUD shake. It also calms the
  big moments' picture cuts and rolling glitches; at 0 they stay still.
- **Flashes:** how strong the screen flashes are. Below 100%, impact frames
  stop strobing. At 0 the test-card colour bars, static and the FINISH
  negative are switched off too.
- **Crosshair size:** SMALL, NORMAL (default) or LARGE: how far the
  crosshair's four ticks reach.
- **Crosshair colour:** WHITE (default), CYAN, GREEN, YELLOW or PINK. The
  health and cell frame around it keeps its own colours.

## Quit game

**QUIT GAME** on the title, pause and Settings screens closes the game after
saving. Click it twice: the first click only asks you to confirm, so a stray
click never quits.

Settings are saved inside your profile, so they share its backup
([Saving and Continuing](Saving-and-Continuing)).
