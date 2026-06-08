extends Node2D

## Lightweight drawn explosion; no external art files needed.

@export var lifetime: float = 0.55
@export var radius: float = 46.0
@export var color: Color = Color(1.0, 0.45, 0.12, 1.0)
@export var spark_count: int = 12
@export var active_on_ready: bool = true
@export var pooled: bool = false

signal released(effect: Node)

var _age: float = 0.0
var _active: bool = false
var _spark_dirs := PackedVector2Array()
var _spark_speeds := PackedFloat32Array()
var _spark_sizes := PackedFloat32Array()

func _ready() -> void:
	_generate_sparks()
	if active_on_ready:
		activate(global_position, radius, color)
	else:
		deactivate()

func configure(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	color = new_color
	if is_inside_tree():
		_generate_sparks()

func activate(at_position: Vector2, new_radius: float, new_color: Color) -> void:
	global_position = at_position
	_age = 0.0
	radius = new_radius
	color = new_color
	_active = true
	show()
	set_process(true)
	add_to_group("explosions")
	_generate_sparks()

func deactivate() -> void:
	_active = false
	hide()
	set_process(false)
	remove_from_group("explosions")

func release() -> void:
	if not _active:
		return
	deactivate()
	if pooled:
		released.emit(self)
	else:
		queue_free()

func _generate_sparks() -> void:
	_spark_dirs.resize(spark_count)
	_spark_speeds.resize(spark_count)
	_spark_sizes.resize(spark_count)
	for i in range(spark_count):
		_spark_dirs[i] = Vector2.RIGHT.rotated(randf() * TAU)
		_spark_speeds[i] = randf_range(radius * 0.9, radius * 2.2)
		_spark_sizes[i] = randf_range(2.0, 4.5)

func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if _age >= lifetime:
		release()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var fade := 1.0 - t
	var core := color
	core.a = 0.55 * fade
	draw_circle(Vector2.ZERO, radius * t * 0.65, core)

	var ring := Color(1.0, 0.9, 0.4, 0.65 * fade)
	draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 24, ring, 4.0)

	for i in range(_spark_dirs.size()):
		var distance := _spark_speeds[i] * _age
		var pos := _spark_dirs[i] * distance
		var spark_color := Color(1.0, 0.82, 0.34, 0.9 * fade)
		draw_circle(pos, _spark_sizes[i] * fade, spark_color)
