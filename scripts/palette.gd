class_name Palette
## Synthwave colour schemes. Each run picks one from its seed, and every
## system (sky, sun, neon tubes, floor grid, fog, signs, windows) reads from it.

const LIST := [
	{
		"name": "SUNSET DRIVE",
		"sky_top": Color("12002b"), "sky_mid": Color("5a0f6e"), "sky_horizon": Color("ff3d7f"),
		"sun_top": Color("ffe14d"), "sun_bottom": Color("ff2a8a"),
		"fog": Color("3a0b4f"), "ambient": Color("5a3a8a"),
		"neon_a": Color("ff2a8a"), "neon_b": Color("2af6ff"), "neon_c": Color("ffd23f"),
		"grid": Color("ff3df0"), "floor": Color("150a26"), "mountain": Color("2a0838"),
	},
	{
		"name": "MIAMI NIGHTS",
		"sky_top": Color("070a2e"), "sky_mid": Color("2b1d74"), "sky_horizon": Color("ff6ec7"),
		"sun_top": Color("fff07a"), "sun_bottom": Color("ff4f6e"),
		"fog": Color("2a1d5c"), "ambient": Color("4a4a9a"),
		"neon_a": Color("ff4fb8"), "neon_b": Color("3dfcd8"), "neon_c": Color("ff9e3d"),
		"grid": Color("3dfcd8"), "floor": Color("0c0c26"), "mountain": Color("1a1448"),
	},
	{
		"name": "ULTRAVIOLET",
		"sky_top": Color("090018"), "sky_mid": Color("3b0a7a"), "sky_horizon": Color("c45dff"),
		"sun_top": Color("ffb3ff"), "sun_bottom": Color("7b2cff"),
		"fog": Color("2a0a55"), "ambient": Color("5a3aa0"),
		"neon_a": Color("b44dff"), "neon_b": Color("4df0ff"), "neon_c": Color("ff3d9e"),
		"grid": Color("b44dff"), "floor": Color("100626"), "mountain": Color("220a48"),
	},
	{
		"name": "BLOOD CHROME",
		"sky_top": Color("120006"), "sky_mid": Color("4a0820"), "sky_horizon": Color("ff4b3b"),
		"sun_top": Color("ffd27a"), "sun_bottom": Color("ff1f4d"),
		"fog": Color("3a0a1c"), "ambient": Color("6a3448"),
		"neon_a": Color("ff2b4a"), "neon_b": Color("29e7ff"), "neon_c": Color("ffb52b"),
		"grid": Color("ff2b4a"), "floor": Color("1a0810"), "mountain": Color("330a18"),
	},
	{
		"name": "TOXIC TOKYO",
		"sky_top": Color("001312"), "sky_mid": Color("04404a"), "sky_horizon": Color("19ffc1"),
		"sun_top": Color("f6ff7a"), "sun_bottom": Color("19ff9c"),
		"fog": Color("032e33"), "ambient": Color("2a5a60"),
		"neon_a": Color("19ffc1"), "neon_b": Color("ff3df2"), "neon_c": Color("f6ff4a"),
		"grid": Color("19ffc1"), "floor": Color("041416"), "mountain": Color("06303a"),
	},
]


static func pick(rng: RandomNumberGenerator) -> Dictionary:
	return LIST[rng.randi() % LIST.size()]
