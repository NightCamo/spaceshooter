extends Area2D

## Fast pooled homing rocket. Retargets if the current target disappears.

@export var damage: float = 45.0
@export var speed: float = 650.0
@export var turn_speed: float = 6.0
@export var lifetime: float = 4.0
@export var explosion_radius: float = 70.0
@export var active_on_ready: bool = true
@export var pooled: bool = false

signal released(projectile: Node)

var _active: bool = false
var _time_left: float = 0.0
var _direction: Vector2 = Vector2.UP
var _target: Node2D
var _screen_size: Vector2 = Vector2.ZERO

@onready var flame: Polygon2D = $Flame

func _ready() -> void:
	add_to_group("player_rockets")
	area_entered.connect(_on_area_entered)
	if active_on_ready:
		activate(global_position)
	else:
		deactivate()

func activate(at_position: Vector2) -> void:
	global_position = at_position
	_screen_size = get_viewport_rect().size
	_time_left = lifetime
	_direction = Vector2.UP
	_target = null
	_active = true
	show()
	monitoring = true
	monitorable = true
	set_process(true)
	_find_target()

func deactivate() -> void:
	_active = false
	hide()
	monitoring = false
	monitorable = false
	set_process(false)

func release() -> void:
	if not _active:
		return
	deactivate()
	if pooled:
		released.emit(self)
	else:
		queue_free()

func _process(delta: float) -> void:
	if not _active:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_explode(false)
		return

	if not is_instance_valid(_target):
		_find_target()

	if is_instance_valid(_target):
		var desired := (_target.global_position - global_position).normalized()
		_direction = _direction.lerp(desired, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

	global_position += _direction * speed * delta
	rotation = _direction.angle() + PI / 2.0
	flame.scale.y = 0.8 + 0.25 * sin(Time.get_ticks_msec() / 40.0)

	if global_position.y < -90.0 or global_position.y > _screen_size.y + 90.0 or global_position.x < -90.0 or global_position.x > _screen_size.x + 90.0:
		release()

func _find_target() -> void:
	var best_distance := INF
	var best_target: Node2D = null
	for area in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(area):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = area
	_target = best_target

func _on_area_entered(area: Area2D) -> void:
	if _active and area.is_in_group("enemies"):
		_explode(true)

func _explode(apply_damage: bool) -> void:
	var container := get_parent()
	if container != null and container.has_method("spawn_explosion"):
		container.call("spawn_explosion", global_position, explosion_radius, Color(1.0, 0.72, 0.18, 1.0))
	elif container != null and container.has_method("_spawn_explosion"):
		container.call("_spawn_explosion", global_position, explosion_radius, Color(1.0, 0.72, 0.18, 1.0))

	if apply_damage:
		for area in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(area) and area.has_method("take_bullet_hit"):
				if global_position.distance_to(area.global_position) <= explosion_radius:
					area.call("take_bullet_hit", damage)
	release()
