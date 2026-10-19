extends GutTest
## The Focus HUD's warning lane (spec §9.7): each hint shows as a coloured
## head line with the rest of the sentence under it.


func test_splits_at_the_first_separator() -> void:
	assert_eq(Hud.split_hint("MISSILES INBOUND - GET OUT OF THE RED CIRCLES"), PackedStringArray(["MISSILES INBOUND", "GET OUT OF THE RED CIRCLES"]))
	assert_eq(Hud.split_hint("KATANA KILLS CHARGE THE SHOTGUN  -  KEEP BOTH HANDS BUSY"), PackedStringArray(["KATANA KILLS CHARGE THE SHOTGUN", "KEEP BOTH HANDS BUSY"]))
	assert_eq(Hud.split_hint("RED SIGNAL: GET CLEAR, OR DASH THROUGH IT AT THE LAST MOMENT"), PackedStringArray(["RED SIGNAL", "GET CLEAR, OR DASH THROUGH IT AT THE LAST MOMENT"]))


func test_keeps_the_exclamation_on_the_head() -> void:
	assert_eq(Hud.split_hint("KAMAE BROKEN!  PRESS F FOR ONIKIRI"), PackedStringArray(["KAMAE BROKEN!", "PRESS F FOR ONIKIRI"]))
	assert_eq(Hud.split_hint("HIGH ABOVE A FOE?  PRESS F TO PLUNGE"), PackedStringArray(["HIGH ABOVE A FOE?", "PRESS F TO PLUNGE"]))


func test_one_line_hints_stay_whole() -> void:
	assert_eq(Hud.split_hint("JUMP OVER THE SHOCKWAVE"), PackedStringArray(["JUMP OVER THE SHOCKWAVE"]))
	assert_eq(Hud.split_hint("SLASH INCOMING BOLTS TO DEFLECT THEM"), PackedStringArray(["SLASH INCOMING BOLTS TO DEFLECT THEM"]))
