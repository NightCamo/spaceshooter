extends Node2D

## Game manager: waves, boss spawns, projectile pools, powerups, combo, UI.

const POWERUP_KINDS: Array[StringName] = [
	&"rapid", &"spread", &"shield", &"speed", &"life",
	&"bomb", &"laser_reset", &"rocket_boost",
]
const STRONG_POWERUP_KINDS: Array[StringName] = [&"spread", &"shield", &"bomb", &"laser_reset", &"rocket_boost"]
const AUTO_SPAWN_POSITION := Vector2(-999999.0, -999999.0)

@export var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
@export var boss_scene: PackedScene = preload("res://scenes/boss.tscn")
@export var player_bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
@export var rocket_scene: PackedScene = preload("res://scenes/rocket.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/powerup.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/explosion.tscn")

@export var spawn_interval: float = 0.85
@export var powerup_interval: float = 6.5
@export var difficulty_step: float = 12.0
@export var wave_duration: float = 16.0
@export var boss_every_waves: int = 5
@export var mobile_controls_enabled: bool = false

@export var max_enemies: int = 42
@export var max_powerups: int = 6
@export var max_explosions: int = 10
@export var initial_player_bullet_pool: int = 40
@export var max_player_bullets: int = 90
@export var initial_enemy_bullet_pool: int = 40
@export var max_enemy_bullets: int = 100
@export var default_enemy_bullet_speed: float = 350.0
@export var initial_rocket_pool: int = 4
@export var max_player_rockets: int = 4
@export var initial_explosion_pool: int = 8

var score: int = 0
var game_over: bool = false

var _elapsed: float = 0.0
var _wave: int = 1
var _wave_time: float = 0.0
var _boss_active: bool = false

var _powerup_timer: Timer
var _perk_label: Label
var _combo_label: Label
var _boss_label: Label
var _boss_bar: ProgressBar
var _mobile_controls: Control
var _perk_label_time: float = 0.0

var _combo_kills: int = 0
var _combo_timer: float = 0.0
var _combo_window: float = 3.0

var _player_bullet_pool: Array[Node] = []
var _enemy_bullet_pool: Array[Node] = []
var _rocket_pool: Array[Node] = []
var _explosion_pool: Array[Node] = []
var _active_player_bullets: int = 0
var _active_enemy_bullets: int = 0
var _active_player_rockets: int = 0

var _debug_key_down: Dictionary = {}

@onready var score_label: Label = $UI/ScoreLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var game_over_label: Label = $UI/GameOverLabel
@onready var spawn_timer: Timer = $EnemySpawnTimer
@onready var player = $Player

func _ready() -> void:
	randomize()
	game_over_label.hide()
	_create_perk_label()
	_create_combo_label()
	_create_boss_ui()
	_create_mobile_controls()
	_prewarm_projectiles()
	_prewarm_explosions()
	_update_score_label()
	_update_lives_label(player.lives)
	_update_combo_label()

	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	_powerup_timer = Timer.new()
	_powerup_timer.wait_time = powerup_interval
	_powerup_timer.timeout.connect(_on_powerup_timer_timeout)
	add_child(_powerup_timer)
	_powerup_timer.start()

	player.hit.connect(_on_player_hit)
	player.lives_changed.connect(_on_player_lives_changed)
	player.died.connect(_on_player_died)
	player.powerup_applied.connect(_on_player_powerup_applied)
	if player.has_signal("bomb_requested"):
		player.bomb_requested.connect(_on_player_bomb_requested)

func _process(delta: float) -> void:
	if game_over:
		if _wants_to_restart():
			get_tree().reload_current_scene()
		return

	_elapsed += delta
	_update_wave(delta)
	_update_combo(delta)
	_update_perk_label(delta)
	_handle_debug_shortcuts()

func _wants_to_restart() -> bool:
	return _action_just_pressed("restart") \
		or _action_just_pressed("shoot") \
		or _action_just_pressed("ui_accept") \
		or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_ENTER) \
		or Input.is_key_pressed(KEY_KP_ENTER)

func _action_just_pressed(action_name: StringName) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)

func _key_just_pressed(keycode: Key) -> bool:
	var is_down := Input.is_key_pressed(keycode)
	var was_down: bool = _debug_key_down.get(keycode, false)
	_debug_key_down[keycode] = is_down
	return is_down and not was_down

func _handle_debug_shortcuts() -> void:
	if _key_just_pressed(KEY_F1):
		spawn_enemy(&"fighter", Vector2(randf_range(80.0, get_viewport_rect().size.x - 80.0), -44.0))
	if _key_just_pressed(KEY_F2):
		spawn_boss()
	if _key_just_pressed(KEY_F3):
		player.call("apply_powerup", &"spread")
	if _key_just_pressed(KEY_F4):
		player.call("apply_powerup", &"shield")
	if _key_just_pressed(KEY_F5):
		player.call("apply_powerup", &"bomb")

func _update_wave(delta: float) -> void:
	_wave_time += delta
	if _wave_time < wave_duration:
		return
	_wave_time = 0.0
	_wave += 1
	if _wave % boss_every_waves == 0:
		spawn_boss()

func _update_combo(delta: float) -> void:
	if _combo_kills <= 0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_kills = 0
		_update_combo_label()

func _update_perk_label(delta: float) -> void:
	if _perk_label_time <= 0.0:
		return
	_perk_label_time -= delta
	if _perk_label_time <= 0.0:
		_perk_label.text = ""

func _create_perk_label() -> void:
	_perk_label = Label.new()
	_perk_label.name = "PerkLabel"
	_perk_label.offset_left = 16.0
	_perk_label.offset_top = 78.0
	_perk_label.offset_right = 420.0
	_perk_label.offset_bottom = 110.0
	_perk_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.7, 1.0))
	_perk_label.add_theme_font_size_override("font_size", 20)
	$UI.add_child(_perk_label)

func _create_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.offset_left = 16.0
	_combo_label.offset_top = 108.0
	_combo_label.offset_right = 300.0
	_combo_label.offset_bottom = 138.0
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
	_combo_label.add_theme_font_size_override("font_size", 20)
	$UI.add_child(_combo_label)

func _create_boss_ui() -> void:
	_boss_label = Label.new()
	_boss_label.name = "BossLabel"
	_boss_label.offset_left = 356.0
	_boss_label.offset_top = 16.0
	_boss_label.offset_right = 796.0
	_boss_label.offset_bottom = 42.0
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4, 1.0))
	_boss_label.add_theme_font_size_override("font_size", 20)
	_boss_label.text = "BOSS"
	_boss_label.hide()
	$UI.add_child(_boss_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.name = "BossHealthBar"
	_boss_bar.offset_left = 356.0
	_boss_bar.offset_top = 44.0
	_boss_bar.offset_right = 796.0
	_boss_bar.offset_bottom = 62.0
	_boss_bar.min_value = 0.0
	_boss_bar.max_value = 1.0
	_boss_bar.value = 1.0
	_boss_bar.hide()
	$UI.add_child(_boss_bar)

func _create_mobile_controls() -> void:
	if not mobile_controls_enabled:
		return
	_mobile_controls = Control.new()
	_mobile_controls.name = "MobileSpecialControls"
	_mobile_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_mobile_controls)
	_add_mobile_button("LASER", Vector2(-332, -96), Vector2(-232, -32), Callable(player, "try_fire_laser"))
	_add_mobile_button("ROCKET", Vector2(-220, -96), Vector2(-112, -32), Callable(player, "try_launch_rocket"))
	_add_mobile_button("BOMB", Vector2(-100, -96), Vector2(-24, -32), Callable(player, "try_use_bomb"))

func _add_mobile_button(label: String, top_left: Vector2, bottom_right: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = top_left.x
	button.offset_top = top_left.y
	button.offset_right = bottom_right.x
	button.offset_bottom = bottom_right.y
	button.pressed.connect(callback)
	_mobile_controls.add_child(button)

func _on_spawn_timer_timeout() -> void:
	if game_over or _boss_active:
		return
	spawn_enemy(_choose_enemy_variant())
	spawn_timer.wait_time = max(0.32, spawn_interval - min(_elapsed * 0.006, 0.45))

func spawn_enemy(variant: StringName = &"fighter", at_position: Vector2 = AUTO_SPAWN_POSITION) -> Node:
	if enemy_scene == null:
		return null
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return null

	var enemy = enemy_scene.instantiate()
	var screen_width := get_viewport_rect().size.x
	if at_position == AUTO_SPAWN_POSITION:
		enemy.position = Vector2(randf_range(42.0, screen_width - 42.0), -44.0)
	else:
		enemy.position = at_position
	enemy.connect("destroyed", Callable(self, "_on_enemy_destroyed"))
	add_child(enemy)

	if enemy.has_method("configure_variant"):
		enemy.call("configure_variant", variant, int(_elapsed / difficulty_step))
	return enemy

func _choose_enemy_variant() -> StringName:
	var roll := randf()
	if _elapsed > 35.0 and roll > 0.78:
		return &"bruiser"
	if _elapsed > 18.0 and roll > 0.58:
		return &"zigzag"
	if roll < 0.28:
		return &"scout"
	return &"fighter"

func spawn_boss() -> Node:
	if game_over or _boss_active or boss_scene == null:
		return null
	_boss_active = true
	spawn_timer.stop()

	var boss = boss_scene.instantiate()
	boss.position = Vector2(get_viewport_rect().size.x * 0.5, 96.0)
	boss.connect("destroyed", Callable(self, "_on_boss_destroyed"))
	if boss.has_signal("health_changed"):
		boss.connect("health_changed", Callable(self, "_on_boss_health_changed"))
	if boss.has_signal("warning"):
		boss.connect("warning", Callable(self, "_on_boss_warning"))
	add_child(boss)
	_show_boss_ui(true)
	return boss

func _on_boss_health_changed(current_health: float, max_health: float) -> void:
	if max_health <= 0.0:
		return
	_boss_bar.value = clampf(current_health / max_health, 0.0, 1.0)

func _on_boss_warning(message: String) -> void:
	_perk_label.text = message
	_perk_label_time = 1.2

func _on_boss_destroyed(points: int, at_position: Vector2) -> void:
	_boss_active = false
	_show_boss_ui(false)
	if not game_over:
		spawn_timer.start()
	_add_score(points)
	_spawn_explosion(at_position, 96.0, Color(1.0, 0.25, 0.08, 1.0))
	_drop_powerup(at_position, STRONG_POWERUP_KINDS[randi() % STRONG_POWERUP_KINDS.size()])

func _show_boss_ui(show_ui: bool) -> void:
	if show_ui:
		_boss_label.show()
		_boss_bar.value = 1.0
		_boss_bar.show()
	else:
		_boss_label.hide()
		_boss_bar.hide()

func _on_powerup_timer_timeout() -> void:
	if game_over or powerup_scene == null:
		return
	if get_tree().get_nodes_in_group("powerups").size() >= max_powerups:
		return

	var screen_width := get_viewport_rect().size.x
	_drop_powerup(Vector2(randf_range(54.0, screen_width - 54.0), -36.0), _choose_powerup())

func _choose_powerup() -> StringName:
	return POWERUP_KINDS[randi() % POWERUP_KINDS.size()]

func _try_drop_powerup(at_position: Vector2, points: int) -> void:
	var chance := 0.08
	if points >= 5:
		chance = 0.15
	if randf() <= chance:
		_drop_powerup(at_position, _choose_powerup())

func _drop_powerup(at_position: Vector2, kind: StringName) -> void:
	if powerup_scene == null:
		return
	if get_tree().get_nodes_in_group("powerups").size() >= max_powerups:
		return
	var powerup = powerup_scene.instantiate()
	powerup.position = at_position
	if powerup.has_method("configure"):
		powerup.call("configure", kind)
	add_child(powerup)

func _on_enemy_destroyed(points: int, at_position: Vector2) -> void:
	_add_score(points)
	_spawn_explosion(at_position, 46.0, Color(1.0, 0.45, 0.12, 1.0))
	_try_drop_powerup(at_position, points)

func _add_score(base_points: int) -> void:
	_combo_kills += 1
	_combo_timer = _combo_window
	var earned := base_points * _combo_multiplier()
	score += earned
	_update_score_label()
	_update_combo_label()

func _combo_multiplier() -> int:
	if _combo_kills >= 10:
		return 4
	if _combo_kills >= 6:
		return 3
	if _combo_kills >= 3:
		return 2
	return 1

func _on_player_hit(lives_left: int) -> void:
	_update_lives_label(lives_left)

func _on_player_lives_changed(lives_left: int) -> void:
	_update_lives_label(lives_left)

func _on_player_powerup_applied(label: String, duration: float) -> void:
	if duration > 0.0:
		_perk_label.text = "%s  %.0fs" % [label, duration]
	else:
		_perk_label.text = label
	_perk_label_time = 2.0

func _on_player_bomb_requested(at_position: Vector2, damage: float) -> void:
	_spawn_explosion(at_position, 160.0, Color(1.0, 0.86, 0.25, 1.0))
	for area in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(area) and area.has_method("take_bullet_hit"):
			area.call("take_bullet_hit", damage)

func spawn_player_bullet(at_position: Vector2, direction: Vector2) -> bool:
	if _active_player_bullets >= max_player_bullets:
		return false
	var bullet := _take_projectile(
		_player_bullet_pool,
		player_bullet_scene,
		max_player_bullets,
		_active_player_bullets,
		Callable(self, "_on_player_bullet_released")
	)
	if bullet == null:
		return false
	_active_player_bullets += 1
	bullet.call("activate", at_position, direction)
	return true

func spawn_enemy_bullet(at_position: Vector2, direction: Vector2, bullet_speed: float = -1.0) -> bool:
	if _active_enemy_bullets >= max_enemy_bullets:
		return false
	var bullet := _take_projectile(
		_enemy_bullet_pool,
		enemy_bullet_scene,
		max_enemy_bullets,
		_active_enemy_bullets,
		Callable(self, "_on_enemy_bullet_released")
	)
	if bullet == null:
		return false
	_active_enemy_bullets += 1
	if bullet_speed > 0.0:
		bullet.set("speed", bullet_speed)
	else:
		bullet.set("speed", default_enemy_bullet_speed)
	bullet.call("activate", at_position, direction)
	return true

func spawn_player_rocket(at_position: Vector2) -> bool:
	if _active_player_rockets >= max_player_rockets:
		return false
	var rocket := _take_projectile(
		_rocket_pool,
		rocket_scene,
		max_player_rockets,
		_active_player_rockets,
		Callable(self, "_on_player_rocket_released")
	)
	if rocket == null:
		return false
	_active_player_rockets += 1
	rocket.call("activate", at_position)
	return true

func _prewarm_projectiles() -> void:
	_prewarm_projectile_pool(player_bullet_scene, _player_bullet_pool, initial_player_bullet_pool, Callable(self, "_on_player_bullet_released"))
	_prewarm_projectile_pool(enemy_bullet_scene, _enemy_bullet_pool, initial_enemy_bullet_pool, Callable(self, "_on_enemy_bullet_released"))
	_prewarm_projectile_pool(rocket_scene, _rocket_pool, initial_rocket_pool, Callable(self, "_on_player_rocket_released"))

func _prewarm_projectile_pool(scene: PackedScene, pool: Array[Node], count: int, released_callback: Callable) -> void:
	if scene == null:
		return
	for i in count:
		var projectile := _create_pooled_projectile(scene, released_callback)
		if projectile != null:
			pool.append(projectile)

func _take_projectile(pool: Array[Node], scene: PackedScene, max_total: int, active_count: int, released_callback: Callable) -> Node:
	while not pool.is_empty():
		var projectile: Node = pool.pop_back()
		if is_instance_valid(projectile):
			return projectile
	if scene == null:
		return null
	var total := pool.size() + active_count
	if total >= max_total:
		return null
	return _create_pooled_projectile(scene, released_callback)

func _create_pooled_projectile(scene: PackedScene, released_callback: Callable) -> Node:
	var projectile = scene.instantiate()
	if projectile == null:
		return null
	projectile.set("active_on_ready", false)
	projectile.set("pooled", true)
	add_child(projectile)
	if projectile.has_signal("released"):
		projectile.connect("released", released_callback)
	if projectile.has_method("deactivate"):
		projectile.call("deactivate")
	return projectile

func _on_player_bullet_released(projectile: Node) -> void:
	_active_player_bullets = max(_active_player_bullets - 1, 0)
	if is_instance_valid(projectile):
		_player_bullet_pool.append(projectile)

func _on_enemy_bullet_released(projectile: Node) -> void:
	_active_enemy_bullets = max(_active_enemy_bullets - 1, 0)
	if is_instance_valid(projectile):
		_enemy_bullet_pool.append(projectile)

func _on_player_rocket_released(projectile: Node) -> void:
	_active_player_rockets = max(_active_player_rockets - 1, 0)
	if is_instance_valid(projectile):
		_rocket_pool.append(projectile)

func _prewarm_explosions() -> void:
	if explosion_scene == null:
		return
	for i in initial_explosion_pool:
		var explosion = explosion_scene.instantiate()
		explosion.set("active_on_ready", false)
		explosion.set("pooled", true)
		add_child(explosion)
		if explosion.has_signal("released"):
			explosion.connect("released", Callable(self, "_on_explosion_released"))
		if explosion.has_method("deactivate"):
			explosion.call("deactivate")
		_explosion_pool.append(explosion)

func _spawn_explosion(at_position: Vector2, radius: float, color: Color) -> void:
	if explosion_scene == null:
		return
	if get_tree().get_nodes_in_group("explosions").size() >= max_explosions:
		return
	var explosion: Node = null
	while not _explosion_pool.is_empty() and explosion == null:
		var candidate: Node = _explosion_pool.pop_back()
		if is_instance_valid(candidate):
			explosion = candidate
	if explosion == null:
		explosion = explosion_scene.instantiate()
		explosion.set("active_on_ready", false)
		explosion.set("pooled", true)
		add_child(explosion)
		if explosion.has_signal("released"):
			explosion.connect("released", Callable(self, "_on_explosion_released"))
	explosion.call("activate", at_position, radius, color)

func spawn_explosion(at_position: Vector2, radius: float, color: Color) -> void:
	_spawn_explosion(at_position, radius, color)

func _on_explosion_released(explosion: Node) -> void:
	if is_instance_valid(explosion):
		_explosion_pool.append(explosion)

func _on_player_died() -> void:
	game_over = true
	spawn_timer.stop()
	if _powerup_timer != null:
		_powerup_timer.stop()
	_update_lives_label(0)
	_spawn_explosion(player.global_position, 82.0, Color(0.35, 0.8, 1.0, 1.0))
	game_over_label.show()

func _update_score_label() -> void:
	score_label.text = "Score: %d" % score

func _update_lives_label(n: int) -> void:
	lives_label.text = "Lives: %d" % n

func _update_combo_label() -> void:
	if _combo_kills <= 1:
		_combo_label.text = ""
	else:
		_combo_label.text = "Combo %d  x%d" % [_combo_kills, _combo_multiplier()]
