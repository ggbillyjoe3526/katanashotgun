class_name Palette
## Synthwave colour schemes (spec §9.2). Each run picks one from its seed, and
## every system (sky, sun, neon tubes, floor grid, fog, signs, windows) reads
## from it.
##
## Every palette is a MULTI-COLOUR base: six strong accent hues that maps spread
## over signs, tubes and props, so a scene never collapses into one hue. The
## big areas (sky top, fog, ambient, floor) stay dark and fairly neutral so the
## accents carry the colour. neon_a/b/c are the first three accents: the HUD
## and effects use them, and neon_c is always bright enough for text.
## `problems()` checks these rules; the unit tests run it on every palette.

const ACCENTS_MIN := 5
const ACCENT_MIN_SAT := 0.6
const ACCENT_MIN_VALUE := 0.8
const ACCENT_MIN_HUE_GAP := 25.0 # degrees between any two accents
const PURPLE_HUES := Vector2(255.0, 300.0)
const TEXT_MIN_LUMINANCE := 0.5 # neon_c is used for HUD text
const WASH_MAX_SAT := 0.75 # fog and ambient stay fairly neutral
const FOG_MAX_VALUE := 0.25
const SKY_MIN_HUE_GAP := 30.0 # sky_mid vs sky_horizon

const LIST := [
	{
		"name": "SUNSET DRIVE",
		"sky_top": Color("060b2e"), "sky_mid": Color("a3195b"), "sky_horizon": Color("ff7a2a"),
		"sun_top": Color("ffe14d"), "sun_bottom": Color("ff2a8a"),
		"fog": Color("161a30"), "ambient": Color("565c82"),
		"grid": Color("2af6ff"), "floor": Color("0c0e1e"), "mountain": Color("12163a"),
		"accents": [Color("ff2a8a"), Color("2af6ff"), Color("ffc23a"), Color("3d6bff"), Color("9dff3a"), Color("ff4a1f")],
	},
	{
		"name": "MIAMI NIGHTS",
		"sky_top": Color("050a2a"), "sky_mid": Color("1d3590"), "sky_horizon": Color("ff6ec7"),
		"sun_top": Color("fff07a"), "sun_bottom": Color("ff4f6e"),
		"fog": Color("0f1c32"), "ambient": Color("4a6688"),
		"grid": Color("3dfcd8"), "floor": Color("08101e"), "mountain": Color("0c1844"),
		"accents": [Color("ff4fb8"), Color("3dfcd8"), Color("ff9e3d"), Color("4d8bff"), Color("c6ff3d"), Color("b45cff")],
	},
	{
		"name": "ULTRAVIOLET",
		"sky_top": Color("05021a"), "sky_mid": Color("24127a"), "sky_horizon": Color("2fd0ff"),
		"sun_top": Color("e8ff6a"), "sun_bottom": Color("ff3d9e"),
		"fog": Color("12112c"), "ambient": Color("54568a"),
		"grid": Color("9dff3a"), "floor": Color("0a0a1c"), "mountain": Color("0e0c34"),
		"accents": [Color("b44dff"), Color("4df0ff"), Color("e8ff3a"), Color("ff3d9e"), Color("3dff8a"), Color("ff7a1f")],
	},
	{
		"name": "BLOOD CHROME",
		"sky_top": Color("05060c"), "sky_mid": Color("1e2a40"), "sky_horizon": Color("ff3b2b"),
		"sun_top": Color("ffd27a"), "sun_bottom": Color("ff1f4d"),
		"fog": Color("171a22"), "ambient": Color("66687a"),
		"grid": Color("ff2b4a"), "floor": Color("100c10"), "mountain": Color("140c14"),
		"accents": [Color("ff2b4a"), Color("29e7ff"), Color("ffb52b"), Color("ff3df0"), Color("3d7bff"), Color("b8ff3d")],
	},
	{
		"name": "TOXIC TOKYO",
		"sky_top": Color("020818"), "sky_mid": Color("064a50"), "sky_horizon": Color("ff3da8"),
		"sun_top": Color("f6ff7a"), "sun_bottom": Color("19ff9c"),
		"fog": Color("0b1c1e"), "ambient": Color("46666e"),
		"grid": Color("19ffc1"), "floor": Color("061012"), "mountain": Color("061a24"),
		"accents": [Color("19ffc1"), Color("ff3df2"), Color("f6ff4a"), Color("ff7a1f"), Color("2f8bff"), Color("ff3d5a")],
	},
]


## Picks the run's palette. Always draws exactly one number from `rng` so the
## rest of the map stream is the same whichever palette comes up.
## `force` (debug `--palette=`) takes a palette name or index.
static func pick(rng: RandomNumberGenerator, force := "") -> Dictionary:
	var i := rng.randi() % LIST.size()
	if force != "":
		var found := false
		for k in LIST.size():
			if force == str(k) or force.to_upper() == LIST[k].name:
				i = k
				found = true
		if not found:
			push_warning("--palette=%s matches no palette; using the seeded one" % force)
	return expand(LIST[i])


## A copy of a palette entry with neon_a/b/c filled in from its accents.
static func expand(entry: Dictionary) -> Dictionary:
	var p := entry.duplicate(true)
	p.neon_a = p.accents[0]
	p.neon_b = p.accents[1]
	p.neon_c = p.accents[2]
	return p


## Everything that breaks the multi-colour rules (spec §9.2); empty when fine.
static func problems(p: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var acc: Array = p.get("accents", [])
	if acc.size() < ACCENTS_MIN:
		out.append("only %d accents" % acc.size())
	var purple := 0
	for i in acc.size():
		var c: Color = acc[i]
		if c.s < ACCENT_MIN_SAT or c.v < ACCENT_MIN_VALUE:
			out.append("accent %d is not a strong neon" % i)
		if _is_purple(c):
			purple += 1
		for j in range(i + 1, acc.size()):
			if hue_gap(c, acc[j]) < ACCENT_MIN_HUE_GAP:
				out.append("accents %d and %d share a hue" % [i, j])
	if purple > 1:
		out.append("%d purple accents" % purple)
	if acc.size() >= 3 and luminance(acc[2]) < TEXT_MIN_LUMINANCE:
		out.append("neon_c too dark for text")
	for k in ["fog", "ambient"]:
		if Color(p[k]).s > WASH_MAX_SAT:
			out.append("%s too saturated" % k)
	if Color(p.fog).v > FOG_MAX_VALUE:
		out.append("fog too bright")
	if hue_gap(p.sky_mid, p.sky_horizon) < SKY_MIN_HUE_GAP:
		out.append("sky is one hue")
	var washed := 0
	for k in ["sky_top", "sky_mid", "fog", "ambient", "floor", "mountain"]:
		var c: Color = p[k]
		if _is_purple(c) and c.s > 0.3:
			washed += 1
	if washed > 2:
		out.append("purple base (%d large areas)" % washed)
	return out


## Shortest distance between two hues, in degrees.
static func hue_gap(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)


static func luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _is_purple(c: Color) -> bool:
	var h := c.h * 360.0
	return h >= PURPLE_HUES.x and h <= PURPLE_HUES.y
