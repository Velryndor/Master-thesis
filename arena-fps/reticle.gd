extends Control

var headshot := false

func set_headshot(value: bool) -> void:
	if headshot != value:
		headshot = value
		queue_redraw()

func _draw() -> void:
	# Exact camera-ray center, independent of font metrics or recoil animation.
	var ink := Color(0.015,0.02,0.025,0.95)
	var light := Color("ff9b35") if headshot else Color("f1fbff")
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(direction*6,direction*10,ink,3.5,true)
		draw_line(direction*6,direction*10,light,1.5,true)
	# Contrasting dot remains visible on both dark zombies and bright surfaces.
	draw_circle(Vector2.ZERO,3.0,ink)
	draw_circle(Vector2.ZERO,1.4,light)
