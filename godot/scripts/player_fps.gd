extends CharacterBody3D

@export var speed: float = 4.0
@export var mouse_sensitivity: float = 0.0025
@export var interact_distance: float = 2.8

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractRay
@onready var prompt: Label = $PromptLayer/Prompt

var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _current_target: Node = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ray.target_position = Vector3(0, 0, -interact_distance)
	prompt.visible = false


func _dialogue() -> Node:
	return get_node_or_null("/root/Dialogue")


func _dialogue_open() -> bool:
	var dlg := _dialogue()
	return dlg != null and dlg.has_method("is_open") and bool(dlg.call("is_open"))


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_open():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_yaw -= event.relative.x * mouse_sensitivity
		_look_pitch -= event.relative.y * mouse_sensitivity
		_look_pitch = clampf(_look_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		rotation.y = _look_yaw
		camera.rotation.x = _look_pitch
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_try_interact()


func _physics_process(delta: float) -> void:
	if _dialogue_open():
		velocity = Vector3.ZERO
		move_and_slide()
		_update_prompt(null)
		return

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	var basis_yaw := Basis(Vector3.UP, _look_yaw)
	var move := (basis_yaw.x * input_dir.x + basis_yaw.z * input_dir.y)
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_scan_interact()


func _scan_interact() -> void:
	ray.force_raycast_update()
	if ray.is_colliding():
		var collider := ray.get_collider() as Node
		var target := _resolve_interactable(collider)
		_update_prompt(target)
	else:
		_update_prompt(null)


func _resolve_interactable(node: Node) -> Node:
	var n := node
	while n:
		if n.has_method("interact") and n.is_in_group("interactable"):
			return n
		n = n.get_parent()
	return null


func _update_prompt(target: Node) -> void:
	_current_target = target
	if target and target.has_method("get_prompt"):
		prompt.text = str(target.call("get_prompt"))
		prompt.visible = true
	elif target:
		prompt.text = "[E] Взаимодействовать"
		prompt.visible = true
	else:
		prompt.visible = false


func _try_interact() -> void:
	if _current_target and _current_target.has_method("interact"):
		_current_target.call("interact")
