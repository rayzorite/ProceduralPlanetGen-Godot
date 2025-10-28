@tool
extends Camera3D

@export var target: Node3D
@export_range(0.5, 50.0) var distance: float = 10.0
@export_range(0.1, 10.0) var zoom_speed: float = 2.0
@export_range(0.1, 2.0) var rotate_speed: float = 0.3
@export_range(1.0, 100.0) var min_distance: float = 2.0
@export_range(5.0, 200.0) var max_distance: float = 50.0

var _rotation_x := 0.0
var _rotation_y := 0.0
var _dragging := false
var _last_mouse_pos := Vector2.ZERO


func _ready():
	if target == null:
		push_warning("⚠️ Camera target not set. Assign a Node3D (e.g. your planet).")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			_last_mouse_pos = event.position
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _dragging else Input.MOUSE_MODE_VISIBLE)

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(distance - zoom_speed, min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(distance + zoom_speed, max_distance)

	elif event is InputEventMouseMotion and _dragging:
		var delta = event.relative
		_rotation_x += delta.y * rotate_speed * 0.01
		_rotation_y -= delta.x * rotate_speed * 0.01
		_rotation_x = clamp(_rotation_x, -PI / 2.0 + 0.1, PI / 2.0 - 0.1)


func _process(_delta):
	if target == null:
		return

	var target_pos = target.global_transform.origin
	var rot = Basis()
	rot = rot.rotated(Vector3.UP, _rotation_y)
	rot = rot.rotated(rot.x, _rotation_x)

	global_transform.origin = target_pos + rot.z * -distance
	look_at(target_pos, Vector3.UP)
