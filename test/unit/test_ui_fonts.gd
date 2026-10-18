extends GutTest
## The pixel face (spec §9.7, §9.9): Jersey 10 draws only at 19 px or a whole
## multiple, and nothing is ever asked for at a size where it draws nothing.


func before_all() -> void:
	Ui.init()


func test_pixel_face_sizes_are_whole_multiples() -> void:
	for f in [Ui.font, Ui.font_bold, Ui.font_mono]:
		for s in range(1, 40):
			var p := Ui.px(f, s)
			assert_true(p >= Ui.PIX and p % Ui.PIX == 0, "size %d gives %d" % [s, p])


func test_pixel_face_line_box_is_snug() -> void:
	assert_eq(Ui.font.get_ascent(Ui.PIX), 13.0)
	assert_eq(Ui.font.get_height(Ui.PIX), 16.0)
	assert_eq(Ui.font.get_height(Ui.PIX * 2), 32.0)


func test_small_display_text_uses_the_pixel_face() -> void:
	assert_eq(Ui.face(Ui.font_big, Ui.BIG_MIN - 1), Ui.font_bold)
	assert_eq(Ui.face(Ui.font_big, Ui.BIG_MIN), Ui.font_big)
	assert_eq(Ui.face(Ui.font_card, Ui.CARD_MIN - 1), Ui.font_bold)
	assert_eq(Ui.face(Ui.font_card, Ui.CARD_MIN), Ui.font_card)


func test_digits_are_fixed_width() -> void:
	var w0 := Ui.font_mono.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
	for d in "123456789":
		assert_eq(Ui.font_mono.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x, w0, "digit " + d)
