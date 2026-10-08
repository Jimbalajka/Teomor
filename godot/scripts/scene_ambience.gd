extends Node

## Placeholder underground bed + rare drips/creaks.
@export var drip_path: String = "res://assets/audio/sfx_drip.wav"
@export var creak_path: String = "res://assets/audio/sfx_wood_creak.wav"
@export var drip_min: float = 2.8
@export var drip_max: float = 7.5

var _drip: AudioStreamPlayer
var _creak: AudioStreamPlayer
var _timer: float = 2.0


func _ready() -> void:
	_drip = AudioStreamPlayer.new()
	_drip.name = "DripPlayer"
	_drip.volume_db = -10.0
	_drip.bus = "Master"
	var ds := load(drip_path)
	if ds != null:
		_drip.stream = ds
	add_child(_drip)
	_creak = AudioStreamPlayer.new()
	_creak.name = "CreakPlayer"
	_creak.volume_db = -14.0
	var cs := load(creak_path)
	if cs != null:
		_creak.stream = cs
	add_child(_creak)
	_timer = randf_range(drip_min, drip_max)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(drip_min, drip_max)
	if randf() < 0.72:
		if _drip.stream != null and not _drip.playing:
			_drip.pitch_scale = randf_range(0.85, 1.15)
			_drip.play()
	else:
		if _creak.stream != null and not _creak.playing:
			_creak.pitch_scale = randf_range(0.9, 1.08)
			_creak.play()
