@tool
class_name Prop
extends Node2D
## A piece of set dressing: a pixel-art sprite (optionally animated) with an
## optional additive glow for anything that gives off light.
## The node's position is the sprite's BOTTOM-CENTRE, so props sit on the
## ground by placing them at the floor's y.
## lit_when_quest: frame 0 until that quest is turned in, then frame 1
## (used for Tinker's generator and the camp lights).

const GLOW := preload("res://art/fx/glow.png")

@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
@export var frames := 1:
	set(v):
		frames = maxi(v, 1)
		queue_redraw()
@export var fps := 0.0
## Hanging props (cave roof junk) are anchored at their TOP-centre instead.
@export var hanging := false:
	set(v):
		hanging = v
		queue_redraw()
@export var flip := false:
	set(v):
		flip = v
		queue_redraw()
## Background props are dimmed slightly so they never read as something you
## can stand on or interact with.
@export var background := false:
	set(v):
		background = v
		self_modulate = Color(0.72, 0.7, 0.78) if v else Color.WHITE
@export_group("Light")
@export var glow_color := Color(1, 0.8, 0.5, 0.0)
@export var glow_radius := 0.0
@export var glow_offset := Vector2.ZERO
@export var glow_flicker := 0.0
## Real light cast on the surroundings (0 = none). Uses glow_color.
@export var light_radius := 0.0
@export var light_energy := 0.9
## Light only while frame 0 is showing (blinking warning lamps).
@export var light_on_frame_zero := false
@export_group("Particles")
@export_enum("none", "embers", "smoke", "sparks", "trickle") var emit := "none"
@export var emit_offset := Vector2.ZERO
@export_group("Story state")
@export var lit_when_quest: StringName

var _t := 0.0
var _frame := 0
var _glow: Sprite2D
var _light: PointLight2D
var _emitter: CPUParticles2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_t = randf() * 10.0
	if Fx.art_variant != "" and texture:
		# a palette-matched copy for the art variant being trialled, if one exists
		var alt := texture.resource_path.get_base_dir() + "/" + Fx.art_variant + "/" + texture.resource_path.get_file()
		if ResourceLoader.exists(alt):
			texture = load(alt)
	if glow_radius > 0.0 and glow_color.a > 0.0:
		_glow = Sprite2D.new()
		_glow.texture = GLOW
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = mat
		_glow.modulate = Color(glow_color, glow_color.a * 0.6) # bloom does the rest
		_glow.scale = Vector2.ONE * (glow_radius / 32.0)
		_glow.position = glow_offset
		add_child(_glow)
	if light_radius > 0.0:
		_light = Fx.make_light(Color(glow_color, 1.0), light_radius, light_energy)
		_light.position = glow_offset
		add_child(_light)
	match emit:
		"embers": _emitter = FxParticles.embers()
		"smoke": _emitter = FxParticles.smoke()
		"sparks": _emitter = FxParticles.sparks()
		"trickle": _emitter = FxParticles.trickle(Color(0.7, 0.62, 0.5, 0.7))
	if _emitter:
		_emitter.position = emit_offset
		add_child(_emitter)
		_emitter.emitting = true
	_apply_story_state()


func _apply_story_state() -> void:
	if lit_when_quest == &"":
		return
	var lit := QuestManager.get_state(lit_when_quest) == GameState.QuestState.TURNED_IN
	_frame = 1 if lit else 0
	if _glow:
		_glow.visible = lit
	if _light:
		_light.visible = lit
	if _emitter:
		_emitter.emitting = lit
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if lit_when_quest == &"" and fps > 0.0 and frames > 1:
		var f := int(_t * fps) % frames
		if f != _frame:
			_frame = f
			queue_redraw()
	var k := 1.0
	if glow_flicker > 0.0:
		k = 1.0 - glow_flicker * (0.5 + 0.5 * sin(_t * 23.0) * sin(_t * 7.0))
	if light_on_frame_zero:
		k = 1.0 if _frame == 0 else 0.0
	if _glow:
		_glow.modulate.a = glow_color.a * 0.6 * k
	if _light:
		_light.energy = light_energy * k


func _draw() -> void:
	if texture == null:
		return
	var fw := texture.get_width() / frames
	var h := texture.get_height()
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect_region(texture, Rect2(-fw / 2, 0 if hanging else -h, fw, h), Rect2(_frame * fw, 0, fw, h))
