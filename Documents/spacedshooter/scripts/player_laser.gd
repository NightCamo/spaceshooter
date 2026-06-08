extends Area2D

## Player special weapon. A single beam Area2D damages every enemy it overlaps.
## Kept as one reusable node to avoid spawning many laser particles/effects.

@export var damage_per_second: float = 80.0
@export var width: float = 20.0
@export var length: float = 900.0

var _active: bool = false
var _time_left: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var beam: Line2D = $Beam
@onready var glow: Line2D = $Glow

func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, length)
	collision_shape.shape = shape
	collision_shape.position = Vector2(0.0, -length * 0.5)
	beam.width = width * 0.45
	glow.width = width
	beam.points = PackedVector2Array([Vector2(0, -24), Vector2(0, -length)])
	glow.points = beam.points
	deactivate()

func activate(duration: float) -> void:
	_time_left = duration
	_active = true
	show()
	monitoring = true
	monitorable = false
	set_process(true)

func deactivate() -> void:
	_active = false
	hide()
	monitoring = false
	monitorable = false
	set_process(false)

func _process(delta: float) -> void:
	if not _active:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		deactivate()
		return

	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 35.0)
	var glow_color := glow.default_color
	glow_color.a = 0.18 + pulse * 0.16
	glow.default_color = glow_color
	var beam_color := beam.default_color
	beam_color.a = 0.75 + pulse * 0.2
	beam.default_color = beam_color

	for area in get_overlapping_areas():
		if area.is_in_group("enemies") and area.has_method("take_bullet_hit"):
			area.call("take_bullet_hit", damage_per_second * delta)
