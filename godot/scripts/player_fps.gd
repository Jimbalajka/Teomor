extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.8
@export var crouch_speed: float = 2.2
@export var jump_velocity: float = 4.8
@export var gravity: float = 9.8
@export var mouse_sensitivity: float = 0.0025
@export var interact_distance: float = 2.8
@export var stand_height: float = 1.6
@export var crouch_height: float = 1.0
@export var stand_cam_y: float = 0.7
@export var crouch_cam_y: float = 0.38

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractRay
@onready var prompt: Label = $PromptLayer/Prompt
@onready var controls_hint: Label = $PromptLayer/ControlsHint
@onready var body_col: CollisionShape3D = $Collision

var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _current_target: Node = null
var _crouching: bool = false
var _wish_crouch: bool = false


func _ready() -> void:
	if not _input_blocked():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ray.target_position = Vector3(0, 0, -interact_distance)
	prompt.visible = false
	if controls_hint:
		controls_hint.visible = true
		controls_hint.text = "WASD ход · Shift бег · Ctrl присед · Пробел прыжок · E · I инвентарь · K навыки · Esc мышь"
	_apply_stance(false, true)
	floor_snap_length = 0.15


func _dialogue() -> Node:
	return get_node_or_null("/root/Dialogue")


func _dialogue_open() -> bool:
	var dlg := _dialogue()
	return dlg != null and dlg.has_method("is_open") and bool(dlg.call("is_open"))


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _input_blocked() -> bool:
	var gs := _game_state()
	if gs != null and bool(gs.get("input_locked")):
		return true
	return _dialogue_open()


func _unhandled_input(event: InputEvent) -> void:
	if _input_blocked():
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_try_jump()


func _try_jump() -> void:
	if _input_blocked():
		return
	if not is_on_floor():
		return
	if _crouching:
		# stand then jump next frame if headroom; for now block crouch-jump
		return
	velocity.y = jump_velocity


func _physics_process(delta: float) -> void:
	if _input_blocked():
		velocity = Vector3.ZERO
		move_and_slide()
		_update_prompt(null)
		return

	_wish_crouch = Input.is_key_pressed(KEY_CTRL)
	_update_crouch()

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

	var sprinting := Input.is_key_pressed(KEY_SHIFT) and not _crouching and input_dir != Vector2.ZERO
	var speed := walk_speed
	if _crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed

	var basis_yaw := Basis(Vector3.UP, _look_yaw)
	var move := (basis_yaw.x * input_dir.x + basis_yaw.z * input_dir.y)
	velocity.x = move.x * speed
	velocity.z = move.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	_scan_interact()


func _update_crouch() -> void:
	if _wish_crouch and not _crouching:
		_apply_stance(true)
	elif not _wish_crouch and _crouching:
		if _can_stand():
			_apply_stance(false)


func _can_stand() -> bool:
	# Short ray/shape check upward from crouch capsule top.
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var shape := body_col.shape as CapsuleShape3D
	if shape == null:
		return true
	var rise := (stand_height - crouch_height) * 0.5 + 0.05
	var params := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = shape.radius * 0.95
	probe.height = stand_height
	params.shape = probe
	params.transform = global_transform.translated(Vector3(0, rise, 0))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	var hits := space.intersect_shape(params, 1)
	return hits.is_empty()


func _apply_stance(crouch: bool, force: bool = false) -> void:
	if _crouching == crouch and not force:
		return
	_crouching = crouch
	var shape := body_col.shape as CapsuleShape3D
	if shape == null:
		shape = CapsuleShape3D.new()
		body_col.shape = shape
	shape.radius = 0.28
	shape.height = crouch_height if crouch else stand_height
	# Keep capsule centered on character origin (feet roughly at -height/2).
	body_col.position = Vector3(0, shape.height * 0.5, 0)
	var target_cam_y := crouch_cam_y if crouch else stand_cam_y
	if force:
		camera.position.y = target_cam_y
	else:
		var tw := create_tween()
		tw.tween_property(camera, "position:y", target_cam_y, 0.12)


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
