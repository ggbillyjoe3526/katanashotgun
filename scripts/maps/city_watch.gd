class_name CityWatch
extends Node3D
## THE CITY IS WATCHING (spec §19.1 #9, built for the owner to try): the city
## reacts to the run. TSUKUYOMI news drones gather round the roof as the combo
## climbs, hold their lights on the player and fly off once it breaks; city
## screens on masts show the live score, kills and combo, and the best initials
## this save holds for the seed.
## Presentation only: it reads Game and Profile and never writes them. Its RNG
## is seeded from the run seed and never draws from a gameplay stream (or the
## backdrop's), so neither the run nor the city's look can shift. Cheap: the
## drones, their lights and the screen plates are MultiMeshes, the masts and
## frames join the backdrop's batched strips, and text is rebuilt only when a
## value changes. The preset sets how many drones and screens there are.

const COMBO_PER_DRONE := 4 # one more drone every 4 combo
const LINGER := 5.0 # seconds the drones stay once the combo drops
const LEAVE_GAP := 0.8 # then one leaves every this many seconds
const FLY_TIME := 2.6 # seconds to fly in from the city or back out
## Drones hold a ring round a spot between the roof's centre and the player
## (FOLLOW of the way to the player, drifting there slowly), so they gather
## where the action is. The ring stays inside the 57 m traffic lane, and its
## height clears everything on the roof (the beacon cap is +13) and the 13 m
## lane, so nothing ever flies through a drone.
const STATION_R := Vector2(22.0, 26.0)
const STATION_Y := Vector2(17.0, 23.0)
const FOLLOW := 0.6
const FOLLOW_RATE := 0.5 # how fast the ring's centre drifts after the player
const DRONE_SCALE := 2.4 # a 6 m broadcast rig, big enough to read from across the roof
const AWAY_R := 135.0 # where a drone waits out of sight
const AWAY_Y := 60.0
const LIGHT_LEN := 20.0 # longest a drone's light gets
const LIGHT_GAP := 6.0 # it always ends at least this far short of the player
const LIGHT_W := 1.4 # radius of the light where it ends
const LIGHT_FADE := 0.6 # seconds for the light to switch on once on station
const MILESTONES := [10, 25, 50, 75, 100, 150, 200] # the drones' cameras flash
const FLASH_TIME := 0.25
const LENS_ENERGY := 3.0
const LENS_FLASH := 9.0 # extra lens energy at a milestone, times the flash slider
## Screens on masts between the 57 m traffic lane and the tower ring, at
## [bearing (radians, -PI/2 is north, where the player faces), radius, height].
## High enough to clear the north deck and shrine tower from the south roof.
## The first two flank the sun's gap to the north and stay on every preset.
const SCREENS := [[-PI * 0.5 - 0.72, 59.5, 40.0], [-PI * 0.5 + 0.72, 59.5, 40.0], [PI, 59.5, 40.0], [0.0, 59.5, 40.0]]
const LIVE_TIME := 7.0 # seconds a screen shows the live feed
const RECORD_TIME := 5.0 # then the seed's record
const NEW_BEST_TIME := 4.0 # held when the score passes the seed's record
enum { PAGE_LIVE, PAGE_RECORD, PAGE_NEW_BEST }

var arena: Arena
var rng := RandomNumberGenerator.new()
var screens: Array[CityScreen] = []
var record: Dictionary = {} # the best saved entry for this seed, {} if none
var seed_text := ""

var _drones: MultiMesh
var _lights: MultiMesh
var _plates: MultiMesh
var _lens_mat: ShaderMaterial
var _bearing := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _height := PackedFloat32Array()
var _progress := PackedFloat32Array() # 0 away in the city, 1 on station
var _on_station := PackedFloat32Array() # seconds on station, for the light
var _target := 0 # drones wanted on station
var _linger := 0.0
var _cap := 0
var _flash := 0.0
var _last_combo := 0
var _t := 0.0
var _centre := Vector3.ZERO
# screens
var _page_t := 0.0
var _new_best_t := 0.0
var _beaten := false
var _page := PackedInt32Array() # the page each screen shows
var _shown_score := -1 # what the live page last showed
var _shown_kills := -1
var _shown_combo := -1


## Builds the drones and screens. Masts and frames go into the backdrop's
## batches, so call this before the backdrop flushes them.
func build(backdrop: CityBackdrop) -> void:
	arena = backdrop.arena
	rng.seed = hash(Game.run_seed * 13 + 9)
	seed_text = Game.seed_string(Game.run_seed)
	record = seed_record(Profile.high_scores, seed_text)
	var acc: Array = backdrop.accents
	_build_drones(acc)
	_build_screens(backdrop, acc)
	_on_quality(Quality.preset)
	Quality.on_changed(_on_quality)
	_refresh_pages(false)


func _exit_tree() -> void:
	Quality.off_changed(_on_quality)


## How many drones a combo calls in, up to `cap`.
static func drones_for_combo(combo: int, cap: int) -> int:
	return clampi(combo / COMBO_PER_DRONE, 0, cap)


## The best entry in `scores` (best first, as the profile keeps them) played
## on `seed_str`, or {} when none of the saved scores is for that seed.
static func seed_record(scores: Array, seed_str: String) -> Dictionary:
	for e in scores:
		if e is Dictionary and str(e.get("seed", "")) == seed_str:
			return e
	return {}


## Debug (--juicetest): pretend this seed has a saved record.
func demo_record(initials: String, score: int) -> void:
	record = {"name": initials, "score": score, "wave": 0, "seed": seed_text}
	_beaten = Game.score > score
	_refresh_pages(true)


func active_drones() -> int:
	return _target


## Drones in view (on station or flying).
func visible_drones() -> int:
	var n := 0
	for k in _progress.size():
		if _progress[k] > 0.0:
			n += 1
	return n


func _on_quality(_id: String) -> void:
	_cap = mini(Quality.cap("drones"), _progress.size())
	var shown := mini(Quality.cap("screens"), screens.size())
	for i in screens.size():
		screens[i].visible = i < shown
	_plates.visible_instance_count = shown


# ---------------------------------------------------------------- drones
func _build_drones(acc: Array) -> void:
	var count := Quality.max_cap("drones")
	var body := Psx.lit(Color(0.42, 0.44, 0.52), TexGen.get_tex("chrome"), false, 1.0)
	var neon := Psx.unlit(acc[3 % acc.size()], 3.0, null, {"fog_amount": 0.2, "fog_end": 300.0})
	_lens_mat = Psx.unlit(Color(0.85, 0.95, 1.0), LENS_ENERGY, null, {"fog_amount": 0.15, "fog_end": 300.0})
	var rec := Psx.unlit(Color("ff2a3a"), 4.0, null, {"flicker": 0.6, "fog_amount": 0.1})
	var mesh := ArrayMesh.new()
	# local -z faces the player: the camera and lens sit on the nose
	_part(mesh, body, [
		[Vector3(1.0, 0.4, 1.0), Vector3.ZERO, 0.0],
		[Vector3(2.4, 0.08, 0.14), Vector3(0, 0.12, 0), PI * 0.25],
		[Vector3(2.4, 0.08, 0.14), Vector3(0, 0.12, 0), -PI * 0.25],
		[Vector3(0.4, 0.4, 0.45), Vector3(0, -0.3, -0.35), 0.0],
	])
	# neon rotor rings and a lit belly: seen from below against the night sky,
	# each drone reads as a bright cross of light
	var tips := []
	for a in 4:
		var ang := PI * 0.25 + a * PI * 0.5
		tips.append([Vector3(0.7, 0.1, 0.7), Vector3(cos(ang) * 1.15, 0.12, sin(ang) * 1.15), PI * 0.25])
	tips.append([Vector3(0.8, 0.05, 0.8), Vector3(0, -0.21, 0), 0.0])
	tips.append([Vector3(1.04, 0.06, 0.06), Vector3(0, -0.05, 0.51), 0.0])
	_part(mesh, neon, tips)
	_part(mesh, _lens_mat, [[Vector3(0.3, 0.3, 0.06), Vector3(0, -0.3, -0.6), 0.0]])
	_part(mesh, rec, [[Vector3(0.16, 0.16, 0.16), Vector3(0.3, 0.27, -0.3), 0.0]])
	# a soft glow round each drone, so it reads as a light in the sky from afar
	var halo := QuadMesh.new()
	halo.size = Vector2(2.2, 2.2)
	var st := SurfaceTool.new()
	st.append_from(halo, 0, Transform3D.IDENTITY)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	mesh.surface_set_material(mesh.get_surface_count() - 1, Psx.fx(Color(acc[3 % acc.size()]).lightened(0.4) * Color(1, 1, 1, 0.9), TexGen.get_tex("glow"), true, true))
	_drones = MultiMesh.new()
	_drones.transform_format = MultiMesh.TRANSFORM_3D
	_drones.mesh = mesh
	_drones.instance_count = count
	_drones.visible_instance_count = 0
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12 # the drone end
	cone.bottom_radius = LIGHT_W
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_lights = MultiMesh.new()
	_lights.transform_format = MultiMesh.TRANSFORM_3D
	_lights.mesh = cone
	_lights.instance_count = count
	_lights.visible_instance_count = 0
	var light_mat := Psx.fx(Color(0.85, 0.92, 1.0, 0.12), TexGen.get_tex("glow"), true)
	for mm: MultiMesh in [_drones, _lights]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mm == _lights:
			mmi.material_override = light_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-150, -10, -150), Vector3(300, 90, 300))
		add_child(mmi)
		Graphics.moving(mmi)
	# each drone keeps a seeded spot on the ring, spread by the golden angle
	var base := rng.randf() * TAU
	for k in count:
		_bearing.append(base + k * 2.39996 + rng.randf_range(-0.2, 0.2))
		_radius.append(rng.randf_range(STATION_R.x, STATION_R.y))
		_height.append(rng.randf_range(STATION_Y.x, STATION_Y.y))
		_progress.append(0.0)
		_on_station.append(0.0)


## Adds one surface to `mesh`: boxes [size, offset, yaw] in one material.
func _part(mesh: ArrayMesh, mat: Material, boxes: Array) -> void:
	var st := SurfaceTool.new()
	for b: Array in boxes:
		var bm := BoxMesh.new()
		bm.size = b[0]
		st.append_from(bm, 0, Transform3D(Basis(Vector3.UP, b[2]), b[1]))
	var arrays := st.commit_to_arrays()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


func _update_drones(delta: float, real_dt: float) -> void:
	var want := drones_for_combo(Game.combo, _cap)
	if want > 0 and want >= _target:
		_target = want
		_linger = LINGER
	elif _target > want:
		_linger -= delta
		if _linger <= 0.0:
			_target -= 1
			_linger = LEAVE_GAP
	_target = mini(_target, _cap)
	# a camera flash from every drone when the combo passes a milestone
	for m: int in MILESTONES:
		if _last_combo < m and Game.combo >= m and _target > 0:
			_flash = FLASH_TIME
	_last_combo = Game.combo
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - real_dt)
		_lens_mat.set_shader_parameter("energy", LENS_ENERGY + LENS_FLASH * Settings.flash * _flash / FLASH_TIME)
	var eye := Vector3(0, 1.2, 0)
	if is_instance_valid(Game.player):
		eye = Game.player.global_position + Vector3(0, 1.2, 0)
	var follow := Vector3(eye.x, 0.0, eye.z) * FOLLOW
	_centre = _centre.lerp(follow, 1.0 - exp(-FOLLOW_RATE * delta))
	var shown := 0
	for k in _progress.size():
		var goal := 1.0 if k < _target else 0.0
		_progress[k] = move_toward(_progress[k], goal, delta / FLY_TIME)
		if _progress[k] > 0.0:
			shown = k + 1
		_on_station[k] = _on_station[k] + delta if _progress[k] >= 1.0 else 0.0
	_drones.visible_instance_count = shown
	_lights.visible_instance_count = shown
	for k in shown:
		var p := _progress[k]
		var b := _bearing[k] + 0.06 * sin(_t * 0.21 + k)
		var station := _centre + Vector3(cos(b) * _radius[k], _height[k] + sin(_t * 1.7 + k * 1.3) * 0.4, sin(b) * _radius[k])
		var away := Vector3(cos(b) * AWAY_R, AWAY_Y, sin(b) * AWAY_R)
		var pos := away.lerp(station, smoothstep(0.0, 1.0, p))
		var to_eye := eye - pos
		_drones.set_instance_transform(k, Transform3D(Basis.looking_at(to_eye, Vector3.UP).scaled(Vector3.ONE * DRONE_SCALE), pos))
		var on := clampf(_on_station[k] / LIGHT_FADE, 0.0, 1.0)
		var length := minf(LIGHT_LEN, to_eye.length() - LIGHT_GAP)
		if on <= 0.0 or length <= 1.0:
			_lights.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), pos))
			continue
		var dir := to_eye / to_eye.length()
		var side := dir.cross(Vector3.UP).normalized()
		var y := -dir # the cone's narrow top sits on the drone
		var z := side.cross(y)
		_lights.set_instance_transform(k, Transform3D(Basis(side * on, y * length, z * on), pos + dir * length * 0.5))


# ---------------------------------------------------------------- screens
func _build_screens(backdrop: CityBackdrop, acc: Array) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_plates = MultiMesh.new()
	_plates.transform_format = MultiMesh.TRANSFORM_3D
	_plates.mesh = quad
	_plates.instance_count = SCREENS.size()
	var mast := Color(0.18, 0.18, 0.25)
	for i in SCREENS.size():
		var s: Array = SCREENS[i]
		var c := Vector3(cos(s[0]) * s[1], s[2], sin(s[0]) * s[1])
		var yaw := atan2(-c.x, -c.z) # local +z faces the arena
		var basis := Basis(Vector3.UP, yaw)
		var size := CityScreen.SIZE
		_plates.set_instance_transform(i, Transform3D(basis * Basis.from_scale(Vector3(size.x, size.y, 1.0)), c))
		var col: Color = acc[(i * 2) % acc.size()]
		var col2: Color = acc[(i * 2 + 1) % acc.size()]
		# a frame of neon round the plate and a mast down into the city
		var back := basis * Vector3(0, 0, -0.4)
		backdrop.add_strip(c + basis * Vector3(0, size.y * 0.5 + 0.15, 0), basis, Vector3(size.x + 0.6, 0.3, 0.3), col)
		backdrop.add_strip(c + basis * Vector3(0, -size.y * 0.5 - 0.15, 0), basis, Vector3(size.x + 0.6, 0.3, 0.3), col)
		for sx in [-1.0, 1.0]:
			backdrop.add_strip(c + basis * Vector3(sx * (size.x * 0.5 + 0.15), 0, 0), basis, Vector3(0.3, size.y, 0.3), col)
		var foot := -40.0
		var top := c.y - size.y * 0.5
		backdrop.add_strip(Vector3(c.x, (top + foot) * 0.5, c.z) + back, basis, Vector3(1.2, top - foot, 1.2), mast)
		backdrop.add_strip(c + back, basis, Vector3(size.x * 0.6, size.y * 0.8, 0.5), mast)
		var scr := CityScreen.new()
		scr.position = c
		scr.rotation.y = yaw
		add_child(scr)
		scr.build(col, col2)
		screens.append(scr)
		_page.append(-1)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _plates
	mmi.material_override = Psx.unlit(Color(0.025, 0.02, 0.05), 1.0, null, {"fog_amount": 0.25, "fog_end": 300.0})
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Screen i shows the live feed or the record. Odd screens open on the
## record, so the two north screens never both show the record at once.
func _page_of(i: int) -> int:
	var cycle := LIVE_TIME + RECORD_TIME
	var t := fposmod(_page_t + (LIVE_TIME if i % 2 == 1 else 0.0), cycle)
	return PAGE_LIVE if t < LIVE_TIME else PAGE_RECORD


func _update_screens(real_dt: float) -> void:
	_page_t += real_dt
	if not _beaten and not record.is_empty() and Game.score > int(record.score):
		_beaten = true
		_new_best_t = NEW_BEST_TIME
		_flash = FLASH_TIME
	elif _new_best_t > 0.0:
		_new_best_t = maxf(0.0, _new_best_t - real_dt)
	var big_combo := Game.combo >= COMBO_PER_DRONE
	var live_changed := Game.score != _shown_score or Game.kills != _shown_kills \
		or big_combo != (_shown_combo >= COMBO_PER_DRONE) or (big_combo and Game.combo != _shown_combo)
	for i in screens.size():
		var now := PAGE_NEW_BEST if _new_best_t > 0.0 else _page_of(i)
		if now != _page[i]:
			_page[i] = now
			screens[i].show_page(_page_texts(now), true)
		elif now == PAGE_LIVE and live_changed:
			screens[i].show_page(_page_texts(now), false)
		screens[i].tick(real_dt)
	if live_changed:
		_remember_live()


func _refresh_pages(swap: bool) -> void:
	for i in screens.size():
		_page[i] = _page_of(i)
		screens[i].show_page(_page_texts(_page[i]), swap)
	_remember_live()


func _remember_live() -> void:
	_shown_score = Game.score
	_shown_kills = Game.kills
	_shown_combo = Game.combo


## The three lines of a page.
func _page_texts(page: int) -> PackedStringArray:
	match page:
		PAGE_LIVE:
			var sub := "x%d COMBO" % Game.combo if Game.combo >= COMBO_PER_DRONE else "%s KILLS" % Juice._num(Game.kills)
			return PackedStringArray(["TSUKUYOMI LIVE", Juice._num(Game.score), sub])
		PAGE_RECORD:
			if record.is_empty():
				return PackedStringArray(["SEED %s" % seed_text, "OPEN", "NO RECORD YET"])
			return PackedStringArray(["SEED %s" % seed_text, str(record.get("name", "---")), "BEST %s" % Juice._num(int(record.score))])
		_:
			return PackedStringArray(["SEED %s" % seed_text, "NEW BEST", "%s BEATEN" % str(record.get("name", "---"))])


# ---------------------------------------------------------------- tick
func _process(delta: float) -> void:
	tick(delta, Game.real_dt)


## One frame: `delta` is game time (drones slow with the world), `real_dt`
## real time (screens hold their text for real seconds, spec §9.9).
func tick(delta: float, real_dt: float) -> void:
	_t += delta
	_update_drones(delta, real_dt)
	_update_screens(real_dt)
