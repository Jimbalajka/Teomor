extends OmniLight3D

## Soft diegetic flicker — lamp/candle, not disco.
@export var base_energy: float = 1.0
@export var amplitude: float = 0.12
@export var speed: float = 1.35
@export var secondary_amp: float = 0.05
@export var secondary_speed: float = 3.1

var _t: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	if base_energy <= 0.0:
		base_energy = light_energy
	_phase = float(get_instance_id() % 97) * 0.17


func _process(delta: float) -> void:
	_t += delta
	var wobble := sin((_t + _phase) * speed) * amplitude
	wobble += sin((_t + _phase) * secondary_speed + 1.7) * secondary_amp
	light_energy = maxf(base_energy + wobble, 0.05)
