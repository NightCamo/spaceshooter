extends Area2D

## Player bullet. Supports angled shots for spread-shot powerups.

@export var speed: float = 760.0
@export var active_on_ready: bool = true
@export var pooled: bool = false

signal released(projectile: Node)

var _active: bool = false
var _direction: Vector2 = Vector2.UP
var _screen_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("bullets")
	area_entered.connect(_on_area_entered)
	if active_on_ready:
		activate(global_position, _direction)
	else:
		deactivate()

func activate(at_position: Vector2, direction: Vector2) -> void:
	global_position = at_position
	_screen_size = get_viewport_rect().size
	_active = true
	show()
	monitoring = true
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
	rotation = _direction.angle() + PI / 2.0

func _process(delta: float) -> void:
	if not _active:
		return
	position += _direction * speed * delta
	if position.y < -60.0 or position.y > _screen_size.y + 60.0 or position.x < -60.0 or position.x > _screen_size.x + 60.0:
		release()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if area.has_method("take_bullet_hit"):
			area.call("take_bullet_hit", 1)
		elif area.has_method("explode"):
			area.call("explode")
		release()
