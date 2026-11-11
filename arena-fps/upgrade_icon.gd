extends Control

var kind := 0
var available := false
var maxed := false

func set_state(can_buy: bool, completed: bool) -> void:
	if available == can_buy and maxed == completed: return
	available = can_buy
	maxed = completed
	queue_redraw()

func _draw() -> void:
	var color := Color("f0ce83") if available else (Color("82b79e") if maxed else Color("c5cbd0"))
	# Flat silhouettes, kept legible without a panel or textual captions.
	if kind == 0:
		# Cartridge with impact rays: weapon damage.
		draw_colored_polygon(PackedVector2Array([Vector2(25,40),Vector2(25,20),Vector2(32,9),Vector2(39,20),Vector2(39,40)]),color)
		draw_line(Vector2(23,44),Vector2(41,44),color,3,true)
		for side in [-1,1]:
			draw_line(Vector2(32+side*15,18),Vector2(32+side*22,12),color,2,true)
			draw_line(Vector2(32+side*17,28),Vector2(32+side*25,28),color,2,true)
	elif kind == 1:
		# Three fast rounds with motion streaks: rate of fire.
		for i in range(3):
			var y := 14.0+i*13
			draw_line(Vector2(7+i*4,y),Vector2(23,y),color,2,true)
			draw_colored_polygon(PackedVector2Array([Vector2(27,y-4),Vector2(43,y-4),Vector2(50,y),Vector2(43,y+4),Vector2(27,y+4)]),color)
	elif kind == 2:
		# Medical cross with a protective outline: maximum health.
		draw_polyline(PackedVector2Array([Vector2(32,7),Vector2(51,14),Vector2(48,35),Vector2(32,48),Vector2(16,35),Vector2(13,14),Vector2(32,7)]),color,2,true)
		draw_rect(Rect2(28,17,8,22),color)
		draw_rect(Rect2(21,24,22,8),color)
	elif kind == 3:
		# Running silhouette.
		draw_circle(Vector2(37,10),5,color)
		draw_polyline(PackedVector2Array([Vector2(18,25),Vector2(27,17),Vector2(34,21),Vector2(29,32),Vector2(19,43)]),color,4,true)
		draw_polyline(PackedVector2Array([Vector2(34,21),Vector2(42,29),Vector2(51,29)]),color,3,true)
		draw_polyline(PackedVector2Array([Vector2(29,32),Vector2(41,37),Vector2(45,46)]),color,4,true)
		draw_line(Vector2(5,19),Vector2(17,19),color,2,true)
		draw_line(Vector2(8,31),Vector2(18,31),color,2,true)
	elif kind == 4:
		# Magazine silhouette, feed lips and inspection slots.
		draw_polyline(PackedVector2Array([Vector2(22,12),Vector2(42,12),Vector2(39,44),Vector2(18,44),Vector2(22,12)]),color,3,true)
		draw_line(Vector2(22,8),Vector2(29,8),color,3,true)
		draw_line(Vector2(35,8),Vector2(42,8),color,3,true)
		for i in range(3): draw_line(Vector2(26,20+i*7),Vector2(34,20+i*7),color,2,true)
		draw_line(Vector2(16,48),Vector2(41,48),color,3,true)
	if available:
		draw_colored_polygon(PackedVector2Array([Vector2(51,44),Vector2(57,37),Vector2(63,44)]),color)
