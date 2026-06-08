extends Area2D

## Player ship. Moves with WASD/arrow keys and fires automatically.
## Pickups can improve fire rate, spread, speed, lives, or shields.

@export var speed: float = 420.0
@export var fire_rate: float = 0.16
@export var bullet_scene: PackedScene
@export var laser_scene: PackedScene = preload("res://scenes/player_laser.tscn")
@export var max_lives: int = 3
@export var invincible_duration: float = 1.2
@export var auto_fire_enabled: bool = true
@export var touch_drag_enabled: bool = true

@export var rapid_fire_duration: float = 8.0
@export var spread_duration: float = 10.0
@export var speed_boost_duration: float = 8.0
@export var shield_duration: float = 10.0
@export var laser_duration: float = 1.5
@export var laser_cooldown: float = 5.0
@export var rocket_cooldown: float = 2.0
@export var rocket_boost_duration: float = 8.0
@export var bomb_damage: float = 120.0

signal hit(lives_left: int)
signal lives_changed(lives_left: int)
signal died
signal powerup_applied(label: String, duration: float)
signal bomb_requested(at_position: Vector2, damage: float)

var lives: int = 0
var weapon_level: int = 1

var _shoot_cooldown: float = 0.0
var _invincible: bool = false
var _invincible_time: float = 0.0
var _muzzle_time: float = 0.0

var _rapid_time: float = 0.0
var _spread_time: float = 0.0
var _speed_time: float = 0.0
var _shield_time: float = 0.0
var _shield_charges: int = 0
var _rocket_boost_time: float = 0.0
var _laser_cooldown_time: float = 0.0
var _rocket_cooldown_time: float = 0.0
var _bomb_charges: int = 1
var _touch_drag_active: bool = false
var _touch_target: Vector2 = Vector2.ZERO
var _key_down: Dictionary = {}
var _laser: Node

@onready var flame: Polygon2D = $Flame
@onready var muzzle: Polygon2D = $Muzzle
@onready var shield_visual: Polygon2D = $Shield

func _ready() -> void:
	lives = max_lives
	add_to_group("player")
	area_entered.connect(_on_area_entered)
	muzzle.hide()
	shield_visual.hide()
	_create_laser()

func _input(event: InputEvent) -> void:
	if not touch_drag_enabled:
		return
	if event is InputEventScreenTouch:
		_touch_drag_active = event.pressed
		_touch_target = event.position
	elif event is InputEventScreenDrag:
		_touch_drag_active = true
		_touch_target = event.position

func _process(delta: float) -> void:
	_update_powerups(delta)
	_update_special_cooldowns(delta)

	var direction := _get_move_direction()
	position += direction * _current_speed() * delta
	_clamp_to_screen()

	_shoot_cooldown = max(_shoot_cooldown - delta, 0.0)
	if _wants_to_shoot() and _shoot_cooldown == 0.0:
		_shoot()
		_shoot_cooldown = _current_fire_rate()

	_update_invincibility(delta)
	_animate_flame(delta)
	_update_muzzle(delta)
	_update_shield_visual()
	_handle_special_input()

func _get_move_direction() -> Vector2:
	var direction := Vector2.ZERO

	if _action_pressed("move_left") or _action_pressed("ui_left") or _key_pressed(KEY_A) or _key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if _action_pressed("move_right") or _action_pressed("ui_right") or _key_pressed(KEY_D) or _key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if _action_pressed("move_up") or _action_pressed("ui_up") or _key_pressed(KEY_W) or _key_pressed(KEY_UP):
		direction.y -= 1.0
	if _action_pressed("move_down") or _action_pressed("ui_down") or _key_pressed(KEY_S) or _key_pressed(KEY_DOWN):
		direction.y += 1.0
	if _touch_drag_active:
		var drag_delta := _touch_target - global_position
		if drag_delta.length() > 12.0:
			direction += drag_delta.normalized()

	if direction.length_squared() > 1.0:
		return direction.normalized()
	return direction

func _key_pressed(keycode: Key) -> bool:
	return Input.is_key_pressed(keycode) or Input.is_physical_key_pressed(keycode)

func _action_pressed(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)

func _key_just_pressed(keycode: Key) -> bool:
	var is_down := Input.is_key_pressed(keycode)
	var was_down: bool = _key_down.get(keycode, false)
	_key_down[keycode] = is_down
	return is_down and not was_down

func _wants_to_shoot() -> bool:
	return auto_fire_enabled \
		or _action_pressed("shoot") \
		or _action_pressed("ui_accept") \
		or _key_pressed(KEY_SPACE)

func _current_speed() -> float:
	return speed * (1.35 if _speed_time > 0.0 else 1.0)

func _current_fire_rate() -> float:
	var rate := fire_rate
	if _rapid_time > 0.0:
		rate *= 0.45
	if weapon_level >= 3:
		rate *= 0.85
	return max(rate, 0.045)

func _rocket_current_cooldown() -> float:
	return rocket_cooldown * (0.45 if _rocket_boost_time > 0.0 else 1.0)

func _clamp_to_screen() -> void:
	var screen := get_viewport_rect().size
	position.x = clampf(position.x, 18.0, screen.x - 18.0)
	position.y = clampf(position.y, 20.0, screen.y - 20.0)

func _shoot() -> void:
	if bullet_scene == null:
		return

	var spread_active := _spread_time > 0.0 or weapon_level >= 3
	if weapon_level <= 1 and not spread_active:
		_spawn_bullet(Vector2(0, -32), Vector2.UP)
	elif weapon_level == 2 and not spread_active:
		_spawn_bullet(Vector2(-10, -26), Vector2.UP)
		_spawn_bullet(Vector2(10, -26), Vector2.UP)
	else:
		_spawn_bullet(Vector2(0, -34), Vector2.UP)
		_spawn_bullet(Vector2(-12, -24), Vector2.UP.rotated(-0.18))
		_spawn_bullet(Vector2(12, -24), Vector2.UP.rotated(0.18))

	_muzzle_time = 0.05
	muzzle.show()

func _spawn_bullet(offset: Vector2, direction: Vector2) -> void:
	var container: Node = get_parent()
	if container == null:
		container = get_tree().current_scene
	if container != null and container.has_method("spawn_player_bullet"):
		container.call("spawn_player_bullet", global_position + offset, direction)
		return

	var bullet = bullet_scene.instantiate()
	container.add_child(bullet)
	bullet.global_position = global_position + offset
	if bullet.has_method("activate"):
		bullet.call("activate", bullet.global_position, direction)
	elif bullet.has_method("set_direction"):
		bullet.call("set_direction", direction)

func _create_laser() -> void:
	if laser_scene == null:
		return
	_laser = laser_scene.instantiate()
	add_child(_laser)
	if _laser.has_method("deactivate"):
		_laser.call("deactivate")

func _handle_special_input() -> void:
	if _key_just_pressed(KEY_L):
		try_fire_laser()
	if _key_just_pressed(KEY_R):
		try_launch_rocket()
	if _key_just_pressed(KEY_B):
		try_use_bomb()

func try_fire_laser() -> bool:
	if _laser == null or _laser_cooldown_time > 0.0:
		return false
	if _laser.has_method("activate"):
		_laser.call("activate", laser_duration)
	_laser_cooldown_time = laser_cooldown
	powerup_applied.emit("Laser fired", laser_duration)
	return true

func try_launch_rocket() -> bool:
	if _rocket_cooldown_time > 0.0:
		return false
	var container: Node = get_parent()
	if container == null:
		container = get_tree().current_scene
	if container == null or not container.has_method("spawn_player_rocket"):
		return false
	if container.call("spawn_player_rocket", global_position + Vector2(0, -28)):
		_rocket_cooldown_time = _rocket_current_cooldown()
		powerup_applied.emit("Rocket launched", 0.0)
		return true
	return false

func try_use_bomb() -> bool:
	if _bomb_charges <= 0:
		return false
	_bomb_charges -= 1
	bomb_requested.emit(global_position, bomb_damage)
	powerup_applied.emit("Bomb used", 0.0)
	return true

func apply_powerup(kind: StringName) -> void:
	match kind:
		&"rapid":
			_rapid_time = max(_rapid_time, rapid_fire_duration)
			powerup_applied.emit("Rapid fire", _rapid_time)
		&"spread":
			weapon_level = min(weapon_level + 1, 3)
			_spread_time = max(_spread_time, spread_duration)
			powerup_applied.emit("Spread shot", _spread_time)
		&"shield":
			_shield_time = max(_shield_time, shield_duration)
			_shield_charges = max(_shield_charges, 2)
			powerup_applied.emit("Shield", _shield_time)
		&"speed":
			_speed_time = max(_speed_time, speed_boost_duration)
			powerup_applied.emit("Speed boost", _speed_time)
		&"life":
			lives = min(lives + 1, max_lives + 2)
			lives_changed.emit(lives)
			powerup_applied.emit("Extra life", 0.0)
		&"bomb":
			_bomb_charges += 1
			powerup_applied.emit("Bomb ready", 0.0)
		&"laser_reset":
			_laser_cooldown_time = 0.0
			powerup_applied.emit("Laser reset", 0.0)
		&"rocket_boost":
			_rocket_boost_time = max(_rocket_boost_time, rocket_boost_duration)
			_rocket_cooldown_time = min(_rocket_cooldown_time, _rocket_current_cooldown())
			powerup_applied.emit("Rocket boost", _rocket_boost_time)

func _update_powerups(delta: float) -> void:
	_rapid_time = max(_rapid_time - delta, 0.0)
	_spread_time = max(_spread_time - delta, 0.0)
	_speed_time = max(_speed_time - delta, 0.0)
	_shield_time = max(_shield_time - delta, 0.0)
	_rocket_boost_time = max(_rocket_boost_time - delta, 0.0)
	if _shield_time == 0.0:
		_shield_charges = 0
	if _spread_time == 0.0 and weapon_level > 1:
		weapon_level = 2

func _update_special_cooldowns(delta: float) -> void:
	_laser_cooldown_time = max(_laser_cooldown_time - delta, 0.0)
	_rocket_cooldown_time = max(_rocket_cooldown_time - delta, 0.0)

func take_damage() -> bool:
	if _invincible:
		return false

	if _shield_charges > 0:
		_shield_charges -= 1
		if _shield_charges == 0:
			_shield_time = 0.0
		_start_invincibility(0.35)
		return true

	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		died.emit()
		queue_free()
	else:
		hit.emit(lives)
		_start_invincibility(invincible_duration)
	return true

func _start_invincibility(duration: float) -> void:
	_invincible = true
	_invincible_time = duration

func _update_invincibility(delta: float) -> void:
	if not _invincible:
		return
	_invincible_time -= delta
	modulate.a = 0.35 if int(_invincible_time * 14.0) % 2 == 0 else 1.0
	if _invincible_time <= 0.0:
		_invincible = false
		modulate.a = 1.0

func _animate_flame(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var boost := 1.3 if _speed_time > 0.0 else 1.0
	flame.scale.y = boost * (0.85 + 0.35 * sin(t * 24.0) + randf() * 0.15)
	flame.scale.x = 0.9 + 0.1 * sin(t * 13.0)

func _update_muzzle(delta: float) -> void:
	if _muzzle_time <= 0.0:
		return
	_muzzle_time -= delta
	if _muzzle_time <= 0.0:
		muzzle.hide()

func _update_shield_visual() -> void:
	if _shield_charges <= 0:
		shield_visual.hide()
		return
	var pulse := 0.16 + 0.08 * sin(Time.get_ticks_msec() / 80.0)
	shield_visual.show()
	shield_visual.color.a = pulse

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") or area.is_in_group("enemy_bullets"):
		if take_damage():
			if area.is_in_group("boss"):
				return
			if area.has_method("release"):
				area.call("release")
			elif area.has_method("deactivate"):
				area.call("deactivate")
			else:
				area.queue_free()
