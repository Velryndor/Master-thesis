extends Control
## Mouse silhouette with the left button highlighted.
func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var outline := Color("f0f5fa")
	var body := StyleBoxFlat.new()
	body.bg_color = Color("30465a")
	body.border_color = outline
	body.set_border_width_all(3)
	body.set_corner_radius_all(16)
	draw_style_box(body, Rect2(3, 2, 36, 48))
	var left_button := StyleBoxFlat.new()
	left_button.bg_color = Color("61d9b5")
	left_button.corner_radius_top_left = 12
	left_button.corner_radius_bottom_left = 2
	draw_style_box(left_button, Rect2(6, 5, 14, 20))
	draw_line(Vector2(21, 4), Vector2(21, 27), outline, 2, true)
	draw_line(Vector2(5, 27), Vector2(37, 27), outline, 2, true)
	var wheel := StyleBoxFlat.new()
	wheel.bg_color = outline
	wheel.set_corner_radius_all(2)
	draw_style_box(wheel, Rect2(18, 12, 6, 10))
