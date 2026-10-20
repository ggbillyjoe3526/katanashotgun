class_name TexGen
## Procedural low-res textures. Everything is generated at startup so the
## prototype has zero external art; swap these for hand-made 64–128 px
## textures in the art pass.

static var _cache := {}


static func get_tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var img: Image
	match name:
		"floor": img = _floor()
		"panel": img = _panel()
		"concrete": img = _concrete()
		"windows": img = _windows(7)
		"windows_b": img = _windows(21)
		"container": img = _container()
		"hazard": img = _hazard()
		"grate": img = _grate()
		"sign_v0": img = _sign(32, 128, 3)
		"sign_v1": img = _sign(32, 128, 11)
		"sign_v2": img = _sign(32, 128, 23)
		"sign_h0": img = _sign(128, 32, 5)
		"sign_h1": img = _sign(128, 32, 17)
		"ad0": img = _ad(1)
		"ad1": img = _ad(2)
		"ad2": img = _ad(3)
		"splat": img = _splat(64, 4)
		"splat_b": img = _splat(64, 9)
		"glow": img = _glow(32)
		"star": img = _star(32)
		"noise": img = _noise(16, 0.75, 1.0, 2)
		"cloth": img = _noise(16, 0.6, 1.0, 3)
		"skin": img = _noise(8, 0.9, 1.0, 4)
		"lacquer": img = _lacquer()
		"jumppad": img = _jumppad()
		"ring": img = _ring(64)
		"grid": img = _grid()
		"chrome": img = _chrome()
		# world detail (WorldDetail): masks and painted props
		"ao": img = _ao()
		"mist": img = _mist(false)
		"mist_tile": img = _mist(true)
		"beam": img = _beam()
		"pool": img = _pool()
		"vend": img = _vend()
		"door": img = _door()
		"puddle0": img = _puddle(70, false)
		"puddle1": img = _puddle(71, false)
		"puddle2": img = _puddle(72, false)
		"puddle_cell": img = _puddle(90, true)
		_:
			if name.begins_with("sign_v"):
				img = _sign(32, 128, 100 + int(name.substr(6)) * 13)
			elif name.begins_with("sign_h"):
				img = _sign(128, 32, 200 + int(name.substr(6)) * 17)
			elif name.begins_with("ad"):
				img = _ad(int(name.substr(2)) + 1)
			else:
				img = _noise(8, 0.5, 1.0, 1)
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


## Window facades coloured from the run's palette.
static func windows_for(pal: Dictionary, seed_v: int) -> ImageTexture:
	var key := "win_%s_%d" % [pal.name, seed_v]
	if _cache.has(key):
		return _cache[key]
	var r := _rng(seed_v)
	var s := 64
	var img := _img(s, s, Color(0.05, 0.04, 0.08))
	var lit: Array = pal.accents.duplicate()
	lit.append(Color(1.0, 0.85, 0.6))
	for y in s:
		for x in s:
			if y % 16 == 15 or x % 32 == 31:
				img.set_pixel(x, y, Color(0.1, 0.08, 0.14))
	for gy in range(0, s, 8):
		var row_lit := r.randf() < 0.7
		for gx in range(0, s - 3, 4):
			var c := Color(0.07, 0.07, 0.14)
			if row_lit and r.randf() < 0.42:
				c = lit[r.randi() % lit.size()]
				if r.randf() < 0.35:
					c = c.darkened(0.5)
			for y in range(gy + 2, gy + 6):
				for x in range(gx + 1, gx + 3):
					img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _grid() -> Image:
	var r := _rng(64)
	var s := 64
	var img := _img(s, s)
	for y in s:
		for x in s:
			var k := r.randf_range(0.16, 0.22)
			var c := Color(k * 0.8, k * 0.7, k)
			if x < 2 or y < 2:
				c = Color(1, 1, 1)
			elif x == 32 or y == 32:
				c = Color(0.5, 0.5, 0.5)
			img.set_pixel(x, y, c)
	return img


static func _chrome() -> Image:
	var s := 32
	var img := _img(s, s)
	for y in s:
		var band := 0.55 + 0.45 * sin(y * 0.45) * sin(y * 0.13 + 1.0)
		for x in s:
			var k := clampf(band, 0.15, 1.0)
			if x % 16 == 0:
				k *= 0.6
			img.set_pixel(x, y, Color(k, k, k * 1.05))
	return img


static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


static func _img(w: int, h: int, c: Color = Color.BLACK) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


static func _shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _floor() -> Image:
	var r := _rng(42)
	var s := 64
	var img := _img(s, s)
	var base := Color(0.2, 0.18, 0.25)
	for y in s:
		for x in s:
			var k := r.randf_range(0.82, 1.08)
			if x % 32 == 0 or y % 32 == 0:
				k *= 0.55
			img.set_pixel(x, y, _shade(base, k))
	# puddles that "reflect" neon
	for p in 4:
		var cx := r.randi_range(4, 60)
		var cy := r.randi_range(4, 60)
		var rx := r.randi_range(4, 9)
		var ry := r.randi_range(3, 6)
		for y in range(cy - ry, cy + ry + 1):
			for x in range(cx - rx, cx + rx + 1):
				var dx := float(x - cx) / rx
				var dy := float(y - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					var px := posmod(x, s)
					var py := posmod(y, s)
					var c := Color(0.1, 0.09, 0.16)
					var roll := r.randf()
					if roll < 0.07:
						c = Color(0.85, 0.2, 0.7)
					elif roll < 0.13:
						c = Color(0.2, 0.75, 0.9)
					img.set_pixel(px, py, c)
	# cracks
	for c in 6:
		var x := r.randi_range(0, s - 1)
		var y := r.randi_range(0, s - 1)
		for i in r.randi_range(6, 16):
			img.set_pixel(posmod(x, s), posmod(y, s), _shade(base, 0.4))
			x += r.randi_range(-1, 1)
			y += r.randi_range(0, 1)
	return img


static func _panel() -> Image:
	var r := _rng(7)
	var s := 64
	var img := _img(s, s)
	var base := Color(0.34, 0.35, 0.42)
	for y in s:
		for x in s:
			var k := r.randf_range(0.88, 1.05)
			if x % 32 == 0 or y % 16 == 0:
				k = 0.45
			elif x % 32 == 1 or y % 16 == 1:
				k = 1.25
			img.set_pixel(x, y, _shade(base, k))
	for y in range(3, s, 16):
		for x in range(3, s, 8):
			img.set_pixel(x, y, Color(0.75, 0.75, 0.8))
	for i in 60:
		var x := r.randi_range(0, s - 1)
		var y := r.randi_range(0, s - 1)
		img.set_pixel(x, y, _shade(base, 0.6))
	return img


static func _concrete() -> Image:
	var r := _rng(3)
	var s := 32
	var img := _img(s, s)
	var base := Color(0.4, 0.38, 0.44)
	for y in s:
		for x in s:
			var k := r.randf_range(0.8, 1.05)
			if y > 24:
				k *= 0.85
			img.set_pixel(x, y, _shade(base, k))
	return img


static func _windows(seed_v: int) -> Image:
	var r := _rng(seed_v)
	var s := 64
	var img := _img(s, s, Color(0.07, 0.06, 0.1))
	var lit := [Color(1.0, 0.78, 0.4), Color(0.35, 0.9, 1.0), Color(1.0, 0.35, 0.8), Color(0.9, 0.9, 1.0), Color(1.0, 0.55, 0.25)]
	# facade panel lines
	for y in s:
		for x in s:
			if y % 16 == 15 or x % 32 == 31:
				img.set_pixel(x, y, Color(0.12, 0.1, 0.16))
	for gy in range(0, s, 8):
		var row_lit := r.randf() < 0.75
		for gx in range(0, s - 3, 4):
			var c := Color(0.08, 0.1, 0.18)
			if row_lit and r.randf() < 0.45:
				c = lit[r.randi() % lit.size()]
				if r.randf() < 0.3:
					c = c.darkened(0.45)
			for y in range(gy + 2, gy + 6):
				for x in range(gx + 1, gx + 3):
					var cc := c
					if y == gy + 2 and c.r < 0.2:
						cc = Color(0.16, 0.18, 0.3)
					img.set_pixel(x, y, cc)
	return img


static func _container() -> Image:
	var r := _rng(11)
	var s := 64
	var img := _img(s, s)
	for y in s:
		for x in s:
			var k := 1.0 if (x / 4) % 2 == 0 else 0.72
			k *= r.randf_range(0.85, 1.05)
			if y < 3 or y > s - 4:
				k = 0.5
			var c := Color(k, k, k)
			if r.randf() < 0.02:
				c = Color(0.55, 0.3, 0.15)
			img.set_pixel(x, y, c)
	return img


static func _hazard() -> Image:
	var s := 32
	var img := _img(s, s)
	for y in s:
		for x in s:
			var on := ((x + y) / 8) % 2 == 0
			img.set_pixel(x, y, Color(0.95, 0.75, 0.1) if on else Color(0.08, 0.07, 0.07))
	return img


static func _grate() -> Image:
	var s := 32
	var img := _img(s, s, Color(0.05, 0.05, 0.07))
	for y in s:
		for x in s:
			if x % 8 < 2 or y % 8 < 2:
				img.set_pixel(x, y, Color(0.42, 0.42, 0.5))
	return img


static func _glyph(img: Image, ox: int, oy: int, cell: int, r: RandomNumberGenerator) -> void:
	var m := 4
	var t := 2 if cell <= 32 else 3
	var strokes := r.randi_range(3, 6)
	for i in strokes:
		var horizontal := r.randf() < 0.55
		if horizontal:
			var y := oy + r.randi_range(m, cell - m - t)
			var x0 := ox + r.randi_range(m, cell / 2)
			var x1 := ox + r.randi_range(cell / 2, cell - m)
			for x in range(x0, x1):
				for k in t:
					img.set_pixel(x, y + k, Color.WHITE)
		else:
			var x := ox + r.randi_range(m, cell - m - t)
			var y0 := oy + r.randi_range(m, cell / 2)
			var y1 := oy + r.randi_range(cell / 2, cell - m)
			for y in range(y0, y1):
				for k in t:
					img.set_pixel(x + k, y, Color.WHITE)


static func _sign(w: int, h: int, seed_v: int) -> Image:
	var r := _rng(seed_v)
	var img := _img(w, h, Color(0, 0, 0, 1))
	# border tube
	for x in w:
		img.set_pixel(x, 1, Color.WHITE)
		img.set_pixel(x, h - 2, Color.WHITE)
	for y in h:
		img.set_pixel(1, y, Color.WHITE)
		img.set_pixel(w - 2, y, Color.WHITE)
	var cell := mini(w, h)
	if h > w:
		for i in h / cell:
			_glyph(img, 0, i * cell, cell, r)
	else:
		for i in w / cell:
			_glyph(img, i * cell, 0, cell, r)
	return img


static func _ad(seed_v: int) -> Image:
	var r := _rng(seed_v * 31)
	var w := 128
	var h := 64
	var a := Color.from_hsv(r.randf(), 0.8, 0.9)
	var b := Color.from_hsv(r.randf(), 0.9, 0.35)
	var img := _img(w, h)
	for y in h:
		for x in w:
			img.set_pixel(x, y, b.lerp(a, float(y) / h))
	# a big circle "logo"
	var cx := r.randi_range(24, 40)
	var cy := 32
	var rad := r.randi_range(12, 20)
	var lc := Color.from_hsv(r.randf(), 0.5, 1.0)
	for y in h:
		for x in w:
			var d := Vector2(x - cx, y - cy).length()
			if d < rad and d > rad - 4:
				img.set_pixel(x, y, lc)
	# "text" bars
	for i in 4:
		var y := 12 + i * 11
		var x0 := 60
		var x1 := x0 + r.randi_range(28, 60)
		for x in range(x0, mini(x1, w - 4)):
			for k in 4:
				if r.randf() < 0.85:
					img.set_pixel(x, y + k, Color(1, 1, 1))
	return img


static func _splat(s: int, seed_v: int) -> Image:
	var r := _rng(seed_v)
	var img := _img(s, s, Color(1, 1, 1, 0))
	var c := s / 2.0
	var blobs := []
	for i in 7:
		var a := r.randf() * TAU
		var d := r.randf_range(0, s * 0.18)
		blobs.append([Vector2(c + cos(a) * d, c + sin(a) * d), r.randf_range(s * 0.12, s * 0.24)])
	for i in 14:
		var a := r.randf() * TAU
		var d := r.randf_range(s * 0.28, s * 0.46)
		blobs.append([Vector2(c + cos(a) * d, c + sin(a) * d), r.randf_range(1.0, s * 0.05)])
	for y in s:
		for x in s:
			var p := Vector2(x, y)
			for bl in blobs:
				if p.distance_to(bl[0]) < bl[1]:
					var k := r.randf_range(0.75, 1.0)
					img.set_pixel(x, y, Color(k, k, k, 1))
					break
	return img


static func _glow(s: int) -> Image:
	var img := _img(s, s, Color(1, 1, 1, 0))
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _star(s: int) -> Image:
	var img := _img(s, s, Color(1, 1, 1, 0))
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var v := Vector2(x - c, y - c)
			var d := v.length() / c
			var ang := atan2(v.y, v.x)
			var spikes := pow(absf(cos(ang * 3.0)), 6.0)
			var a := clampf(1.0 - d / (0.35 + 0.65 * spikes), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _ring(s: int) -> Image:
	var img := _img(s, s, Color(1, 1, 1, 0))
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - absf(d - 0.85) * 8.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _noise(s: int, lo: float, hi: float, seed_v: int) -> Image:
	var r := _rng(seed_v)
	var img := _img(s, s)
	for y in s:
		for x in s:
			var k := r.randf_range(lo, hi)
			img.set_pixel(x, y, Color(k, k, k))
	return img


static func _lacquer() -> Image:
	var r := _rng(5)
	var s := 32
	var img := _img(s, s)
	for y in s:
		for x in s:
			var k := r.randf_range(0.85, 1.0)
			var c := Color(0.85 * k, 0.1 * k, 0.12 * k)
			if y % 16 < 2:
				c = Color(0.1, 0.05, 0.06)
			img.set_pixel(x, y, c)
	return img


static func _jumppad() -> Image:
	var s := 32
	var img := _img(s, s, Color(0, 0, 0))
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var d := Vector2(x - c, y - c).length()
			if int(d) % 5 < 2 and d < c:
				img.set_pixel(x, y, Color(1, 1, 1))
	return img


# ---------------------------------------------------------------- world detail
## A soft fade, dark at the bottom: baked contact shadow at a wall's foot.
static func _ao() -> Image:
	var img := _img(8, 64, Color(0, 0, 0, 0))
	for y in 64:
		var a := pow(y / 63.0, 1.6)
		for x in 8:
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return img


static func _noise_field(s: int, seed_v: int, tiled: bool) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	n.frequency = 0.035
	n.fractal_octaves = 4
	var img := n.get_seamless_image(s, s, false, false, 0.1, true) if tiled else n.get_image(s, s, false, false, true)
	return img


## Wisps of mist: a soft round patch, or (tiled) a seamless sheet.
static func _mist(tiled: bool) -> Image:
	var s := 128
	var n := _noise_field(s, 12 if tiled else 9, tiled)
	var img := _img(s, s, Color(1, 1, 1, 0))
	var c := (s - 1) / 2.0
	for y in s:
		for x in s:
			var a := clampf(n.get_pixel(x, y).r * 1.5 - 0.35, 0.0, 1.0)
			if not tiled:
				a *= pow(clampf(1.0 - Vector2(x - c, y - c).length() / c, 0.0, 1.0), 0.7)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


## A light beam: bright at the top edge and centre line, fading out.
static func _beam() -> Image:
	var img := _img(32, 128, Color(1, 1, 1, 0))
	for y in 128:
		var down := pow(1.0 - y / 127.0, 1.2)
		for x in 32:
			var across := pow(clampf(1.0 - absf(x / 15.5 - 1.0), 0.0, 1.0), 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, across * down))
	return img


## A pool of lamp light on the floor (additive: the colour is the light).
static func _pool() -> Image:
	var s := 64
	var img := _img(s, s)
	for y in s:
		for x in s:
			var d := Vector2(x - s * 0.5 + 0.5, y - s * 0.5 + 0.5).length() / (s * 0.5)
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.0)
			img.set_pixel(x, y, Color(a, a, a, 1))
	return img


static func _fill(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			img.set_pixel(x, y, c)


## A vending machine front: lit header, rows of cans, a keypad.
static func _vend() -> Image:
	var r := _rng(5)
	var img := _img(32, 64, Color(0.08, 0.08, 0.08))
	_fill(img, 2, 2, 30, 14, Color(0.95, 0.95, 1.0))
	_fill(img, 6, 6, 26, 9, Color(0.9, 0.2, 0.4))
	var cans := [Color(1, 0.3, 0.3), Color(0.3, 0.8, 1), Color(1, 0.85, 0.3), Color(0.4, 1, 0.5), Color(1, 0.5, 0.9)]
	for row in 4:
		var y := 17 + row * 9
		_fill(img, 2, y - 1, 22, y + 7, Color(0.75, 0.8, 0.9))
		for k in 4:
			_fill(img, 3 + k * 5, y + 1, 6 + k * 5, y + 6, cans[r.randi() % cans.size()])
	_fill(img, 24, 17, 30, 52, Color(0.2, 0.2, 0.25))
	for k in 3:
		_fill(img, 25, 20 + k * 4, 29, 21 + k * 4, Color(0.3, 1.0, 0.4))
	_fill(img, 4, 54, 20, 60, Color(0.02, 0.02, 0.02))
	return img


## A shop shutter, half open, with warm light spilling out below.
static func _door() -> Image:
	var img := _img(32, 64, Color(0.05, 0.05, 0.05))
	for y in range(4, 34):
		var k := 0.28 if y % 3 != 0 else 0.12
		_fill(img, 2, y, 30, y + 1, Color(k, k, k))
	for y in range(34, 62):
		var g := (y - 34) / 28.0
		_fill(img, 2, y, 30, y + 1, Color(1.0, 0.75, 0.45) * (0.55 + 0.45 * g))
	_fill(img, 0, 0, 32, 3, Color(0.9, 0.3, 0.2))
	return img


## Alpha mask of a rain puddle: a few merged blobs with a ragged rim. `cell`
## also fills a square recess (an open floor cell), with dry corners.
static func _puddle(seed_v: int, cell: bool) -> Image:
	var r := _rng(seed_v)
	var s := 64
	var n := _noise_field(s, seed_v + 50, false)
	var blobs := []
	for i in r.randi_range(3, 5):
		blobs.append([Vector2(r.randf_range(-0.35, 0.35), r.randf_range(-0.35, 0.35)), Vector2(r.randf_range(0.3, 0.6), r.randf_range(0.3, 0.6))])
	var img := _img(s, s, Color(1, 1, 1, 0))
	for y in s:
		for x in s:
			var p := Vector2(x, y) / (s - 1) * 2.0 - Vector2.ONE
			var f := 0.0
			for b in blobs:
				var d: Vector2 = (p - b[0]) / b[1]
				f = maxf(f, 1.0 - d.length_squared())
			if cell:
				f = maxf(f, 1.0 - pow(maxf(absf(p.x), absf(p.y)), 8.0))
			f += (n.get_pixel(x, y).r - 0.5) * 0.35
			img.set_pixel(x, y, Color(1, 1, 1, clampf((f - 0.05) * 6.0, 0.0, 1.0)))
	return img
