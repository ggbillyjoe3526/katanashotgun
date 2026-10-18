class_name Ui
## Fonts and small UI helpers. The faces are cyberpunk: a heavy wide display
## face (Orbitron) for big text and numbers, a cut-corner face (Chakra Petch)
## for labels, a monospace face (Share Tech Mono) for data readouts and
## rolling numbers, and a wide sci-fi face (Michroma) for the big slow cards.
## They are drawn the PS1/PS2 way: rasterised at the UI's low internal
## resolution (480x270) with no antialiasing, then upscaled with nearest
## filtering, so every letter is made of chunky pixels like the 3D world.

static var font: Font # labels (Chakra Petch 600)
static var font_bold: Font # emphasis (Chakra Petch 700)
static var font_big: FontVariation # display + big numbers (Orbitron 900)
static var font_mono: Font # data, seeds, rolling numbers (Share Tech Mono)
static var font_card: FontVariation # boss felled / flatlined cards (Michroma)


static func init() -> void:
	if font:
		return
	font = _pix("chakra_petch_600")
	font_bold = _pix("chakra_petch_700")
	# Orbitron is tightly spaced; at pixel sizes neighbouring letters merge
	# ("LI" reads as "U"), so it gets one extra pixel between glyphs
	font_big = FontVariation.new()
	font_big.base_font = _pix("orbitron_900")
	font_big.spacing_glyph = 1
	font_mono = _pix("share_tech_mono")
	font_card = FontVariation.new()
	font_card.base_font = _pix("michroma")
	font_card.spacing_glyph = 2


static func _pix(file: String) -> FontFile:
	var f: FontFile = load("res://assets/fonts/%s.woff2" % file)
	f.multichannel_signed_distance_field = false
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NORMAL
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.allow_system_fallback = false
	if "oversampling" in f:
		f.set("oversampling", 1.0) # rasterise at the low internal size
	return f


## Makes fonts rasterise at the UI's internal 480x270 size instead of being
## oversampled to the window size, which keeps them pixelated.
static func pixelate_viewport(vp: Viewport) -> void:
	if "oversampling" in vp:
		vp.set("oversampling", false)
	if "oversampling_override" in vp:
		vp.set("oversampling_override", 1.0)


## Pixel faces need a little more size than the old bitmap fonts to read.
static func px(f: Font, size: int) -> int:
	if f == font_big:
		return int(round(size * 1.25))
	if f == font_mono:
		return int(round(size * 1.5))
	if f == font or f == font_bold:
		return int(round(size * 1.25))
	return size


static func theme() -> Theme:
	init()
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 10
	return t


static func label(text: String, f: Font, size: int, color := Color.WHITE, outline := 0, outline_color := Color(0, 0, 0, 1)) -> Label:
	init()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px(f, size))
	l.add_theme_color_override("font_color", color)
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
