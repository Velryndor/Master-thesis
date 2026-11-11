extends Control
## A keyboard key with an outlined face and bevel, matching the controls reference.
var caption := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Label.new()
	text.text = caption
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_bottom = -8
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("font_size", 17)
	text.add_theme_color_override("font_color", Color("f0f5fa"))
	text.add_theme_color_override("font_outline_color", Color("f0f5fa"))
	text.add_theme_constant_override("outline_size", 1)
	add_child(text)
	resized.connect(queue_redraw)

func _draw() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color("243647")
	base.border_color = Color("f0f5fa")
	base.set_border_width_all(3)
	base.set_corner_radius_all(9)
	draw_style_box(base, Rect2(Vector2(2,2),size-Vector2(4,4)))
	var face := StyleBoxFlat.new()
	face.bg_color = Color("30465a")
	face.border_color = Color("f0f5fa")
	face.set_border_width_all(3)
	face.set_corner_radius_all(6)
	draw_style_box(face,Rect2(Vector2(8,2),size-Vector2(16,13)))
