extends Area2D

## Enemy bullet. Supports angled fire for enemy variants.

@export var speed: float = 350.0
@export var active_on_ready: bool = true
@export var pooled: bool = false

signal released(projectile: Node)

var _active: bool = false
var _direction: Vector2 = Vector2.DOWN
var _screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy_bullets")
	if active_on_ready:
		activate(global_position, _direction)
	else:
		deactivate()

func activate(at_position: Vector2, direction: Vector2) -> void:
	global_position = at_position
	_screen_size = get_viewport_rect().size
	_active = true
	show()
	monitoring = false
	monitorable = true
	set_process(true)
	set_direction(direction)

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

func set_direction(direction: Vector2) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle() - PI / 2.0

func _process(delta: float) -> void:
	if not _active:
		return
	position += _direction * speed * delta
	if position.y > _screen_size.y + 50.0 or position.y < -50.0 or position.x < -50.0 or position.x > _screen_size.x + 50.0:
		release()
