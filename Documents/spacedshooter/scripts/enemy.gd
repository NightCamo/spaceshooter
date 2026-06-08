extends Area2D

## Enemy ship. Main configures variants so waves feel less repetitive.

@export var speed: float = 190.0
@export var enemy_bullet_scene: PackedScene
@export var shoot_interval: float = 1.5
@export var health: float = 1.0
@export var points: int = 1

signal destroyed(points: int, at_position: Vector2)

var _dead: bool = false
var _shoot_time: float = 0.0
var _spawn_x: float = 0.0
var _phase: float = 0.0
var _drift_amplitude: float = 0.0
var _drift_speed: float = 0.0
var _variant: StringName = &"fighter"
var _flash_time: float = 0.0
var _despawn_y: float = 720.0

@onready var glow: Polygon2D = $Glow
@onready var left_wing: Polygon2D = $LWing
@onready var right_wing: Polygon2D = $RWing
@onready var hull: Polygon2D = $Hull
@onready var cockpit: Polygon2D = $Cockpit

func _ready() -> void:
	add_to_group("enemies")
	_spawn_x = position.x
	_despawn_y = get_viewport_rect().size.y + 70.0
	_phase = randf() * TAU
	_shoot_time = randf_range(0.35, shoot_interval)
	_apply_variant_visuals()

func configure_variant(variant: StringName, difficulty: int) -> void:
	_variant = variant
	_spawn_x = position.x
	_drift_amplitude = 0.0
	_drift_speed = 0.0

	match variant:
		&"scout":
			speed = 255.0 + difficulty * 8.0
			shoot_interval = 2.2
			health = 1
			points = 1
			scale = Vector2(0.82, 0.82)
		&"zigzag":
			speed = 175.0 + difficulty * 5.0
			shoot_interval = 1.7
			health = 1
			points = 3
			scale = Vector2(1.0, 1.0)
			_drift_amplitude = 86.0
			_drift_speed = 3.2
		&"bruiser":
			speed = 112.0 + difficulty * 4.0
			shoot_interval = 1.15
			health = 3
			points = 5
			scale = Vector2(1.32, 1.32)
		_:
			speed = 195.0 + difficulty * 6.0
			shoot_interval = 1.45
			health = 1
			points = 2
			scale = Vector2(1.0, 1.0)

	_shoot_time = randf_range(0.25, shoot_interval)
	if is_inside_tree():
		_apply_variant_visuals()

func _process(delta: float) -> void:
	position.y += speed * delta
	if _drift_amplitude > 0.0:
		position.x = _spawn_x + sin(Time.get_ticks_msec() / 1000.0 * _drift_speed + _phase) * _drift_amplitude

	if position.y > _despawn_y:
		queue_free()
		return

	_shoot_time -= delta
	if _shoot_time <= 0.0:
		_shoot()
		_shoot_time = shoot_interval

	if _flash_time > 0.0:
		_flash_time -= delta
		modulate = Color(1.5, 1.5, 1.5, 1.0) if _flash_time > 0.0 else Color.WHITE

func take_bullet_hit(damage: float = 1.0) -> void:
	if _dead:
		return
	health -= damage
	if health <= 0:
		explode()
	else:
		_flash_time = 0.08

func explode() -> void:
	if _dead:
		return
	_dead = true
	destroyed.emit(points, global_position)
	queue_free()

func _shoot() -> void:
	if enemy_bullet_scene == null:
		return

	match _variant:
		&"bruiser":
			_spawn_enemy_bullet(Vector2(-12, 26), Vector2.DOWN.rotated(-0.18))
			_spawn_enemy_bullet(Vector2(0, 30), Vector2.DOWN)
			_spawn_enemy_bullet(Vector2(12, 26), Vector2.DOWN.rotated(0.18))
		&"scout":
			if randf() > 0.35:
				_spawn_enemy_bullet(Vector2(0, 22), Vector2.DOWN)
		_:
			_spawn_enemy_bullet(Vector2(0, 24), Vector2.DOWN)

func _spawn_enemy_bullet(offset: Vector2, direction: Vector2) -> void:
	var container: Node = get_parent()
	if container == null:
		container = get_tree().current_scene
	if container != null and container.has_method("spawn_enemy_bullet"):
		container.call("spawn_enemy_bullet", global_position + offset, direction)
		return

	var bullet = enemy_bullet_scene.instantiate()
	container.add_child(bullet)
	bullet.global_position = global_position + offset
	if bullet.has_method("activate"):
		bullet.call("activate", bullet.global_position, direction)
	elif bullet.has_method("set_direction"):
		bullet.call("set_direction", direction)

func _apply_variant_visuals() -> void:
	var hull_color := Color(0.9, 0.27, 0.27, 1.0)
	var wing_color := Color(0.6, 0.13, 0.18, 1.0)
	var glow_color := Color(0.7, 0.2, 0.9, 0.7)

	match _variant:
		&"scout":
			hull_color = Color(1.0, 0.38, 0.18, 1.0)
			wing_color = Color(0.9, 0.18, 0.08, 1.0)
			glow_color = Color(1.0, 0.75, 0.18, 0.75)
		&"zigzag":
			hull_color = Color(0.78, 0.18, 1.0, 1.0)
			wing_color = Color(0.34, 0.1, 0.65, 1.0)
			glow_color = Color(0.3, 0.95, 1.0, 0.72)
		&"bruiser":
			hull_color = Color(0.42, 0.9, 0.35, 1.0)
			wing_color = Color(0.1, 0.48, 0.18, 1.0)
			glow_color = Color(0.95, 1.0, 0.3, 0.78)

	hull.color = hull_color
	left_wing.color = wing_color
	right_wing.color = wing_color
	glow.color = glow_color
	cockpit.color = Color(1.0, 0.82, 0.45, 1.0)
