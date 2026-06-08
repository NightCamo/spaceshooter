extends Node2D

## A simple animated starfield: dots that scroll downward and wrap around,
## drawn directly with _draw(). No image files needed. Stars come in a few
## tints and gently twinkle so the background feels alive.

@export var star_count: int = 100
@export var speed_min: float = 30.0
@export var speed_max: float = 150.0

# A small palette of star tints (white, pale blue, warm).
const TINTS := [
	Color(1.0, 1.0, 1.0),
	Color(0.7, 0.85, 1.0),
	Color(1.0, 0.9, 0.75),
]

var _stars: Array[Dictionary] = []

func _ready() -> void:
	var size := get_viewport_rect().size
	for i in star_count:
		_stars.append({
			"pos": Vector2(randf() * size.x, randf() * size.y),
			"speed": randf_range(speed_min, speed_max),
			"radius": randf_range(1.0, 2.6),
			"bright": randf_range(0.3, 1.0),
			"tint": TINTS[randi() % TINTS.size()],
			"twinkle": randf() * TAU,         # phase offset so stars blink out of sync
			"twinkle_speed": randf_range(1.5, 4.0),
		})

func _process(delta: float) -> void:
	var size := get_viewport_rect().size
	for s in _stars:
		var p: Vector2 = s.pos
		p.y += s.speed * delta
		if p.y > size.y:                 # fell off the bottom -> wrap to top
			p.y = 0.0
			p.x = randf() * size.x
		s.pos = p
		s.twinkle += s.twinkle_speed * delta
	queue_redraw()   # ask Godot to call _draw() again this frame

func _draw() -> void:
	for s in _stars:
		var flicker: float = 0.65 + 0.35 * sin(s.twinkle)
		var col: Color = s.tint
		col.a = s.bright * flicker
		draw_circle(s.pos, s.radius, col)
		# Faster (closer) stars get a faint halo for a touch of depth.
		if s.speed > 110.0:
			col.a *= 0.25
			draw_circle(s.pos, s.radius * 2.2, col)
