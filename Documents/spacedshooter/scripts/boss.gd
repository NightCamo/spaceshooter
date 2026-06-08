extends Area2D

## Multi-phase boss. Uses the existing enemy bullet pool and normal damage API.

@export var max_health: float = 900.0
@export var points: int = 120
@export var move_speed: float = 95.0
@export var bullet_speed: float = 360.0

signal health_changed(current_health: float, max_health: float)
signal destroyed(points: int, at_position: Vector2)
signal warning(message: String)

var health: float = 0.0
var _dead: bool = false
var _phase: int = 1
var _direction: float = 1.0
var _attack_cooldown: float = 1.5
var _warning_time: float = 0.0
var _pending_attack: StringName = &""
var _laser_time: float = 0.0
var _laser_x: float = 0.0
var _laser_direction: float = 1.0
var _laser_damage_timer: float = 0.0
var _screen_size: Vector2 = Vector2.ZERO

@onready var warning_label: Label = $WarningLabel
@onready var warning_beam: Polygon2D = $WarningBeam
@onready var laser_beam: Polygon2D = $LaserBeam
@onready var hull: Polygon2D = $Hull
@onready var core: Polygon2D = $Core

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	health = max_health
	_screen_size = get_viewport_rect().size
	_laser_x = global_position.x
	warning_label.hide()
	warning_beam.hide()
	laser_beam.hide()
	health_changed.emit(health, max_health)

func _process(delta: float) -> void:
	if _dead:
		return
	_update_phase()
	_update_movement(delta)
	_update_warning(delta)
	_update_laser(delta)

	if _warning_time <= 0.0 and _laser_time <= 0.0:
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_choose_attack()

func take_bullet_hit(damage: float = 1.0) -> void:
	if _dead:
		return
	health -= damage
	health_changed.emit(max(health, 0.0), max_health)
	if health <= 0.0:
		_die()
	else:
		core.color = Color(1.0, 0.86, 0.45, 1.0)

func _update_phase() -> void:
	var percent := health / max_health
	var new_phase := 1
	if percent <= 0.35:
		new_phase = 3
	elif percent <= 0.70:
		new_phase = 2
	if new_phase == _phase:
		return
	_phase = new_phase
	warning.emit("Boss phase %d" % _phase)
	match _phase:
		2:
			move_speed = 135.0
			hull.color = Color(0.82, 0.22, 1.0, 1.0)
		3:
			move_speed = 170.0
			hull.color = Color(1.0, 0.22, 0.18, 1.0)

func _update_movement(delta: float) -> void:
	position.x += _direction * move_speed * delta
	if position.x < 140.0:
		position.x = 140.0
		_direction = 1.0
	elif position.x > _screen_size.x - 140.0:
		position.x = _screen_size.x - 140.0
		_direction = -1.0
	position.y = lerpf(position.y, 96.0, delta * 2.5)

func _choose_attack() -> void:
	match _phase:
		1:
			_queue_attack(&"straight", 0.35, "Boss shot")
		2:
			var attacks: Array[StringName] = [&"spread", &"drone", &"circle"]
			_queue_attack(attacks[randi() % attacks.size()], 0.55, "Incoming pattern")
		3:
			var attacks: Array[StringName] = [&"laser", &"barrage", &"circle", &"spread"]
			var attack := attacks[randi() % attacks.size()]
			var text := "DANGER: laser sweep" if attack == &"laser" else "DANGER: barrage"
			_queue_attack(attack, 0.9, text)

func _queue_attack(attack_name: StringName, warn_time: float, text: String) -> void:
	_pending_attack = attack_name
	_warning_time = warn_time
	warning.emit(text)
	warning_label.text = text
	warning_label.show()
	if attack_name == &"laser":
		_laser_x = global_position.x - 180.0
		_laser_direction = 1.0
		_update_beam_polygon(warning_beam, _laser_x, Color(1.0, 0.2, 0.1, 0.22), 30.0)
		warning_beam.show()

func _update_warning(delta: float) -> void:
	if _warning_time <= 0.0:
		return
	_warning_time -= delta
	if _pending_attack == &"laser":
		_update_beam_polygon(warning_beam, _laser_x, Color(1.0, 0.2, 0.1, 0.22), 30.0)
	if _warning_time <= 0.0:
		warning_label.hide()
		warning_beam.hide()
		_start_attack(_pending_attack)
		_pending_attack = &""

func _start_attack(attack_name: StringName) -> void:
	match attack_name:
		&"straight":
			_attack_straight()
			_attack_cooldown = 1.15
		&"spread":
			_attack_spread()
			_attack_cooldown = 1.35
		&"circle":
			_attack_circle()
			_attack_cooldown = 1.7
		&"drone":
			_attack_drone()
			_attack_cooldown = 2.0
		&"barrage":
			_attack_barrage()
			_attack_cooldown = 1.25
		&"laser":
			_start_laser_sweep()
			_attack_cooldown = 1.65

func _attack_straight() -> void:
	_spawn_boss_bullet(global_position + Vector2(0, 64), Vector2.DOWN)

func _attack_spread() -> void:
	for angle in [-0.36, -0.18, 0.0, 0.18, 0.36]:
		_spawn_boss_bullet(global_position + Vector2(0, 60), Vector2.DOWN.rotated(angle), bullet_speed)

func _attack_circle() -> void:
	for i in 16:
		var direction := Vector2.RIGHT.rotated(float(i) / 16.0 * TAU)
		if direction.y > -0.35:
			_spawn_boss_bullet(global_position, direction, bullet_speed * 0.8)

func _attack_drone() -> void:
	var main := get_parent()
	if main == null or not main.has_method("spawn_enemy"):
		return
	for offset in [-92.0, 0.0, 92.0]:
		main.call("spawn_enemy", &"scout", global_position + Vector2(offset, 44.0))

func _attack_barrage() -> void:
	for offset in [-96.0, -48.0, 0.0, 48.0, 96.0]:
		var direction := Vector2.DOWN.rotated(randf_range(-0.22, 0.22))
		_spawn_boss_bullet(global_position + Vector2(offset, 56.0), direction, bullet_speed * 1.2)

func _start_laser_sweep() -> void:
	_laser_time = 1.45
	_laser_damage_timer = 0.0
	_laser_x = global_position.x - 180.0
	_laser_direction = 1.0
	laser_beam.show()

func _update_laser(delta: float) -> void:
	if _laser_time <= 0.0:
		laser_beam.hide()
		return
	_laser_time -= delta
	_laser_x += _laser_direction * 300.0 * delta
	if _laser_x > global_position.x + 180.0:
		_laser_direction = -1.0
	if _laser_x < global_position.x - 180.0:
		_laser_direction = 1.0
	_update_beam_polygon(laser_beam, _laser_x, Color(1.0, 0.18, 0.08, 0.55), 22.0)

	_laser_damage_timer -= delta
	if _laser_damage_timer <= 0.0:
		_laser_damage_timer = 0.35
		var player = get_tree().get_first_node_in_group("player")
		if player != null and abs(player.global_position.x - _laser_x) <= 20.0 and player.global_position.y > global_position.y:
			if player.has_method("take_damage"):
				player.call("take_damage")

	if _laser_time <= 0.0:
		laser_beam.hide()

func _update_beam_polygon(poly: Polygon2D, global_x: float, color: Color, width: float) -> void:
	var local_x := global_x - global_position.x
	poly.color = color
	poly.polygon = PackedVector2Array([
		Vector2(local_x - width * 0.5, -20.0),
		Vector2(local_x + width * 0.5, -20.0),
		Vector2(local_x + width * 0.5, _screen_size.y),
		Vector2(local_x - width * 0.5, _screen_size.y),
	])

func _spawn_boss_bullet(at_position: Vector2, direction: Vector2, shot_speed: float = -1.0) -> void:
	var main := get_parent()
	if main != null and main.has_method("spawn_enemy_bullet"):
		main.call("spawn_enemy_bullet", at_position, direction, shot_speed)

func _die() -> void:
	if _dead:
		return
	_dead = true
	destroyed.emit(points, global_position)
	queue_free()
