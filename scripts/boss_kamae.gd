class_name BossKamae
extends RefCounted
## A boss's KAMAE (its fighting stance, "posture"; spec §5.5). Bosses are
## never staggered by poise. Pressure fills this bar instead: katana hits,
## shotgun blasts, deflected bolts and glory kills near the boss. When it is
## full the stance breaks, the boss reels, and F lands the ONIKIRI blow.
## Backing off lets it drain again, slowly. Pure data so it can be tested.

## Seconds with no pressure before the bar starts to drain.
const GRACE := 2.5
## Share of the full bar lost per second while draining.
const DRAIN := 0.07
## A break lasts the boss's stagger time plus this many seconds.
const BREAK_EXTRA := 1.5
## A glory kill on an add this close to the boss fills this share of its bar.
const GLORY_RANGE := 15.0
const GLORY_SHARE := 0.12
## The ONIKIRI blow takes this share of the boss's max HP, and kills it at or
## under that much.
const BLOW_SHARE := 0.2
## Kamae per point of poise damage, by source. The katana is the pressure
## tool; a shotgun blast counts for less than its damage; one
## deflected bolt counts for a lot, so a whole returned fan is a big swing.
const SOURCE_MULT := {
	"katana": 1.6,
	"shotgun": 0.6,
	"deflect": 0.4,
	"wave": 1.0,
	"dashcut": 1.0,
}

var max_value := 900.0
var value := 0.0
var broken := false
var idle_t := 0.0 # seconds since the last pressure


func _init(maximum := 900.0) -> void:
	max_value = maxf(1.0, maximum)


func ratio() -> float:
	return clampf(value / max_value, 0.0, 1.0)


## Kamae a hit from `source` with `poise` poise damage is worth.
static func gain_for(source: String, poise: float) -> float:
	return maxf(0.0, poise) * float(SOURCE_MULT.get(source, 0.0))


## Adds pressure. Returns true when this fills the bar and breaks the stance.
func add(amount: float) -> bool:
	if broken or amount <= 0.0:
		return false
	value = minf(max_value, value + amount)
	idle_t = 0.0
	if value >= max_value:
		broken = true
		return true
	return false


## Drains the bar once the player has backed off. Frozen while broken.
func update(delta: float) -> void:
	if broken:
		return
	var draining := minf(delta, maxf(0.0, idle_t + delta - GRACE))
	idle_t += delta
	value = maxf(0.0, value - max_value * DRAIN * draining)


## The boss has recovered its stance: an empty bar, ready to fill again.
func recover() -> void:
	broken = false
	value = 0.0
	idle_t = 0.0
