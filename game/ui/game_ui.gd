class_name EEGameUI
extends CanvasLayer

signal new_world_requested
signal continue_requested
signal resume_requested
signal title_requested
signal quit_requested
signal playground_requested
signal recover_requested
signal settings_changed(master: float, effects: float, ambience: float, shake: bool, reduced: bool)

const INK: Color = Color("101f2c")
const CREAM: Color = Color("e8eed7")
const MINT: Color = Color("b6e8bd")
var root: Control
var veil: ColorRect
var menu: PanelContainer
var content: VBoxContainer
var hud: Control
var health_bar: EEVitalMeter
var endurance_bar: EEVitalMeter
var weapon_label: Label
var objective_label: Label
var region_label: Label
var prompt_label: Label
var toast_label: Label
var footer: Label
var menu_state: String = "title"
var save_available: bool = false
var toast_time: float = 0.0
var master_level: float = 0.75
var effects_level: float = 0.8
var ambience_level: float = 0.35
var shake: bool = true
var reduced: bool = false
var settings_return: String = "title"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme: Theme = Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_focus_color", "Button", Color("ffffff"))
	theme.set_color("font_disabled_color", "Button", Color("5c7078"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.13, 0.17, 0.9) if state == "normal" else Color(0.14,0.26,0.28,0.95)
		if state == "disabled":
			style.bg_color.a = 0.35
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 11
		style.content_margin_bottom = 11
		style.border_width_left = 2 if state in ["hover", "focus"] else 0
		style.border_color = MINT
		theme.set_stylebox(state, "Button", style)
	root.theme = theme
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.018, 0.04, 0.06, 0.45)
	root.add_child(veil)
	menu = PanelContainer.new()
	menu.position = Vector2(78, 82)
	menu.custom_minimum_size = Vector2(398, 0)
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.07, 0.10, 0.93)
	panel.content_margin_left = 30
	panel.content_margin_right = 30
	panel.content_margin_top = 28
	panel.content_margin_bottom = 28
	panel.border_width_top = 2
	panel.border_color = Color("769d85")
	menu.add_theme_stylebox_override("panel", panel)
	root.add_child(menu)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	menu.add_child(content)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	region_label = _label("THE VERDANT REACH", 13, Color("b3ccbb"))
	region_label.position = Vector2(32, 24)
	hud.add_child(region_label)
	health_bar = _bar(Color("e6ae98"))
	health_bar.position = Vector2(32, 52)
	hud.add_child(health_bar)
	endurance_bar = _bar(MINT)
	endurance_bar.position = Vector2(32, 64)
	hud.add_child(endurance_bar)
	weapon_label = _label("01 / SOFT CLUB", 12, Color("bbd2c9"))
	weapon_label.position = Vector2(32, 83)
	hud.add_child(weapon_label)
	objective_label = _label("", 14, CREAM)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-500, 28)
	objective_label.size = Vector2(468, 50)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(objective_label)
	prompt_label = _label("", 17, CREAM)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-450, -78)
	prompt_label.size = Vector2(900, 34)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt_label)
	toast_label = _label("", 16, Color("e9e9c9"))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-430, 120)
	toast_label.size = Vector2(860, 80)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(toast_label)
	footer = _label("A SMALL BODY. A VERY OLD WORLD.", 12, Color("9aada7"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(80, -36)
	root.add_child(footer)

func _label(text: String, size_value: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label

func _bar(color: Color) -> EEVitalMeter:
	var bar: EEVitalMeter = EEVitalMeter.new()
	bar.size = Vector2(150, 5)
	bar.value = 100
	bar.color = color
	return bar

func _clear() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	menu.reset_size()

func _button(text: String, callback: Callable, disabled_value: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = disabled_value
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func _heading(kicker: String, title: String, subtitle: String) -> void:
	content.add_child(_label(kicker, 12, MINT))
	content.add_child(_label(title, 42, CREAM))
	var note: Label = _label(subtitle, 15, Color("9cb9b4"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(330, 0)
	content.add_child(note)
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 8
	content.add_child(gap)

func show_title(available: bool) -> void:
	menu_state = "title"
	save_available = available
	_clear()
	menu.show()
	veil.show()
	footer.show()
	hud.hide()
	_heading("FIELD NOTES / 001", "ELASTIC\nEXPLORER", "Find what still sings beneath the roots.")
	var first: Button = _button("Continue expedition", func() -> void: continue_requested.emit(), not available)
	var start: Button = _button("Begin a new world", _request_new)
	_button("Movement clearing", func() -> void: playground_requested.emit())
	_button("Settings & controls", func() -> void: show_settings("title"))
	if not OS.has_feature("web"):
		_button("Quit", func() -> void: quit_requested.emit())
	(first if available else start).grab_focus()

func _request_new() -> void:
	if not save_available:
		new_world_requested.emit()
		return
	menu_state = "confirm"
	_clear()
	_heading("NEW EXPEDITION", "Start again?", "Your current world will be archived locally before a new expedition begins.")
	_button("Keep exploring this world", func() -> void: show_title(true)).grab_focus()
	_button("Archive world & begin", func() -> void: new_world_requested.emit())

func show_pause() -> void:
	menu_state = "pause"
	_clear()
	menu.show()
	veil.show()
	footer.hide()
	_heading("TAKE A BREATH", "STILLNESS", "The world can wait.")
	_button("Resume", func() -> void: resume_requested.emit()).grab_focus()
	_button("Settings & controls", func() -> void: show_settings("pause"))
	_button("Save & return to title", func() -> void: title_requested.emit())

func show_recovery(message: String) -> void:
	menu_state = "recovery"
	_clear()
	menu.show()
	veil.show()
	_heading("SAVE RECOVERY", "Old echoes", message)
	_button("Preserve original & restore backup", func() -> void: recover_requested.emit()).grab_focus()
	_button("Back", func() -> void: show_title(save_available))

func show_play() -> void:
	menu_state = "play"
	menu.hide()
	veil.hide()
	footer.hide()
	hud.show()

func show_settings(previous: String) -> void:
	settings_return = previous
	menu_state = "settings"
	_clear()
	_heading("MAKE YOURSELF AT HOME", "SETTINGS", "WASD / left stick: move · mouse / right stick: aim\nSpace / A: jump or swim burst\nRMB / LT: grip · LMB / RT: attack\nShift / RB: roll · Ctrl / LB: squeeze\nE / X: interact · Wheel / Y: change weapon")
	_slider("Master", master_level, func(value: float) -> void: master_level = value; _emit_settings())
	_slider("Effects", effects_level, func(value: float) -> void: effects_level = value; _emit_settings())
	_slider("Ambience", ambience_level, func(value: float) -> void: ambience_level = value; _emit_settings())
	var shake_button: CheckButton = CheckButton.new()
	shake_button.text = "Camera shake"
	shake_button.button_pressed = shake
	shake_button.toggled.connect(func(value: bool) -> void: shake = value; _emit_settings())
	content.add_child(shake_button)
	var effects_button: CheckButton = CheckButton.new()
	effects_button.text = "Reduced lighting & particles"
	effects_button.button_pressed = reduced
	effects_button.toggled.connect(func(value: bool) -> void: reduced = value; _emit_settings())
	content.add_child(effects_button)
	_button("Back", func() -> void: show_pause() if settings_return == "pause" else show_title(save_available)).grab_focus()

func _slider(text: String, value: float, callback: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _label(text, 14, CREAM)
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(215, 26)
	slider.value_changed.connect(callback)
	row.add_child(slider)
	content.add_child(row)

func _emit_settings() -> void:
	settings_changed.emit(master_level, effects_level, ambience_level, shake, reduced)

func update_hud(player: EEPlayer, region: String, resonators: int, direction: String, prompt: String) -> void:
	health_bar.value = player.vitals.health
	endurance_bar.value = player.vitals.endurance
	health_bar.modulate.a = 1.0 if player.vitals.health < 100 or player.vitals.recently_hurt > 0 else 0.25
	endurance_bar.modulate.a = 1.0 if player.vitals.endurance < 99 or player.mode in ["swim", "climb"] else 0.25
	region_label.text = region.to_upper()
	var weapon: String = str(player.attack_controller.get("weapon")) if player.attack_controller != null else "club"
	weapon_label.text = {"club":"SOFT CLUB", "heavy":"STONEFIST", "thorn":"THORN LASH"}.get(weapon, weapon) + "  ·  WHEEL / Y"
	objective_label.text = ("RESONANCE  %d / 3\n" % resonators) + direction
	prompt_label.text = prompt
	if player.vitals.endurance <= 0.0:
		prompt_label.text = "EXHAUSTED — find footing or the surface"
	elif player.mode == "swim" and player.vitals.endurance < 35.0:
		prompt_label.text = "Low endurance — float at the surface to recover"

func toast(message: String, duration: float = 4.0) -> void:
	toast_label.text = message
	toast_time = duration
	toast_label.modulate.a = 1.0

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	toast_label.modulate.a = minf(1.0, toast_time)
