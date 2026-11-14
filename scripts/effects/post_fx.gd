class_name PostFX
extends CanvasLayer

const SHADER := preload("res://shaders/post_fx.gdshader")

const GRADES := {
	&"heap": [Vector3(0.95, 1.0, 1.04), Vector3(1.04, 1.0, 0.95), 1.02],
	&"cave": [Vector3(0.9, 0.95, 1.12), Vector3(1.1, 1.0, 0.88), 0.96],
	&"intake": [Vector3(1.0, 0.97, 0.98), Vector3(1.05, 1.0, 0.93), 1.0],
	&"underworks": [Vector3(0.9, 1.04, 1.0), Vector3(1.1, 1.0, 0.86), 0.98],
}

var _rect: ColorRect
var _mat: ShaderMaterial
var _flash := 0.0


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)
	apply_settings()


func apply_settings() -> void:
	_mat.set_shader_parameter("enabled", 1.0 if Fx.post_enabled else 0.0)


func set_grade(key: StringName) -> void:
	var g: Array = GRADES.get(key, GRADES[&"heap"])
	_mat.set_shader_parameter("shadow_tint", g[0])
	_mat.set_shader_parameter("highlight_tint", g[1])
	_mat.set_shader_parameter("saturation", g[2])


func hit() -> void:
	if Fx.flashes_enabled:
		_flash = 1.0


func set_low_health(on: bool) -> void:
	_mat.set_shader_parameter("low_health", 1.0 if on and Fx.flashes_enabled else 0.0)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.5, 0.0)
		_mat.set_shader_parameter("hit_flash", _flash)
