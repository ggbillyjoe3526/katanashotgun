# Waves and Mutators

## Waves

A run is an endless series of waves on the rooftop. Each wave:

1. **Intro:** the wave number (and its mutator, if any), then 3, 2, 1, FIGHT.
2. **Fight:** enemies drop in from above in groups of 1 to 3 until the wave's
   whole line-up has arrived and been killed.
3. **Tally:** the wave's score pays out ([Scoring](Scoring-and-High-Scores)).
   You get **+2 cells**.
4. Then the next wave. Every third wave is a [boss](Bosses).

### How waves grow

| | Wave 1 | Wave 2 | Wave 4 | Wave 5 | Wave 8 | Wave 10 |
| --- | --- | --- | --- | --- | --- | --- |
| Grunts | 7 | 9 | 13 | 15 | 21 | 25 |
| Gunners | none | 1 | 3 | 4 | 7 | 9 |
| Brutes | none | none | 1 | 1 | 2 | 3 |
| Enemies alive at once (most) | 10 | 12 | 16 | 18 | 22 | 22 |

Boss waves (3, 6, 9...) send the boss and reinforcements instead.

- Grunts: 5 + 2 per wave. Gunners: from wave 2, one more each wave, up to 9.
  Brutes: from wave 4, one more every 3 waves.
- Gunners fire a 3-bolt fan from wave 6.
- Mutators can change these numbers (more grunts, double gunners, extra brutes).
- Enemy health rises a little every wave and faster after wave 9 (see
  [Enemies](Enemies#they-get-tougher)).
- **Waves 1 to 3 are meant to be easy.** It's after that the climb starts.
- Your [seed](Seeds) decides the order enemies arrive in and where they drop.

## Mutators

From **wave 2**, each regular wave has a 65% chance to roll a **mutator**: a
twist that makes the wave harder (or stranger) and multiplies its tally. The
mutator shows under the wave label with its multiplier.

- Boss waves never have one.
- The same mutator never comes up twice in a row.
- The harshest ones wait until wave 3 or 4.
- Your seed decides which mutators come up.

| Mutator | What happens | Score | From wave |
| --- | --- | --- | --- |
| **OKURI-INU HUNT** | Enemies move 25% faster | ×1.5 | 2 |
| **MURAMASA'S CURSE** | You deal and take +50% damage | ×1.3 | 2 |
| **AKATSUKI** | Enemies have 40% more HP, but glory kills heal double | ×1.4 | 2 |
| **YOMI BLACKOUT** | No passive cell recharge: cells come only from kills, deflects and glory kills | ×1.3 | 2 |
| **HYAKKI YAKO** | 60% more grunts, each with 30% less HP | ×1.2 | 2 |
| **TEPPO VOLLEY** | Double the gunners | ×1.3 | 2 |
| **KANABO VANGUARD** | Two extra brutes | ×1.4 | 2 |
| **MATSURI RUSH** | The combo timer runs twice as fast (2 s instead of 4 s) | ×1.4 | 2 |
| **SENRYO BOUNTY** | Headshot kills and glory kills score double; every other kill scores half | ×1.2 | 2 |
| **RAIJIN'S STORM** | A thunderstorm. Every 3.5 to 6 s lightning strikes near you: a red ring warns for 1.2 s, then 16 damage inside it (enemies in it take 32). Leave the rings | ×1.4 | 3 |
| **ONRYO'S GRUDGE** | Every enemy that dies leaves a red ring that bursts 1.1 s later for 14 damage (enemies take 28, so they chain) | ×1.3 | 3 |
| **KANASHIBARI** | Dashes take twice as long to recharge | ×1.3 | 3 |
| **KABUTO PLATE** | Grunts and gunners wear armour: the katana does 40% until you stagger them. Blast, then slash | ×1.3 | 4 |
| **HANNYA'S WRATH** | Wounded enemies (below half HP) enrage: 40% faster, 30% harder hitting, red eyes | ×1.3 | 4 |
| **UMIBOZU SWELL** | The whole wave comes at once: up to 60% more enemies alive, arriving twice as fast | ×1.4 | 4 |

When a wave is cleared, any red rings still waiting are defused, so nothing
hits you during the tally.

Mutators are named after yokai and legends: the okuri-inu wolf that follows
travellers at night, the cursed swords of Muramasa, the hyakki yako (night
parade of a hundred demons), the onryo vengeful ghost, the umibozu sea giant
and the hannya mask of jealous rage.
