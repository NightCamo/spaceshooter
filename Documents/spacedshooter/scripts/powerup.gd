extends Area2D

## Falling collectible perk.

@export_enum("rapid", "spread", "shield", "speed", "life", "bomb", "laser_reset", "rocket_boost") var kind: String = "rapid"
@export var fall_speed: float = 118.0

const POWERUP_DATA := {
	"rapid": {"label": "R", "color": Color(1.0, 0.75, 0.15, 1.0)},
	"spread": {"label": "S", "color": Color(0.35, 0.85, 1.0, 1.0)},
	"shield": {"label": "D", "color": Color(0.25, 0.95, 0.65, 1.0)},
	"speed": {"label": "V", "color": Color(1.0, 0.35, 0.85, 1.0)},
	"life": {"label": "+", "color": Color(0.9, 1.0, 0.35, 1.0)},
	"bomb": {"label": "B", "color": Color(1.0, 0.42, 0.1, 1.0)},
	"laser_reset": {"label": "L", "color": Color(0.25, 1.0, 0.95, 1.0)},
	"rocket_boost": {"label": "K", "color": Color(1.0, 0.9, 0.25, 1.0)},
}

@onready var glow: Polygon2D = $Glow
@onready var core: Polygon2D = $Core
@onready var label: Label = $Label

var _despawn_y: float = 720.0

func _ready() -> void:
	add_to_group("powerups")
	_despawn_y = get_viewport_rect().size.y + 50.0
	area_entered.connect(_on_area_entered)
	_apply_style()

func configure(new_kind: StringName) -> void:
	kind = String(new_kind)
	if is_inside_tree():
		_apply_style()

func _process(delta: float) -> void:
	position.y += fall_speed * delta
	rotation += delta * 1.35
	var pulse := 0.88 + 0.12 * sin(Time.get_ticks_msec() / 95.0)
	core.scale = Vector2.ONE * pulse
	if position.y > _despawn_y:
		queue_free()

func _apply_style() -> void:
	var data: Dictionary = POWERUP_DATA.get(kind, POWERUP_DATA["rapid"])
	var color: Color = data["color"]
	core.color = color
	glow.color = Color(color.r, color.g, color.b, 0.24)
	label.text = String(data["label"])
	label.add_theme_color_override("font_color", Color.WHITE)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player") and area.has_method("apply_powerup"):
		area.call("apply_powerup", StringName(kind))
		queue_free()
