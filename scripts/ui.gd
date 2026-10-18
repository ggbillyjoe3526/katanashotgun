class_name Ui
## Fonts and small UI helpers. Body text, labels and numbers use Jersey 10, a
## true pixel face: it is drawn only at its own pixel size (19 px, or whole
## multiples of it), so every stem is exactly one pixel wide and the spacing
## is even. Numbers use its fixed-width digits so rolling counters hold
## still. The cyberpunk display faces stay for big text only, where they
## have enough pixels to read: a heavy wide face (Orbitron) for big words and
## numbers and a wide sci-fi face (Michroma) for the big slow cards.
## Everything is drawn the PS1/PS2 way: rasterised at the UI's low internal
## resolution (480x270) with no antialiasing, then upscaled with nearest
## filtering, so every letter is made of chunky pixels like the 3D world.

const PIX := 19 # Jersey 10's own pixel size: one font pixel per screen pixel
const PIX_CAP := 10 # its capital height at that size
const BIG_MIN := 13 # Orbitron below this size reads poorly; Jersey takes over
const CARD_MIN := 16 # same for Michroma

static var font: Font # labels and body text (Jersey 10)
static var font_bold: Font # emphasis (Jersey 10 too: a pixel face has one weight)
static var font_big: FontVariation # big display words and numbers (Orbitron 900)
static var font_mono: FontVariation # numbers and data (Jersey 10, fixed-width digits)
static var font_card: FontVariation # boss felled / flatlined cards (Michroma)


static func init() -> void:
	if font:
		return
	var jersey: FontFile = load("res://assets/fonts/jersey_10.ttf")
	_setup(jersey)
	jersey.hinting = TextServer.HINTING_NONE # the outlines already sit on the pixel grid
	# any requested size is drawn at 19 px or a whole multiple of it, so the
	# face never lands between pixels whatever size a caller asks for
	jersey.fixed_size = PIX
	jersey.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	# its own line box is 22 px tall for 10 px capitals, which leaves text
	# floating low in its box; 13 above the baseline (room for accents) and 3
	# below (descenders) keep boxes snug and wrapped lines 16 px apart. Set
	# after the properties above, which clear the cache.
	jersey.set_cache_ascent(0, PIX, 13)
	jersey.set_cache_descent(0, PIX, 3)
	font = jersey
	font_bold = jersey
	font_mono = FontVariation.new()
	font_mono.base_font = jersey
	font_mono.opentype_features = {"tnum": 1}
	# Orbitron is tightly spaced; at pixel sizes neighbouring letters merge
	# ("LI" reads as "U"), so it gets one extra pixel between glyphs
	font_big = FontVariation.new()
	font_big.base_font = _pix("orbitron_900")
	font_big.spacing_glyph = 1
	font_card = FontVariation.new()
	font_card.base_font = _pix("michroma")
	font_card.spacing_glyph = 2


static func _pix(file: String) -> FontFile:
	var f: FontFile = load("res://assets/fonts/%s.woff2" % file)
	_setup(f)
	return f


static func _setup(f: FontFile) -> void:
	f.multichannel_signed_distance_field = false
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NORMAL
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.allow_system_fallback = false
	if "oversampling" in f:
		f.set("oversampling", 1.0) # rasterise at the low internal size


## Makes fonts rasterise at the UI's internal 480x270 size instead of being
## oversampled to the window size, which keeps them pixelated.
static func pixelate_viewport(vp: Viewport) -> void:
	if "oversampling" in vp:
		vp.set("oversampling", false)
	if "oversampling_override" in vp:
		vp.set("oversampling_override", 1.0)


## The face to draw `f` with at `size`: the display faces hand small text to
## the pixel face, which stays crisp where they would blur into blobs.
static func face(f: Font, size: int) -> Font:
	init()
	if (f == font_big and size < BIG_MIN) or (f == font_card and size < CARD_MIN):
		return font_bold
	return f


## The pixel size to draw `f` at for a design size. The display faces need
## a little more than the old bitmap fonts; the pixel face snaps to its own
## size or a whole multiple of it.
static func px(f: Font, size: int) -> int:
	if f == font_big:
		return int(round(size * 1.25))
	if f == font or f == font_bold or f == font_mono:
		return PIX * maxi(1, roundi(size * 1.25 / PIX))
	return size


## The name of the first key bound to `action`, for on-screen prompts
## ("F"), so prompts stay right when the key is rebound. Shown in the
## player's keyboard layout where the platform can tell us it.
static func key_name(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k == null:
			continue
		var code := k.keycode
		if code == KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		if code == KEY_NONE:
			code = k.physical_keycode
		return OS.get_keycode_string(code).to_upper()
	return "?"


static func theme() -> Theme:
	init()
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = PIX
	return t


static func label(text: String, f: Font, size: int, color := Color.WHITE, outline := 0, outline_color := Color(0, 0, 0, 1)) -> Label:
	init()
	f = face(f, size)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px(f, size))
	l.add_theme_color_override("font_color", color)
	if f == font or f == font_mono:
		l.add_theme_constant_override("line_spacing", 2) # its line box is snug; a little air between lines
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
