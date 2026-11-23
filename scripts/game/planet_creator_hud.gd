class_name PlanetCreatorHUD
extends CanvasLayer

# PlanetCreatorHUD.gd
# Interface de Criação e Pintura de Mundos inspirada no WorldBox:
# - Paleta de camadas de terrenos (Oceano, Areia, Grama, Floresta, Colinas, Montanhas, Picos, etc.)
# - Ferramentas de modelagem e escultura (Pintar, Elevar, Cavar, Suavizar, Planar, Preencher, Conta-gotas)
# - Pincéis estilo WorldBox: tamanhos rápidos (1x, 2x, 4x, 8x) e formatos (Suave, Nítido, Orgânico)
# - Camada de Oceanos 3D e Nível do Mar
# - Gerador de Mundos Procedurais com Presets
# - Menu de Pausa In-Game no Esc (sem sair da rodada)

@export var controller: PlanetCreatorController
@export var planet: PlanetMesh

# Barra Superior
@onready var main_hud_container: Control = %MainHUDContainer
@onready var top_bar_wrapper: Control = %TopBarWrapper
@onready var top_bar: PanelContainer = %TopBar
@onready var btn_toggle_top_bar: Button = %BtnToggleTopBar
@onready var planet_name_edit: LineEdit = %PlanetNameEdit
@onready var planet_type_badge: Label = %PlanetTypeBadge
@onready var stats_label: Label = %StatsLabel
@onready var toast_label: Label = %ToastLabel
@onready var photo_mode_hint: Label = %PhotoModeHint

@onready var btn_undo: Button = %BtnUndo
@onready var btn_redo: Button = %BtnRedo
@onready var btn_open_world_gen: Button = %BtnOpenWorldGen
@onready var btn_photo_mode: Button = %BtnPhotoMode
@onready var btn_open_pause: Button = %BtnOpenPause

# Paleta de Terrenos (WorldBox Drawing Layers)
@onready var terrains_container: Container = %TerrainsContainer

# Ferramentas de Desenho / Escultura
@onready var btn_mode_paint: Button = %BtnModePaint
@onready var btn_mode_elevate: Button = %BtnModeElevate
@onready var btn_mode_carve: Button = %BtnModeCarve
@onready var btn_mode_smooth: Button = %BtnModeSmooth
@onready var btn_mode_flatten: Button = %BtnModeFlatten
@onready var btn_mode_fill: Button = %BtnModeFill
@onready var btn_mode_eyedropper: Button = %BtnModeEyedropper

# Tamanhos Rápidos WorldBox
@onready var btn_size_dec: Button = %BtnSizeDec
@onready var btn_size_1: Button = %BtnSize1
@onready var btn_size_2: Button = %BtnSize2
@onready var btn_size_4: Button = %BtnSize4
@onready var btn_size_8: Button = %BtnSize8
@onready var btn_size_inc: Button = %BtnSizeInc

# Formatos de Pincel
@onready var btn_shape_smooth: Button = %BtnShapeSmooth
@onready var btn_shape_hard: Button = %BtnShapeHard
@onready var btn_shape_noise: Button = %BtnShapeNoise

# Sliders
@onready var radius_slider: HSlider = %RadiusSlider
@onready var radius_val_label: Label = %RadiusValLabel
@onready var strength_slider: HSlider = %StrengthSlider
@onready var strength_val_label: Label = %StrengthValLabel

# Controles de Tamanho do Planeta
@onready var btn_planet_size_dec: Button = %BtnPlanetSizeDec
@onready var planet_size_val_btn: Button = %PlanetSizeValBtn
@onready var btn_planet_size_inc: Button = %BtnPlanetSizeInc

# Oceanos
@onready var ocean_check: CheckButton = %OceanCheck
@onready var sea_level_slider: HSlider = %SeaLevelSlider

# Tooltip Flutuante Instantâneo
@onready var hover_tooltip: PanelContainer = %HoverTooltip
@onready var hover_tooltip_label: Label = %HoverTooltipLabel

# Menu de Pausa In-Game
@onready var pause_menu_modal: Control = %PauseMenuModal
@onready var btn_close_pause: Button = %BtnClosePause
@onready var btn_pause_resume: Button = %BtnPauseResume
@onready var btn_pause_new_world: Button = %BtnPauseNewWorld
@onready var btn_pause_save: Button = %BtnPauseSave
@onready var btn_pause_load: Button = %BtnPauseLoad
@onready var btn_pause_settings: Button = %BtnPauseSettings
@onready var btn_pause_quit: Button = %BtnPauseQuit

# Gerador de Mundos
@onready var world_gen_modal: Control = %WorldGenModal
@onready var btn_close_world_gen: Button = %BtnCloseWorldGen
@onready var btn_gen_random: Button = %BtnGenRandom
@onready var world_presets_container: HFlowContainer = %WorldPresetsContainer

# Configurações
@onready var settings_modal: Control = %SettingsModal
@onready var settings_menu_inst: SettingsMenu = %SettingsMenuInst

const TEX_BTN_NORMAL = preload("res://resources/ui/btn_dark.png")
const TEX_BTN_HOVER = preload("res://resources/ui/btn_dark_hover.png")
const TEX_BTN_PRESSED = preload("res://resources/ui/btn_dark_pressed.png")
const TEX_BTN_ACTIVE = preload("res://resources/ui/btn_dark_active.png")

var _terrain_buttons: Dictionary = {}
var _tool_buttons: Dictionary = {}
var _shape_buttons: Dictionary = {}
var _size_buttons: Dictionary = {}
var _top_bar_open: bool = true

func _ready() -> void:
	_setup_hover_tooltip()
	_setup_top_bar_toggle()
	_setup_history_buttons()
	_setup_worldbox_terrains()
	_setup_tool_buttons()
	_setup_brush_sizes()
	_setup_brush_shapes()
	_setup_sliders()
	_setup_planet_size_controls()
	_setup_oceans()
	_setup_world_gen_modal()
	_setup_pause_menu_modal()
	_setup_settings_modal()
	_connect_planet_signals()

	photo_mode_hint.visible = false
	toast_label.visible = false
	pause_menu_modal.visible = false
	world_gen_modal.visible = false
	settings_modal.visible = false

	# Seleciona ferramenta e terreno iniciais
	_select_tool("PAINT")
	_select_terrain("grass")
	_select_brush_size(0.25)

	btn_photo_mode.pressed.connect(func():
		SoundEffects.play_click()
		main_hud_container.visible = false
		photo_mode_hint.visible = true
	)
	btn_photo_mode.mouse_entered.connect(func(): SoundEffects.play_hover())

func _setup_hover_tooltip() -> void:
	if hover_tooltip:
		hover_tooltip.visible = false
		hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _attach_tooltip(ctrl: Control, text_content: String) -> void:
	if not ctrl:
		return
	ctrl.tooltip_text = text_content
	ctrl.mouse_entered.connect(func():
		_show_hover_tooltip(ctrl, text_content)
	)
	ctrl.mouse_exited.connect(func():
		_hide_hover_tooltip()
	)

func _show_hover_tooltip(ctrl: Control, text_content: String) -> void:
	if not hover_tooltip or not hover_tooltip_label:
		return
	if text_content.is_empty():
		hover_tooltip.visible = false
		return

	hover_tooltip_label.text = text_content
	hover_tooltip.reset_size()
	hover_tooltip.visible = true

	var ctrl_rect := ctrl.get_global_rect()
	var vp_size := get_viewport().get_visible_rect().size
	var tip_size := hover_tooltip.size

	var target_x: float = ctrl_rect.position.x + (ctrl_rect.size.x - tip_size.x) * 0.5
	target_x = clampf(target_x, 8.0, vp_size.x - tip_size.x - 8.0)

	var target_y: float = 0.0
	if ctrl_rect.position.y < vp_size.y * 0.4:
		target_y = ctrl_rect.position.y + ctrl_rect.size.y + 6.0
	else:
		target_y = ctrl_rect.position.y - tip_size.y - 6.0

	hover_tooltip.global_position = Vector2(target_x, target_y)

func _hide_hover_tooltip() -> void:
	if hover_tooltip:
		hover_tooltip.visible = false

func _setup_top_bar_toggle() -> void:
	if not btn_toggle_top_bar or not top_bar_wrapper:
		return
	btn_toggle_top_bar.pressed.connect(func():
		_toggle_top_bar()
	)
	btn_toggle_top_bar.mouse_entered.connect(func(): SoundEffects.play_hover())
	_attach_tooltip(btn_toggle_top_bar, "Ocultar Menu Superior")

func _toggle_top_bar() -> void:
	SoundEffects.play_click()
	_top_bar_open = not _top_bar_open
	var top_h: float = top_bar.size.y if top_bar else 50.0
	var target_y: float = 8.0 if _top_bar_open else -(top_h + 2.0)
	btn_toggle_top_bar.text = "▲" if _top_bar_open else "▼"
	var t_text: String = "Ocultar Menu Superior" if _top_bar_open else "Exibir Menu Superior"
	btn_toggle_top_bar.tooltip_text = t_text
	_show_hover_tooltip(btn_toggle_top_bar, t_text)

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(top_bar_wrapper, "position:y", target_y, 0.25)

func _setup_history_buttons() -> void:
	btn_undo.disabled = true
	btn_redo.disabled = true
	btn_undo.text = ""
	btn_undo.icon = preload("res://resources/ui/icon_undo.png")
	btn_undo.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_redo.text = ""
	btn_redo.icon = preload("res://resources/ui/icon_redo.png")
	btn_redo.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_attach_tooltip(btn_undo, "Desfazer (Ctrl+Z)")
	_attach_tooltip(btn_redo, "Refazer (Ctrl+Y)")

	btn_undo.pressed.connect(func():
		if planet and planet.can_undo():
			planet.undo()
			SoundEffects.play_click()
	)
	btn_undo.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_redo.pressed.connect(func():
		if planet and planet.can_redo():
			planet.redo()
			SoundEffects.play_click()
	)
	btn_redo.mouse_entered.connect(func(): SoundEffects.play_hover())

func _setup_worldbox_terrains() -> void:
	for child in terrains_container.get_children():
		child.queue_free()

	for key in PlanetMesh.WORLDBOX_TERRAINS.keys():
		var data: Dictionary = PlanetMesh.WORLDBOX_TERRAINS[key]
		var btn := Button.new()
		# Onde tem ícone, não mostra texto fixo no botão; apenas mostra no hover!
		btn.text = ""
		var icon_p: String = data.get("icon_path", "")
		if icon_p != "" and ResourceLoader.exists(icon_p):
			btn.icon = load(icon_p)
			btn.expand_icon = false
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(30, 28)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))

		var style := StyleBoxTexture.new()
		style.texture = TEX_BTN_NORMAL
		style.texture_margin_left = 6.0
		style.texture_margin_top = 6.0
		style.texture_margin_right = 6.0
		style.texture_margin_bottom = 6.0
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := StyleBoxTexture.new()
		hover_style.texture = TEX_BTN_HOVER
		hover_style.texture_margin_left = 6.0
		hover_style.texture_margin_top = 6.0
		hover_style.texture_margin_right = 6.0
		hover_style.texture_margin_bottom = 6.0
		hover_style.content_margin_left = 4.0
		hover_style.content_margin_right = 4.0
		hover_style.content_margin_top = 2.0
		hover_style.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("hover", hover_style)

		var press_style := StyleBoxTexture.new()
		press_style.texture = TEX_BTN_PRESSED
		press_style.texture_margin_left = 6.0
		press_style.texture_margin_top = 6.0
		press_style.texture_margin_right = 6.0
		press_style.texture_margin_bottom = 6.0
		press_style.content_margin_left = 4.0
		press_style.content_margin_right = 4.0
		press_style.content_margin_top = 3.0
		press_style.content_margin_bottom = 1.0
		btn.add_theme_stylebox_override("pressed", press_style)

		var t_name: String = str(data.get("name", key))
		_attach_tooltip(btn, t_name)

		btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		var cur_key: String = str(key)
		btn.pressed.connect(func():
			SoundEffects.play_click()
			_select_terrain(cur_key)
		)

		terrains_container.add_child(btn)
		_terrain_buttons[key] = btn

func _select_terrain(key: String) -> void:
	if controller:
		controller.current_element = key
	for k in _terrain_buttons.keys():
		var btn: Button = _terrain_buttons[k]
		var is_sel: bool = (k == key)
		var sb: StyleBoxTexture = btn.get_theme_stylebox("normal") as StyleBoxTexture
		if sb:
			var new_sb: StyleBoxTexture = sb.duplicate() as StyleBoxTexture
			new_sb.texture = TEX_BTN_ACTIVE if is_sel else TEX_BTN_NORMAL
			btn.add_theme_stylebox_override("normal", new_sb)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5) if is_sel else Color(0.95, 0.98, 1.0))

func _setup_tool_buttons() -> void:
	btn_mode_paint.icon = preload("res://resources/ui/icons/tool_paint.png")
	btn_mode_paint.text = ""
	btn_mode_paint.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_paint, "Pintar Terreno [1]")

	btn_mode_elevate.icon = preload("res://resources/ui/icons/tool_elevate.png")
	btn_mode_elevate.text = ""
	btn_mode_elevate.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_elevate, "Elevar Relevo [2]")

	btn_mode_carve.icon = preload("res://resources/ui/icons/tool_carve.png")
	btn_mode_carve.text = ""
	btn_mode_carve.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_carve, "Cavar Crateras [3]")

	btn_mode_smooth.icon = preload("res://resources/ui/icons/tool_smooth.png")
	btn_mode_smooth.text = ""
	btn_mode_smooth.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_smooth, "Suavizar Terreno [4]")

	btn_mode_flatten.icon = preload("res://resources/ui/icons/tool_flatten.png")
	btn_mode_flatten.text = ""
	btn_mode_flatten.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_flatten, "Planar / Platô [5]")

	btn_mode_fill.icon = preload("res://resources/ui/icons/tool_fill.png")
	btn_mode_fill.text = ""
	btn_mode_fill.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_fill, "Preencher Planeta [6]")

	btn_mode_eyedropper.icon = preload("res://resources/ui/icons/tool_eyedrop.png")
	btn_mode_eyedropper.text = ""
	btn_mode_eyedropper.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_mode_eyedropper, "Conta-gotas / Amostrador [I]")

	btn_open_world_gen.icon = preload("res://resources/ui/icons/icon_new_world.png")
	btn_open_world_gen.text = ""
	btn_open_world_gen.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_open_world_gen, "Criar Novo Planeta")

	btn_photo_mode.icon = preload("res://resources/ui/icons/icon_camera.png")
	btn_photo_mode.text = ""
	btn_photo_mode.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_photo_mode, "Modo Foto (Ocultar Interface)")

	btn_open_pause.icon = preload("res://resources/ui/icons/icon_gear.png")
	btn_open_pause.text = ""
	btn_open_pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attach_tooltip(btn_open_pause, "Menu de Pausa [Esc]")

	_tool_buttons = {
		"PAINT": btn_mode_paint,
		"ELEVATE": btn_mode_elevate,
		"CARVE": btn_mode_carve,
		"SMOOTH": btn_mode_smooth,
		"FLATTEN": btn_mode_flatten,
		"FILL": btn_mode_fill,
		"EYEDROPPER": btn_mode_eyedropper
	}

	for mode in _tool_buttons.keys():
		var btn: Button = _tool_buttons[mode]
		btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		var cur_mode: String = mode
		btn.pressed.connect(func():
			_select_tool(cur_mode)
		)

	if controller:
		controller.tool_mode_changed.connect(_on_tool_mode_changed)
		controller.element_picked.connect(_select_terrain)

func _select_tool(mode: String) -> void:
	if controller:
		controller.set_tool_mode(mode)
	_on_tool_mode_changed(mode)

func _on_tool_mode_changed(mode: String) -> void:
	for m in _tool_buttons.keys():
		var btn: Button = _tool_buttons[m]
		var is_sel: bool = (m == mode)
		var sb: StyleBoxTexture = btn.get_theme_stylebox("normal") as StyleBoxTexture
		if sb:
			var new_sb: StyleBoxTexture = sb.duplicate() as StyleBoxTexture
			new_sb.texture = TEX_BTN_ACTIVE if is_sel else TEX_BTN_NORMAL
			btn.add_theme_stylebox_override("normal", new_sb)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7) if is_sel else Color.WHITE)
		btn.modulate = Color(1.1, 1.1, 1.1) if is_sel else Color(0.9, 0.9, 0.9)

func _setup_brush_sizes() -> void:
	_size_buttons = {
		0.05: btn_size_1,
		0.12: btn_size_2,
		0.25: btn_size_4,
		0.55: btn_size_8
	}

	for size_val in _size_buttons.keys():
		var btn: Button = _size_buttons[size_val]
		var val: float = float(size_val)
		btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		btn.pressed.connect(func():
			SoundEffects.play_click()
			_select_brush_size(val)
		)

	if btn_size_dec:
		btn_size_dec.pressed.connect(func():
			_step_brush_size(-0.02)
		)
		btn_size_dec.mouse_entered.connect(func(): SoundEffects.play_hover())
		_attach_tooltip(btn_size_dec, "Diminuir Pincel ([)")

	if btn_size_inc:
		btn_size_inc.pressed.connect(func():
			_step_brush_size(0.02)
		)
		btn_size_inc.mouse_entered.connect(func(): SoundEffects.play_hover())
		_attach_tooltip(btn_size_inc, "Aumentar Pincel (])")

	_attach_tooltip(btn_size_1, "Tamanho Micro (0.05)")
	_attach_tooltip(btn_size_2, "Tamanho Pequeno (0.12)")
	_attach_tooltip(btn_size_4, "Tamanho Médio (0.25)")
	_attach_tooltip(btn_size_8, "Tamanho Grande (0.55)")

func _step_brush_size(amount: float) -> void:
	var cur: float = radius_slider.value if radius_slider else 0.25
	_select_brush_size(clampf(cur + amount, 0.04, 1.6))
	SoundEffects.play_click()

func _select_brush_size(val: float) -> void:
	if controller:
		controller.brush_radius = val
	radius_slider.value = val
	radius_val_label.text = "%.2f" % val

	for s in _size_buttons.keys():
		var btn: Button = _size_buttons[s]
		var active: bool = is_equal_approx(float(s), val)
		var sb: StyleBoxTexture = btn.get_theme_stylebox("normal") as StyleBoxTexture
		if sb:
			var new_sb: StyleBoxTexture = sb.duplicate() as StyleBoxTexture
			new_sb.texture = TEX_BTN_ACTIVE if active else TEX_BTN_NORMAL
			btn.add_theme_stylebox_override("normal", new_sb)
		btn.modulate = Color(1.15, 1.15, 1.15) if active else Color(0.85, 0.85, 0.85)

func _setup_brush_shapes() -> void:
	_shape_buttons = {
		"SMOOTH": btn_shape_smooth,
		"HARD": btn_shape_hard,
		"NOISE": btn_shape_noise
	}

	for shape in _shape_buttons.keys():
		var btn: Button = _shape_buttons[shape]
		btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		var cur_shape: String = shape
		btn.pressed.connect(func():
			SoundEffects.play_click()
			_select_brush_shape(cur_shape)
		)

	_select_brush_shape("SMOOTH")

func _select_brush_shape(shape: String) -> void:
	if controller:
		controller.brush_shape = shape
	for s in _shape_buttons.keys():
		var btn: Button = _shape_buttons[s]
		var active: bool = (s == shape)
		var sb: StyleBoxTexture = btn.get_theme_stylebox("normal") as StyleBoxTexture
		if sb:
			var new_sb: StyleBoxTexture = sb.duplicate() as StyleBoxTexture
			new_sb.texture = TEX_BTN_ACTIVE if active else TEX_BTN_NORMAL
			btn.add_theme_stylebox_override("normal", new_sb)
		btn.modulate = Color(1.15, 1.15, 1.15) if active else Color(0.85, 0.85, 0.85)

func _setup_sliders() -> void:
	radius_slider.value_changed.connect(func(val: float):
		if controller:
			controller.brush_radius = val
		radius_val_label.text = "%.2f" % val
		# Atualiza realce dos botões rápidos de tamanho
		for s in _size_buttons.keys():
			var b: Button = _size_buttons[s]
			b.modulate = Color(1.3, 1.3, 1.3) if is_equal_approx(float(s), val) else Color(0.7, 0.7, 0.7)
	)

	if controller:
		controller.brush_radius_changed.connect(func(r: float):
			radius_slider.value = r
			radius_val_label.text = "%.2f" % r
		)

	strength_slider.value_changed.connect(func(val: float):
		if controller:
			controller.brush_strength = val
		strength_val_label.text = "%.1fx" % val
	)
	strength_val_label.text = "%.1fx" % strength_slider.value

func _setup_planet_size_controls() -> void:
	if btn_planet_size_dec:
		btn_planet_size_dec.pressed.connect(func():
			if controller:
				controller.set_planet_scale(controller.planet_scale - 0.1)
		)
		btn_planet_size_dec.mouse_entered.connect(func(): SoundEffects.play_hover())
		_attach_tooltip(btn_planet_size_dec, "Diminuir Planeta (PageDown)")

	if btn_planet_size_inc:
		btn_planet_size_inc.pressed.connect(func():
			if controller:
				controller.set_planet_scale(controller.planet_scale + 0.1)
		)
		btn_planet_size_inc.mouse_entered.connect(func(): SoundEffects.play_hover())
		_attach_tooltip(btn_planet_size_inc, "Aumentar Planeta (PageUp)")

	if planet_size_val_btn:
		planet_size_val_btn.pressed.connect(func():
			if controller:
				controller.set_planet_scale(1.0)
		)
		planet_size_val_btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		_attach_tooltip(planet_size_val_btn, "Tamanho do Globo (Clique para redefinir para 1.0x)")

	if controller:
		controller.planet_scale_changed.connect(func(new_scale: float):
			if planet_size_val_btn:
				planet_size_val_btn.text = "%.1fx" % new_scale
		)

func _setup_oceans() -> void:
	if ocean_check:
		ocean_check.icon = preload("res://resources/ui/icons/biome_shallow_water.png")
		ocean_check.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ocean_check.text = ""
		_attach_tooltip(ocean_check, "Oceanos 3D (Ligar/Desligar)")
	ocean_check.toggled.connect(func(enabled: bool):
		SoundEffects.play_click()
		if planet:
			planet.set_sea_level(sea_level_slider.value, enabled)
	)

	sea_level_slider.value_changed.connect(func(val: float):
		if planet:
			planet.set_sea_level(val, ocean_check.button_pressed)
	)
	_attach_tooltip(sea_level_slider, "Nível dos Mares")

func _setup_world_gen_modal() -> void:
	btn_open_world_gen.pressed.connect(func():
		SoundEffects.play_click()
		world_gen_modal.visible = true
	)
	btn_open_world_gen.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_close_world_gen.pressed.connect(func():
		SoundEffects.play_click()
		world_gen_modal.visible = false
	)
	btn_close_world_gen.mouse_entered.connect(func(): SoundEffects.play_hover())

	# Oculta o botão de semente aleatória - o usuário é quem cria o mundo!
	if btn_gen_random:
		btn_gen_random.visible = false

	for child in world_presets_container.get_children():
		child.queue_free()

	var canvas_options: Array[Dictionary] = [
		{
			"key": "OCEAN",
			"name": "Planeta Oceano (Recomendado)",
			"icon": "res://resources/ui/icons/biome_deep_ocean.png",
			"desc": "Esfera 100% de água límpida. Perfeita para você erguer seus próprios continentes e ilhas!"
		},
		{
			"key": "EARTH",
			"name": "Terra Fértil / Planície",
			"icon": "res://resources/ui/icons/biome_grass.png",
			"desc": "Globo verdejante plano e suave. Pronto para cavar mares, rios e erguer cordilheiras."
		},
		{
			"key": "ROCK",
			"name": "Planeta Rochoso",
			"icon": "res://resources/ui/icons/biome_mountains.png",
			"desc": "Esfera mineral pura de pedra lisa para escultura geológica completa pelo usuário."
		},
		{
			"key": "DESERT",
			"name": "Planeta Desértico",
			"icon": "res://resources/ui/icons/biome_desert.png",
			"desc": "Dunas arenosas áridas prontas para criação de oásis, cânions e vales."
		},
		{
			"key": "RESET_RELIEF",
			"name": "Nivelar Todo o Relevo",
			"icon": "res://resources/ui/icons/tool_flatten.png",
			"desc": "Redefine todas as alturas para uma esfera lisa, preservando as pinturas e biomas criados."
		}
	]

	for opt: Dictionary in canvas_options:
		var btn := Button.new()
		btn.text = "%s\n%s" % [opt["name"], opt["desc"]]
		var icon_p: String = str(opt.get("icon", ""))
		if icon_p != "" and ResourceLoader.exists(icon_p):
			btn.icon = load(icon_p)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(325, 60)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

		var style := StyleBoxTexture.new()
		style.texture = TEX_BTN_NORMAL
		style.texture_margin_left = 8.0
		style.texture_margin_top = 8.0
		style.texture_margin_right = 8.0
		style.texture_margin_bottom = 8.0
		style.content_margin_left = 14.0
		style.content_margin_right = 14.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 10.0
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := StyleBoxTexture.new()
		hover_style.texture = TEX_BTN_HOVER
		hover_style.texture_margin_left = 8.0
		hover_style.texture_margin_top = 8.0
		hover_style.texture_margin_right = 8.0
		hover_style.texture_margin_bottom = 8.0
		hover_style.content_margin_left = 14.0
		hover_style.content_margin_right = 14.0
		hover_style.content_margin_top = 8.0
		hover_style.content_margin_bottom = 10.0
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.mouse_entered.connect(func(): SoundEffects.play_hover())
		var cur_k: String = str(opt.get("key", "OCEAN"))
		var cur_name: String = str(opt.get("name", "Novo Planeta"))
		btn.pressed.connect(func():
			if planet:
				planet.setup_canvas(cur_k)
				SoundEffects.play_click()
				world_gen_modal.visible = false
				show_toast("Novo planeta: " + cur_name)
		)
		world_presets_container.add_child(btn)

func _setup_pause_menu_modal() -> void:
	btn_pause_resume.icon = preload("res://resources/ui/icons/icon_play.png")
	btn_pause_resume.text = "Continuar (Esc)"
	btn_pause_resume.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_pause_new_world.icon = preload("res://resources/ui/icons/icon_new_world.png")
	btn_pause_new_world.text = "Novo Planeta"
	btn_pause_new_world.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_pause_save.icon = preload("res://resources/ui/icons/icon_save.png")
	btn_pause_save.text = "Salvar Planeta"
	btn_pause_save.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_pause_load.icon = preload("res://resources/ui/icons/icon_load.png")
	btn_pause_load.text = "Carregar Planeta"
	btn_pause_load.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_pause_settings.icon = preload("res://resources/ui/icons/icon_gear.png")
	btn_pause_settings.text = "Configurações"
	btn_pause_settings.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_pause_quit.icon = preload("res://resources/ui/icons/icon_exit.png")
	btn_pause_quit.text = "Sair para o Menu Principal"
	btn_pause_quit.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

	btn_open_pause.pressed.connect(_toggle_pause_menu)
	btn_open_pause.mouse_entered.connect(func(): SoundEffects.play_hover())

	if btn_close_pause:
		btn_close_pause.pressed.connect(_toggle_pause_menu)
		btn_close_pause.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_pause_resume.pressed.connect(_toggle_pause_menu)
	btn_pause_resume.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_pause_new_world.pressed.connect(func():
		SoundEffects.play_click()
		pause_menu_modal.visible = false
		world_gen_modal.visible = true
	)
	btn_pause_new_world.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_pause_save.pressed.connect(func():
		_save_current_planet()
		SoundEffects.play_click()
	)
	btn_pause_save.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_pause_load.pressed.connect(func():
		_load_current_planet()
		SoundEffects.play_click()
	)
	btn_pause_load.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_pause_settings.pressed.connect(func():
		SoundEffects.play_click()
		pause_menu_modal.visible = false
		settings_modal.visible = true
	)
	btn_pause_settings.mouse_entered.connect(func(): SoundEffects.play_hover())

	btn_pause_quit.pressed.connect(func():
		SoundEffects.play_click()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	btn_pause_quit.mouse_entered.connect(func(): SoundEffects.play_hover())

func _toggle_pause_menu() -> void:
	SoundEffects.play_click()
	pause_menu_modal.visible = not pause_menu_modal.visible

func _setup_settings_modal() -> void:
	if settings_menu_inst:
		settings_menu_inst.back_pressed.connect(func():
			settings_modal.visible = false
			pause_menu_modal.visible = true
		)

func _save_current_planet() -> void:
	if not planet:
		return
	var p_name: String = planet_name_edit.text.strip_edges()
	if p_name.is_empty():
		p_name = "Planeta"
	var filename := p_name.validate_filename() + ".json"
	var save_path := "user://planets/" + filename
	var ok := planet.save_planet_to_file(save_path, p_name)
	if ok:
		show_toast("Planeta salvo em " + filename + "!")
	else:
		show_toast("Erro ao salvar planeta.")

func _load_current_planet() -> void:
	if not planet:
		return
	var p_name: String = planet_name_edit.text.strip_edges()
	if p_name.is_empty():
		p_name = "Planeta"
	var filename := p_name.validate_filename() + ".json"
	var save_path := "user://planets/" + filename
	var res: Dictionary = planet.load_planet_from_file(save_path)
	if res.get("success", false):
		planet_name_edit.text = str(res.get("name", p_name))
		show_toast("Planeta " + filename + " carregado!")
	else:
		show_toast("Arquivo " + filename + " não encontrado.")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_hover_tooltip()

	if not main_hud_container.visible:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			main_hud_container.visible = true
			photo_mode_hint.visible = false
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if planet_name_edit and planet_name_edit.has_focus():
				planet_name_edit.release_focus()
				get_viewport().set_input_as_handled()
				return

			if settings_modal and settings_modal.visible:
				settings_modal.visible = false
				pause_menu_modal.visible = true
				get_viewport().set_input_as_handled()
				return

			if world_gen_modal and world_gen_modal.visible:
				world_gen_modal.visible = false
				get_viewport().set_input_as_handled()
				return

			# Alterna o Menu de Pausa in-game sem sair da rodada!
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()
			return

		# Atalhos rápidos de ferramentas 1 a 6 e atalho T para alternar barra superior
		if not (planet_name_edit and planet_name_edit.has_focus()):
			match event.keycode:
				KEY_1: _select_tool("PAINT")
				KEY_2: _select_tool("ELEVATE")
				KEY_3: _select_tool("CARVE")
				KEY_4: _select_tool("SMOOTH")
				KEY_5: _select_tool("FLATTEN")
				KEY_6: _select_tool("FILL")
				KEY_I: _select_tool("EYEDROPPER")
				KEY_T: _toggle_top_bar()

func _connect_planet_signals() -> void:
	if planet:
		planet.composition_updated.connect(_on_planet_composition_updated)
		planet.history_changed.connect(func(can_undo: bool, can_redo: bool):
			btn_undo.disabled = not can_undo
			btn_redo.disabled = not can_redo
		)

func _on_planet_composition_updated(stats: Dictionary, p_type: String) -> void:
	planet_type_badge.text = p_type
	var text := "Ambiente: "
	text += "Água: %.0f%%  " % (stats.get("water", 0.0) + stats.get("deep_ocean", 0.0) + stats.get("shallow_water", 0.0))
	text += "Vida: %.0f%%  " % (stats.get("carbon", 0.0) + stats.get("grass", 0.0) + stats.get("forest", 0.0))
	text += "Terra: %.0f%%  " % (stats.get("silicon", 0.0) + stats.get("hills", 0.0) + stats.get("mountains", 0.0) + stats.get("sand", 0.0))
	text += "Lava: %.0f%%" % (stats.get("sulfur", 0.0) + stats.get("lava", 0.0))
	stats_label.text = text

func show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): toast_label.visible = false)
