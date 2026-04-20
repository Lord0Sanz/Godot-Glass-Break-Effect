extends ColorRect

## How long the crack stays visible before disappearing (seconds)
@export var crack_duration: float = 1.0
## Strength of refraction/distortion effect
@export var refraction_strength: float = 4.0
## Amount of blur around crack lines
@export var blur_amount: float = 1.2
## Tint strength of the glass material
@export var glass_tint: float = 0.06
## Glow intensity of the crack
@export var crack_glow: float = 0.8
## Number of crack points (higher = more complex cracks)
@export var point_count: int = 50
@export_range(100, 1000) var crack_radius: float = 700.0
@export_range(0.1, 3.0) var crack_thickness: float = 1.0
## Sound when cracking
@export var crack_sound: AudioStreamPlayer = null

var crack_timer: float = 0.0
var is_cracked: bool = false

func _ready():
	mouse_filter = MOUSE_FILTER_STOP
	_set_crack_visible(false)
	_update_shader_parameters()

func _update_shader_parameters():
	material.set_shader_parameter("refraction_strength", refraction_strength)
	material.set_shader_parameter("blur_amount", blur_amount)
	material.set_shader_parameter("glass_tint", glass_tint)
	material.set_shader_parameter("crack_glow", crack_glow)
	material.set_shader_parameter("point_count", point_count)
	material.set_shader_parameter("crack_radius", crack_radius)
	material.set_shader_parameter("crack_thickness", crack_thickness)

@warning_ignore("shadowed_variable_base_class")
func _set_crack_visible(visible: bool):
	material.set_shader_parameter("show_crack", visible)
	if not visible:
		is_cracked = false

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			_show_crack(event.position)

func _show_crack(_pos: Vector2):
	var screen_pos = get_viewport().get_mouse_position()
	
	# Reset timer
	crack_timer = crack_duration
	is_cracked = true
	
	# Play crack sound if assigned
	if crack_sound:
		crack_sound.play()
	
	# Update shader parameters
	material.set_shader_parameter("click_position", screen_pos)
	material.set_shader_parameter("show_crack", true)

func _process(delta):
	if is_cracked:
		crack_timer -= delta
		
		# Remove crack when timer expires
		if crack_timer <= 0.0:
			_set_crack_visible(false)

## Public API: Manually trigger a crack
func trigger_crack():
	_show_crack(Vector2.ZERO)

## Public API: Check if glass is currently cracked
func is_cracked_state() -> bool:
	return is_cracked
