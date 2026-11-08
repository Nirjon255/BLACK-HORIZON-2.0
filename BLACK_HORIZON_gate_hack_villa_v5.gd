# BLACK HORIZON - single-file prototype (Godot 4.7, Compatibility renderer)
# Attach this script to a CharacterBody3D root (Main.tscn is included).
# One script powers the mission, the player and the enemies. The "role"
# variable decides which part runs on each instance.
extends CharacterBody3D

signal ammo_changed
signal hit_confirmed(killed: bool)
signal died

var role := "main"

# ---------------- Constants ----------------
const START_POS := Vector3(0, 0, 22)
const CHECKPOINT_POS := Vector3(0, 0, 0)
const CHECKPOINT_RESPAWN := Vector3(0, 0, 3)
const DRIVE_POS := Vector3(-12, 0, -17)
const SIGNAL_POS := Vector3(-9.5, 0.0, -18.5)
const FOREST_LAPTOP_POS := Vector3(9.0, 0.1, -66.0)
const FOREST_EXTRACT_POS := Vector3(0.0, 0.0, -112.0)
const FOREST_START := Vector3(0.0, 0.0, 92.0)
const FOREST_CHECKPOINT_AREA := Vector3(0.0, 0.0, 82.0)
const FOREST_CHECKPOINT_RESPAWN: Vector3 = Vector3(0.0, 0.0, 86.0)
const EXTRACT_POS := Vector3(0, 0, -44)

const PHASE_BRIEF := 0
const PHASE_ACTIVE := 1
const PHASE_COMPLETE := 2
const PHASE_FAILED := 3
const PHASE_MENU := 4
const SENS_VALUES := [0.0012, 0.0022, 0.0035]
const SENS_NAMES := ["LOW", "MEDIUM", "HIGH"]

const HIP_FOV := 72.0
const ADS_FOV := 50.0
const MAG_SIZE := 12
const RESERVE_START := 60
const RELOAD_TIME := 2.2
const FIRE_INTERVAL := 0.12
const BULLET_DAMAGE := 34
const MAX_RANGE := 150.0
const HIP_SPREAD := 0.018
const ADS_SPREAD := 0.004
const RECOIL_STEP := 0.03
const RECOIL_MAX := 0.18
const RECOIL_RECOVERY := 3.0
const HIP_WEAPON_POS := Vector3(0.22, -0.2, -0.42)
const ADS_WEAPON_POS := Vector3(0.0, -0.13, -0.32)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.4
const CROUCH_SPEED := 1.4
const ACCEL := 9.0
const DECEL := 12.0
const JUMP_VEL := 3.6
const GRAVITY := 9.8
const MOUSE_SENS := 0.0022
const MAX_HEALTH := 100
const STAND_H := 1.8
const CROUCH_H := 1.0
const EYE_OFF := 0.15
const STEP_HEIGHT := 0.7

const BANDAGE_START := 3
const BANDAGE_MAX := 5
const BANDAGE_TICKS := 4
const BANDAGE_TICK := 0.6
const BANDAGE_TICK_HP := 10
# Falls up to this height are safe. Each metre beyond it costs FALL_DAMAGE_PER_M health.
const FALL_SAFE_HEIGHT := 5.0
const FALL_DAMAGE_PER_M := 10.0


const S_PATROL := 0
const S_INVEST := 1
const S_ALERT := 2
const S_SEARCH := 3
const S_DEAD := 4
const E_HEALTH := 60
const E_WALK := 1.6
const E_RUN := 4.0
const E_TURN := 6.0
const E_EYE := 1.6
const E_SIGHT := 35.0
const E_HALF_ANGLE := 60.0
const E_SUSPICION := 0.4
const E_ATTACK_RANGE := 30.0
const E_FIRE := 0.7
const E_DAMAGE := 10
const E_WAIT := 2.5
const E_LOST := 4.0
const E_INVEST := 5.0
const E_SEARCH := 14.0
const COV_NONE := 0
const COV_MOVING := 1
const COV_HIDDEN := 2
const COV_PEEK := 3
const SOLDIER_FOLDER := "res://models/soldier/"
const SOLDIER_MODEL := "Steve.fbx"
const RIFLE_BONE_OFFSET := Vector3(0.0, 0.0, -0.1)
const RIFLE_BONE_ROT := Vector3(0.0, 0.0, 0.0)
const RIFLE_FALLBACK_POS := Vector3(0.25, 1.25, -0.35)
const SOLDIER_ANIMS := {
	"walk": "walking.fbx",
	"run": "rifle run.fbx",
	"aim": "rifle aiming idle.fbx",
	"fire": "firing rifle.fbx",
	"reload": "reloading.fbx",
	"hit": "hit reaction.fbx",
}

# ---------------- Main (mission) state ----------------
var phase := PHASE_BRIEF
var player
var enemies: Array = []
var level: NavigationRegion3D
var has_drive := false
var near_drive := false
var has_signal := false
var near_signal := false
var cp_has_signal := false
var alarm_on := false
var alarm_lamp_mat: StandardMaterial3D
var cull_t := 0.0
var tablet: Control
var lbl_weapons: Label
var hp_panel: ColorRect
var hp_accent: ColorRect
var hp_icon: Control
var hp_bar: Control
var lbl_bandage: Label
var tablet_open := false
var hack_active := false
var hack_step := 0
var near_gate_locker := false
var security_gate_open := false
var gate_panel: Node3D
var gate_collision: CollisionShape3D
var gate_tween: Tween
var lbl_alarm: Label
var alarm_sfx: AudioStreamPlayer
var gate_sfx: AudioStreamPlayer
var cameras: Array = []
var signal_area: Area3D
var mission_no := 1
var drive_pos := DRIVE_POS
var ext_pos := EXTRACT_POS
var start_pos := START_POS
var cp_area_pos := CHECKPOINT_POS
var cp_respawn := CHECKPOINT_RESPAWN
var cp_has_drive := false
var cp_pos := CHECKPOINT_RESPAWN
var drive_area: Area3D
var drive_mesh: MeshInstance3D
var cp_area: Area3D
var ext_area: Area3D
var hud: CanvasLayer
var panel: ColorRect
var lbl_brief: Label
var lbl_obj: Label
var lbl_status: Label
var lbl_ammo: Label
var lbl_health: Label
var lbl_cross: Label
var status_t := 0.0
var hit_t := 0.0
var menu_panel: ColorRect
var sens_btn: Button
var sens_index := 1

# ---------------- Player state ----------------
var health := MAX_HEALTH
var alive := true
var bandages := BANDAGE_START
# One-shot presses are queued from the input event and consumed in the physics step.
var jump_queued := false
var reload_queued := false
var fall_top_y := 0.0
var heal_ticks := 0
var heal_tick_t := 0.0
var ctrl := false
var crouching := false
var sprinting := false
var aiming := false
var pitch := 0.0
var recoil := 0.0
var mag := MAG_SIZE
var reserve := RESERVE_START
var reloading := false
var reload_t := 0.0
var fire_cd := 0.0
var aim_blend := 0.0
var reload_blend := 0.0
var sway := Vector2.ZERO
var bob := Vector3.ZERO
var bob_t := 0.0
var step_t := 0.0
var mouse_sens := 0.0022
var ice_rects: Array = []
var slot := 1
var mag_max := MAG_SIZE
var rifle_mag := MAG_SIZE
var rifle_res := RESERVE_START
var pistol_mag := 10
var pistol_res := 40
var pistol_node: Node3D
var snow: CPUParticles3D
var capsule: CapsuleShape3D
var pcol: CollisionShape3D
var head: Node3D
var cam: Camera3D
var weapon: Node3D
var sfx_player: AudioStreamPlayer
var sfx_cache: Dictionary = {}

# ---------------- Enemy state ----------------
var st := S_PATROL
var ehp := E_HEALTH
var aware := 0.0
var lk := Vector3.ZERO
var pts: Array = []
var pidx := 0
var wait_t := 0.0
var lost_t := 0.0
var inv_t := 0.0
var srch_t := 0.0
var srch_tgt := Vector3.ZERO
var arrived := false
var shot_cd := 0.0
var react_t := 0.0
var cov: int = 0
var cover_pt := Vector3.ZERO
var cov_t := 0.0
var cover_cd := 0.0
var hurt_t := 0.0
var fight_t := 0.0
var nav: NavigationAgent3D
var ecol: CollisionShape3D
var emesh: Node3D
var leg_l: Node3D
var leg_r: Node3D
var upper: Node3D
var rifle: Node3D
var anim_t := 0.0
var crouch_t := 0.0
var recoil_t := 0.0
var fire_anim_t := 0.0
var hit_anim_t := 0.0
var anim: AnimationPlayer
var anim_key := ""
var sentry := false
var sfx3d: AudioStreamPlayer3D


# ================= Dispatch =================

func _ready() -> void:
	match role:
		"main": _main_ready()
		"player": _player_ready()
		"enemy": _enemy_ready()


func _process(delta: float) -> void:
	match role:
		"main": _main_process(delta)
		"player": _player_process(delta)


func _physics_process(delta: float) -> void:
	match role:
		"player": _player_physics(delta)
		"enemy": _enemy_physics(delta)


func _unhandled_input(event: InputEvent) -> void:
	match role:
		"main": _main_input(event)
		"player": _player_input(event)


# ================= MAIN =================

func _main_ready() -> void:
	add_to_group("mission_controller")
	mission_no = Engine.get_meta("mission", 1)
	if mission_no == 2:
		drive_pos = FOREST_LAPTOP_POS
		ext_pos = FOREST_EXTRACT_POS
		has_signal = true
		start_pos = FOREST_START
		cp_area_pos = FOREST_CHECKPOINT_AREA
		cp_respawn = FOREST_CHECKPOINT_RESPAWN
		cp_pos = FOREST_CHECKPOINT_RESPAWN
	_setup_input()
	get_viewport().scaling_3d_scale = 0.9
	_build_environment()
	_build_hud()
	_build_level()
	_build_environment_upgrade()
	_build_ambient_audio()
	_build_objectives()
	_spawn_player(start_pos)
	_spawn_enemies()
	level.navigation_mesh = _make_nav_mesh()
	level.bake_navigation_mesh(false)
	_set_captured(false)
	_build_menu()
	if Engine.get_meta("skip_menu", false):
		Engine.set_meta("skip_menu", false)
		_open_briefing()
	else:
		_show_menu()


func _briefing_text() -> String:
	if mission_no == 2:
		return _briefing_two()
	var t := "MISSION 01 - DEAD SIGNAL\n\n"
	t += "Location: Mountain communication station\n\n"
	t += "Investigate a remote mountain station after an intelligence transmission disappears. "
	t += "Find the source of the signal, recover communication records and escape the area.\n\n"
	t += "CONTROLS\n"
	t += "WASD move  |  Mouse look  |  Shift sprint  |  Ctrl crouch  |  Space jump  |  B bandage\n"
	t += "Right mouse aim  |  Left mouse fire  |  R reload  |  E interact / gate locker  |  T tablet  |  M map  |  Esc pause  |  1/2 weapon\n\n"
	t += "Press ENTER to deploy."
	return t


func _setup_input() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("crouch", KEY_CTRL)
	_bind_key("reload", KEY_R)
	_bind_key("interact", KEY_E)
	_bind_key("bandage", KEY_B)
	_bind_key("map", KEY_M)
	_bind_key("tablet", KEY_T)
	_bind_key("slot_1", KEY_1)
	_bind_key("slot_2", KEY_2)
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)


func _bind_key(action: String, code: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.54, 0.60)
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.72, 0.78)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# One controlled directional shadow gives buildings and vehicles readable depth.
	# The shorter shadow distance keeps the Compatibility renderer affordable.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	sun.light_color = Color(0.88, 0.91, 0.94)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.06
	add_child(sun)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var screen := get_viewport().get_visible_rect().size

	panel = ColorRect.new()
	panel.color = Color(0.03, 0.04, 0.05, 0.93)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 10
	hud.add_child(panel)

	lbl_brief = Label.new()
	lbl_brief.position = Vector2(80, 60)
	lbl_brief.custom_minimum_size = Vector2(screen.x - 160.0, 0)
	lbl_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_brief.add_theme_font_size_override("font_size", 20)
	panel.add_child(lbl_brief)

	lbl_obj = _hud_label("", Vector2(24, 20), 18)
	lbl_status = _hud_label("", Vector2(0, screen.y * 0.16), 26)
	lbl_status.custom_minimum_size = Vector2(screen.x, 0)
	lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cross = _hud_label("+", Vector2(screen.x * 0.5 - 8.0, screen.y * 0.5 - 18.0), 28)

	# Compact vitals card: health icon, number, segmented bar and bandage count.
	var py := screen.y - 88.0
	hp_panel = ColorRect.new()
	hp_panel.position = Vector2(16.0, py)
	hp_panel.size = Vector2(236.0, 72.0)
	hp_panel.color = Color(0.02, 0.035, 0.045, 0.86)
	hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_panel.z_index = 20
	hud.add_child(hp_panel)
	hp_accent = ColorRect.new()
	hp_accent.position = Vector2(16.0, py)
	hp_accent.size = Vector2(3.0, 72.0)
	hp_accent.color = Color(0.35, 0.9, 0.55)
	hp_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_accent.z_index = 21
	hud.add_child(hp_accent)
	hp_icon = Control.new()
	hp_icon.position = Vector2(30.0, py + 12.0)
	hp_icon.size = Vector2(30.0, 30.0)
	hp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_icon.z_index = 24
	hp_icon.draw.connect(_draw_health_icon.bind(hp_icon))
	hud.add_child(hp_icon)
	var hp_title := _hud_label("HEALTH", Vector2(72.0, py + 7.0), 10)
	hp_title.z_index = 24
	hp_title.add_theme_color_override("font_color", Color(0.48, 0.65, 0.67))
	lbl_health = _hud_label("100", Vector2(70.0, py + 16.0), 22)
	lbl_health.z_index = 24
	lbl_health.add_theme_color_override("font_color", Color(0.9, 0.95, 0.92))
	lbl_health.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl_health.add_theme_constant_override("shadow_offset_x", 1)
	lbl_health.add_theme_constant_override("shadow_offset_y", 1)
	hp_bar = Control.new()
	hp_bar.position = Vector2(72.0, py + 52.0)
	hp_bar.size = Vector2(134.0, 8.0)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.z_index = 24
	hp_bar.draw.connect(_draw_health_bar.bind(hp_bar))
	hud.add_child(hp_bar)
	lbl_bandage = _hud_label("", Vector2(150.0, py + 7.0), 10)
	lbl_bandage.z_index = 24
	lbl_bandage.add_theme_color_override("font_color", Color(0.72, 0.84, 0.84))

	lbl_ammo = _hud_label("", Vector2(screen.x - 260.0, screen.y - 60.0), 20)
	lbl_weapons = _hud_label("", Vector2(screen.x - 380.0, screen.y - 100.0), 16)
	tablet = Control.new()
	tablet.position = Vector2(screen.x * 0.5 - 260.0, screen.y - 400.0)
	tablet.size = Vector2(520.0, 380.0)
	tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tablet.visible = false
	tablet.draw.connect(_draw_tablet)
	hud.add_child(tablet)



func _health_tint(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.35, 0.9, 0.55)
	if ratio > 0.3:
		return Color(1.0, 0.78, 0.25)
	return Color(1.0, 0.3, 0.25)


func _draw_health_icon(icon_ui: Control) -> void:
	var ratio := 1.0
	if player != null:
		ratio = clampf(float(player.health) / float(MAX_HEALTH), 0.0, 1.0)
	var tint := _health_tint(ratio)
	icon_ui.draw_rect(Rect2(Vector2.ZERO, icon_ui.size), Color(0.07, 0.13, 0.15, 1.0))
	icon_ui.draw_rect(Rect2(Vector2.ZERO, icon_ui.size), Color(tint.r, tint.g, tint.b, 0.45), false, 1.0)
	icon_ui.draw_rect(Rect2(12.0, 5.0, 6.0, 20.0), tint)
	icon_ui.draw_rect(Rect2(5.0, 12.0, 20.0, 6.0), tint)


# Segmented bar. Segments that a running bandage will fill show in pale teal.
func _draw_health_bar(bar_ui: Control) -> void:
	var ratio := 1.0
	var heal_ratio := 0.0
	if player != null:
		ratio = clampf(float(player.health) / float(MAX_HEALTH), 0.0, 1.0)
		if player.heal_ticks > 0:
			var pending: int = mini(player.health + player.heal_ticks * BANDAGE_TICK_HP, MAX_HEALTH)
			heal_ratio = clampf(float(pending) / float(MAX_HEALTH), 0.0, 1.0)
	var tint := _health_tint(ratio)
	var segs := 20
	var gap := 2.0
	var seg_w := (bar_ui.size.x - gap * float(segs - 1)) / float(segs)
	for i in range(segs):
		var frac := (float(i) + 0.5) / float(segs)
		var col := Color(0.1, 0.16, 0.18)
		if frac <= ratio:
			col = tint
		elif frac <= heal_ratio:
			col = Color(0.6, 0.95, 0.9, 0.5)
		bar_ui.draw_rect(Rect2(float(i) * (seg_w + gap), 0.0, seg_w, bar_ui.size.y), col)


func _hud_label(text: String, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.9, 0.92, 0.88))
	hud.add_child(l)
	return l


func _build_level() -> void:
	level = NavigationRegion3D.new()
	add_child(level)

	if mission_no == 2:
		_build_forest_base()
		return

	_solid(Vector3(0, -0.5, 0), Vector3(140, 1, 140), Color(0.24, 0.22, 0.18))

	var edge := Color(0.3, 0.29, 0.27)
	_solid(Vector3(0, 1.5, -65), Vector3(130, 3, 1), edge)
	_solid(Vector3(0, 1.5, 65), Vector3(130, 3, 1), edge)
	_solid(Vector3(-65, 1.5, 0), Vector3(1, 3, 130), edge)
	_solid(Vector3(65, 1.5, 0), Vector3(1, 3, 130), edge)

	var rock := Color(0.33, 0.31, 0.29)
	_solid(Vector3(-40, 2, -40), Vector3(10, 4, 8), rock)
	_solid(Vector3(38, 1.5, -48), Vector3(12, 3, 8), rock)
	_solid(Vector3(44, 2.5, 20), Vector3(9, 5, 9), rock)

	if mission_no == 2:
		_build_forest_base()
		return

	# Bunker with a south doorway. The field drive is inside.
	var concrete := Color(0.42, 0.41, 0.38)
	_solid(Vector3(-12, 1.5, -20), Vector3(8, 3, 0.5), concrete)
	_solid(Vector3(-16, 1.5, -16), Vector3(0.5, 3, 8), concrete)
	_solid(Vector3(-8, 1.5, -16), Vector3(0.5, 3, 8), concrete)
	_solid(Vector3(-14.5, 1.5, -12), Vector3(3, 3, 0.5), concrete)
	_solid(Vector3(-9.5, 1.5, -12), Vector3(3, 3, 0.5), concrete)
	_build_mountain_station_details()
	_solid(drive_pos + Vector3(0, 0.4, 0), Vector3(1, 0.8, 1), Color(0.3, 0.25, 0.18))

	var cover := [
		[Vector3(-6, 1.0, 6), Vector3(4, 2, 1)],
		[Vector3(7, 1.0, 2), Vector3(1, 2, 5)],
		[Vector3(4, 0.6, -4), Vector3(2, 1.2, 2)],
		[Vector3(-22, 0.6, 4), Vector3(3, 1.2, 1.5)],
		[Vector3(16, 1.0, -14), Vector3(3, 2, 1.5)],
		[Vector3(0, 1.5, -10), Vector3(6, 3, 1)],
		[Vector3(-28, 1.5, -22), Vector3(8, 3, 1)],
		[Vector3(24, 1.2, 8), Vector3(6, 2.4, 1)],
		[Vector3(-10, 1.2, 14), Vector3(1, 2.4, 6)],
		[Vector3(30, 0.8, -26), Vector3(3, 1.6, 3)],
	]
	for c in cover:
		_solid(c[0], c[1], Color(0.36, 0.34, 0.30))


func _build_objectives() -> void:
	drive_area = _area(drive_pos + Vector3(0, 1.0, 0), Vector3(3, 3, 3))
	drive_mesh = MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.5, 0.12, 0.35)
	drive_mesh.mesh = dm
	drive_mesh.material_override = _mat(Color(0.05, 0.05, 0.06), Color(0.9, 0.1, 0.1))
	drive_mesh.position = drive_pos + Vector3(0, 0.86, 0)
	add_child(drive_mesh)

	cp_area = _area(cp_area_pos + Vector3(0, 1.5, 0), Vector3(4, 3, 2))
	if mission_no == 1:
		signal_area = _area(SIGNAL_POS + Vector3(0, 1.0, 0), Vector3(3, 3, 3))
		_solid(SIGNAL_POS + Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 0.8), Color(0.2, 0.2, 0.22))
		_build_tower()

	ext_area = _area(ext_pos + Vector3(0, 1.5, 0), Vector3(8, 3, 8))
	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(8, 0.05, 8)
	pad.mesh = pm
	pad.material_override = _mat(Color(0.12, 0.18, 0.12), Color(0.1, 0.5, 0.2))
	pad.position = ext_pos + Vector3(0, 0.03, 0)
	add_child(pad)

	_build_bandage_pickups()
	if mission_no == 2:
		_build_cameras()
	drive_area.body_entered.connect(_on_drive_entered)
	drive_area.body_exited.connect(_on_drive_exited)
	cp_area.body_entered.connect(_on_checkpoint_entered)
	if mission_no == 1:
		signal_area.body_entered.connect(_on_signal_entered)
		signal_area.body_exited.connect(_on_signal_exited)
	ext_area.body_entered.connect(_on_extraction_entered)


func _spawn_player(pos: Vector3) -> void:
	var p = CharacterBody3D.new()
	p.set_script(get_script())
	p.role = "player"
	p.ice_rects = ICE_RECTS if mission_no == 2 else []
	p.mouse_sens = SENS_VALUES[sens_index]
	p.position = pos
	add_child(p)
	player = p
	p.hit_confirmed.connect(_on_hit_confirmed)
	p.died.connect(_on_player_died)


func _spawn_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	var specs := [
		{"pos": Vector3(-4, 0, -4), "patrol": [Vector3(-4, 0, -4), Vector3(-22, 0, -8), Vector3(-6, 0, -28)]},
		{"pos": Vector3(14, 0, -22), "patrol": [Vector3(14, 0, -22), Vector3(26, 0, -30), Vector3(8, 0, -36)]},
		{"pos": Vector3(-30, 0, 4), "patrol": [Vector3(-30, 0, 4), Vector3(-30, 0, 16), Vector3(-16, 0, 8)]},
	]
	if mission_no == 2:
		specs = _forest_specs()
	if not ENEMIES_ENABLED:
		specs = []
	for spec in specs:
		var en = CharacterBody3D.new()
		en.set_script(get_script())
		en.role = "enemy"
		en.position = spec["pos"]
		en.pts = spec["patrol"]
		en.sentry = spec.get("sentry", false)
		add_child(en)
		enemies.append(en)


func _make_nav_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.5
	nm.agent_radius = 0.5
	nm.agent_height = 1.8
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	return nm


func _solid(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	body.add_child(mi)
	level.add_child(body)
	return body


func _area(pos: Vector3, size: Vector3) -> Area3D:
	var a := Area3D.new()
	a.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	add_child(a)
	return a


func _mat(color: Color, glow: Color = Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if glow != Color.BLACK:
		m.emission_enabled = true
		m.emission = glow
	return m


func _main_input(event: InputEvent) -> void:
	if hack_active:
		_handle_gate_hack_input(event)
		return
	if event.is_action_pressed("ui_accept"):
		match phase:
			PHASE_MENU:
				_open_briefing()
			PHASE_BRIEF:
				_start_mission()
			PHASE_FAILED:
				_restart_from_checkpoint()
			PHASE_COMPLETE:
				get_tree().reload_current_scene()
		return
	if phase != PHASE_ACTIVE:
		return
	if event.is_action_pressed("interact") and near_gate_locker and not security_gate_open:
		_open_gate_hack()
		return
	if event.is_action_pressed("tablet"):
		if security_gate_open:
			_status("Security gate already unlocked.", 2.0)
		elif near_gate_locker:
			_status("Press E at the gate locker to open the access terminal.", 3.0)
		else:
			_status("Move closer to the gate control locker to access its security system.", 3.0)
		return
	if event.is_action_pressed("ui_cancel"):
		_set_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("interact") and near_drive and not has_drive:
		_pick_drive()
	elif event.is_action_pressed("interact") and near_signal and not has_signal:
		_locate_signal()
	elif event.is_action_pressed("map") and mission_no == 2:
		_toggle_tablet()
	else:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			_set_captured(true)


func _set_captured(c: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if c else Input.MOUSE_MODE_VISIBLE
	if player:
		player.set_controls(c and phase == PHASE_ACTIVE)


func _start_mission() -> void:
	phase = PHASE_ACTIVE
	panel.visible = false
	_set_captured(true)
	_status("Information is limited. Move carefully.", 4.0)


func _on_drive_entered(body: Node3D) -> void:
	if body == player and not has_drive:
		near_drive = true
		_status("Press E to steal the encrypted laptop." if mission_no == 2 else "Press E to secure the communication records (optional).", 3.0)


func _on_drive_exited(body: Node3D) -> void:
	if body == player:
		near_drive = false


func _pick_drive() -> void:
	has_drive = true
	near_drive = false
	_apply_drive_state()
	_status("Laptop stolen. Head for extraction." if mission_no == 2 else "Communication records secured. Find the signal source.", 4.0)


func _apply_drive_state() -> void:
	drive_mesh.visible = not has_drive
	drive_area.monitoring = not has_drive


func _on_checkpoint_entered(body: Node3D) -> void:
	if body != player or phase != PHASE_ACTIVE:
		return
	cp_pos = cp_respawn
	cp_has_drive = has_drive
	cp_has_signal = has_signal
	_status("Checkpoint saved.", 2.5)


func _on_extraction_entered(body: Node3D) -> void:
	if body != player or phase != PHASE_ACTIVE:
		return
	if mission_no == 2 and not has_drive:
		_status("Steal the encrypted laptop before escaping.", 3.0)
		return
	if mission_no == 1 and not has_signal:
		_status("Locate the signal source before escaping.", 3.0)
		return
	phase = PHASE_COMPLETE
	_set_captured(false)
	var records := "Communication records secured." if has_drive else "Communication records were not recovered."
	if mission_no == 2:
		_show_panel("MISSION COMPLETE\n\nLaptop secured. Extraction successful.\n\nPress ENTER to replay.")
	else:
		_show_panel("MISSION COMPLETE\n\nSignal source located. " + records + "\n\nPress ENTER to replay.")


func _on_player_died() -> void:
	phase = PHASE_FAILED
	_set_captured(false)
	_show_panel("MISSION FAILED\n\nPress ENTER to restart from the last checkpoint.")


func _restart_from_checkpoint() -> void:
	has_drive = cp_has_drive
	has_signal = cp_has_signal
	near_signal = false
	_reset_alarm()
	near_drive = false
	_apply_drive_state()
	_spawn_enemies()
	player.revive(cp_pos)
	phase = PHASE_ACTIVE
	panel.visible = false
	_set_captured(true)
	_status("Restarted from checkpoint.", 3.0)


func _on_hit_confirmed(killed: bool) -> void:
	hit_t = 0.18
	if killed:
		_status("Hostile down.", 1.5)


func _show_panel(text: String) -> void:
	lbl_brief.text = text
	panel.visible = true


func _status(text: String, duration: float) -> void:
	lbl_status.text = text
	status_t = duration


func _main_process(delta: float) -> void:
	if mission_no == 2 and phase == PHASE_ACTIVE and not alarm_on:
		_update_cameras(delta)
	if tablet_open:
		tablet.queue_redraw()
	cull_t -= delta
	if cull_t <= 0.0:
		cull_t = 0.5
		_cull_enemies()
	if lbl_alarm:
		lbl_alarm.text = "ALARM: TRIGGERED" if alarm_on else "ALARM: ARMED"
		lbl_alarm.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25) if alarm_on else Color(0.4, 1.0, 0.5))
	if status_t > 0.0:
		status_t -= delta
		if status_t <= 0.0:
			lbl_status.text = ""
	hit_t = maxf(hit_t - delta, 0.0)
	lbl_cross.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if hit_t > 0.0 else Color(0.9, 0.92, 0.88))
	var lines: PackedStringArray
	if mission_no == 2:
		lines = PackedStringArray([
			"OBJECTIVES",
			("[X]  " if security_gate_open else "[ ]  ") + "Hack the main gate locker (E)",
			("[X]  " if has_drive else "[ ]  ") + "Steal the encrypted laptop",
			"[ ]  Escape through the extraction point",
		])
	else:
		lines = PackedStringArray([
			"OBJECTIVES",
			("[X]  " if has_signal else "[ ]  ") + "Find the source of the signal",
			"[ ]  Escape through the extraction point",
			("[X]  " if has_drive else "[ ]  ") + "Optional: recover communication records",
		])
	lbl_obj.text = "\n".join(lines)
	if player:

		var ratio: float = clampf(float(player.health) / float(MAX_HEALTH), 0.0, 1.0)
		var hc := _health_tint(ratio)
		lbl_health.text = "%d" % player.health
		lbl_health.add_theme_color_override("font_color", hc)
		hp_accent.color = hc
		hp_icon.queue_redraw()
		hp_bar.queue_redraw()
		if player.heal_ticks > 0:
			lbl_bandage.text = "BANDAGE  x%d\nAPPLYING..." % player.bandages
		elif player.bandages <= 0:
			lbl_bandage.text = "BANDAGE  x0\nNONE LEFT"
		elif player.health >= MAX_HEALTH:
			lbl_bandage.text = "BANDAGE  x%d\nHEALTH FULL" % player.bandages
		else:
			lbl_bandage.text = "BANDAGE  x%d\n[B] APPLY" % player.bandages
		lbl_weapons.text = ("> 1 RIFLE" if player.slot == 1 else "  1 RIFLE") + "     " + ("> 2 PISTOL (SILENT)" if player.slot == 2 else "  2 PISTOL (SILENT)")
		if player.reloading:
			lbl_ammo.text = "RELOADING"
		else:
			lbl_ammo.text = ("RIFLE  " if player.slot == 1 else "PISTOL (SILENCED)  ") + "%d / %d" % [player.mag, player.reserve]


# ================= PLAYER =================

func _player_ready() -> void:
	add_to_group("player")
	health = MAX_HEALTH
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = STAND_H
	pcol = CollisionShape3D.new()
	pcol.shape = capsule
	pcol.position.y = STAND_H * 0.5
	add_child(pcol)

	head = Node3D.new()
	head.position.y = STAND_H - EYE_OFF
	add_child(head)

	cam = Camera3D.new()
	cam.fov = HIP_FOV
	cam.near = 0.05
	head.add_child(cam)
	cam.current = true
	_build_snow()
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	weapon = Node3D.new()
	weapon.position = HIP_WEAPON_POS
	cam.add_child(weapon)
	_build_rifle()
	pistol_node = Node3D.new()
	pistol_node.position = HIP_WEAPON_POS
	pistol_node.visible = false
	cam.add_child(pistol_node)
	_build_pistol()
	pistol_node.scale = Vector3.ONE * 1.5
	ammo_changed.emit()


func _build_rifle() -> void:
	var dark := _mat(Color(0.08, 0.08, 0.09))
	var polymer := _mat(Color(0.14, 0.13, 0.10))
	_part(Vector3(0.07, 0.09, 0.46), Vector3(0, 0, -0.12), dark)
	_part(Vector3(0.05, 0.07, 0.22), Vector3(0, -0.01, 0.2), polymer)
	_part(Vector3(0.03, 0.03, 0.28), Vector3(0, 0.02, -0.5), dark)
	_part(Vector3(0.04, 0.13, 0.06), Vector3(0, -0.11, -0.14), dark)
	_part(Vector3(0.015, 0.03, 0.015), Vector3(0, 0.07, -0.05), dark)
	_part(Vector3(0.02, 0.03, 0.02), Vector3(0, 0.06, -0.62), dark)


func _part(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(mi)


func _player_input(event: InputEvent) -> void:
	if not ctrl or not alive:
		return
	if event.is_action_pressed("jump"):
		jump_queued = true
	if event.is_action_pressed("reload"):
		reload_queued = true
	if event.is_action_pressed("slot_1"):
		_switch_slot(1)
	elif event.is_action_pressed("slot_2"):
		_switch_slot(2)
	elif event.is_action_pressed("bandage"):
		_use_bandage()
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := mouse_sens * (0.55 if aiming else 1.0)
		rotate_y(-motion.relative.x * s)
		pitch = clampf(pitch - motion.relative.y * s, deg_to_rad(-85.0), deg_to_rad(85.0))
		sway.x = clampf(sway.x - motion.relative.x * 0.0004, -0.04, 0.04)
		sway.y = clampf(sway.y + motion.relative.y * 0.0004, -0.04, 0.04)


func _player_process(delta: float) -> void:
	head.rotation.x = clampf(pitch + recoil, deg_to_rad(-89.0), deg_to_rad(89.0))
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 6.0)
	reload_blend = move_toward(reload_blend, 1.0 if reloading else 0.0, delta * 4.0)
	cam.fov = lerpf(cam.fov, ADS_FOV if aiming else HIP_FOV, clampf(delta * 10.0, 0.0, 1.0))
	sway = sway.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	var pos := HIP_WEAPON_POS.lerp(ADS_WEAPON_POS, aim_blend)
	pos += Vector3(sway.x, sway.y, 0.0) + bob * 0.5
	pos.y -= reload_blend * 0.12
	var wn: Node3D = pistol_node if slot == 2 else weapon
	wn.position = pos


func _player_physics(delta: float) -> void:
	var jump_now := jump_queued
	var reload_now := reload_queued
	jump_queued = false
	reload_queued = false
	var active := ctrl and alive
	var input := Vector2.ZERO
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	crouching = active and Input.is_action_pressed("crouch")
	aiming = active and Input.is_action_pressed("aim") and not reloading
	sprinting = active and Input.is_action_pressed("sprint") and input.y < -0.5 and not crouching and not aiming

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if aiming:
		speed *= 0.55

	var moving := input.length() > 0.05
	var wish := Vector3.ZERO
	if moving:
		wish = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized() * speed
	var icy := not ice_rects.is_empty() and _on_ice(global_position)
	if icy:
		wish *= 0.8
	var t := clampf((ACCEL if moving else DECEL) * delta * (0.35 if icy else 1.0), 0.0, 1.0)
	velocity.x = lerpf(velocity.x, wish.x, t)
	velocity.z = lerpf(velocity.z, wish.z, t)

	# Remember the highest point of each airborne spell, so landings can be checked for fall damage.
	var was_grounded := is_on_floor()
	if was_grounded:
		fall_top_y = global_position.y
	else:
		fall_top_y = maxf(fall_top_y, global_position.y)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif active and jump_now and not crouching:
		velocity.y = JUMP_VEL

	move_and_slide()
	if not was_grounded and is_on_floor():
		_on_land(fall_top_y - global_position.y)
	# Stairs are the only climbable surface. Walking into a tread steps onto it.
	if active and moving and is_on_wall():
		_try_climb(wish.normalized())

	var target_h := CROUCH_H if crouching else STAND_H
	capsule.height = move_toward(capsule.height, target_h, delta * 4.0)
	pcol.position.y = capsule.height * 0.5
	head.position.y = lerpf(head.position.y, capsule.height - EYE_OFF, clampf(delta * 12.0, 0.0, 1.0))

	var flat := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat > 0.5:
		bob_t += delta * flat * 2.6
		var amp := 0.035 * clampf(flat / WALK_SPEED, 0.3, 1.5)
		if aiming:
			amp *= 0.4
		bob = Vector3(cos(bob_t * 0.5) * amp * 0.6, sin(bob_t) * amp, 0.0)
	else:
		bob = bob.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	cam.position = cam.position.lerp(bob, clampf(delta * 16.0, 0.0, 1.0))

	if active and is_on_floor() and flat > 0.5:
		step_t -= delta
		if step_t <= 0.0:
			var loud := 7.0
			step_t = 0.6
			if sprinting:
				loud = 14.0
				step_t = 0.42
			elif crouching:
				loud = 2.0
				step_t = 0.8
			get_tree().call_group("enemies", "hear_noise", global_position, loud)
			_play_player("step")

	recoil = move_toward(recoil, 0.0, RECOIL_RECOVERY * delta)
	fire_cd = maxf(fire_cd - delta, 0.0)
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()

	# A bandage heals in ticks, even while the operator keeps moving or fighting.
	if heal_ticks > 0 and alive:
		heal_tick_t -= delta
		if heal_tick_t <= 0.0:
			heal_tick_t = BANDAGE_TICK
			heal_ticks -= 1
			health = mini(health + BANDAGE_TICK_HP, MAX_HEALTH)
			if health >= MAX_HEALTH:
				heal_ticks = 0

	if not active:
		return
	if reload_now:
		_start_reload()
	if Input.is_action_pressed("fire") and fire_cd <= 0.0:
		_try_fire()


func _try_fire() -> void:
	if reloading:
		return
	if mag <= 0:
		fire_cd = 0.3
		_play_player("click")
		_start_reload()
		return
	mag -= 1
	fire_cd = 0.28 if slot == 2 else FIRE_INTERVAL
	_play_player("silenced" if slot == 2 else "shot")
	recoil = minf(recoil + RECOIL_STEP * (0.6 if aiming else 1.0), RECOIL_MAX)
	rotate_y(randf_range(-0.006, 0.006) * (0.4 if aiming else 1.0))
	sway += Vector2(randf_range(-0.012, 0.012), 0.025)
	ammo_changed.emit()
	get_tree().call_group("enemies", "hear_noise", cam.global_position, 3.0 if slot == 2 else 45.0)
	_fire_ray()


func _fire_ray() -> void:
	var spread := ADS_SPREAD if aiming else HIP_SPREAD
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * randf_range(-spread, spread) + b.y * randf_range(-spread, spread)).normalized()
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * MAX_RANGE)
	q.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(q)
	if result.is_empty():
		return
	var hit = result["collider"]
	if hit is Node and hit.is_in_group("security_cameras"):
		var controller := get_tree().get_first_node_in_group("mission_controller")
		if controller:
			controller.call("_destroy_security_camera", hit)
		return
	if hit.has_method("take_damage"):
		var killed: bool = hit.take_damage(30 if slot == 2 else BULLET_DAMAGE, result["position"])
		hit_confirmed.emit(killed)


func _start_reload() -> void:
	if reloading or mag >= mag_max or reserve <= 0:
		return
	reloading = true
	reload_t = RELOAD_TIME
	_play_player("reload")


func _finish_reload() -> void:
	var take := mini(mag_max - mag, reserve)
	mag += take
	reserve -= take
	reloading = false
	ammo_changed.emit()


# ================= ENEMY =================

func _enemy_ready() -> void:
	add_to_group("enemies")
	ehp = E_HEALTH
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	ecol = CollisionShape3D.new()
	ecol.shape = cap
	ecol.position.y = 0.9
	add_child(ecol)

	emesh = Node3D.new()
	add_child(emesh)
	_build_soldier()

	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 1.0
	add_child(nav)
	sfx3d = AudioStreamPlayer3D.new()
	add_child(sfx3d)


func _enemy_physics(delta: float) -> void:
	if st == S_DEAD:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var sees := _sees()
	if sees:
		lk = player.global_position
		lost_t = 0.0
		if st != S_ALERT:
			aware = minf(aware + 0.5 * delta, 1.0)
			if aware >= 1.0:
				_e_set(S_ALERT)
	else:
		lost_t += delta
		if st == S_PATROL or st == S_INVEST:
			aware = maxf(aware - 0.2 * delta, 0.0)

	match st:
		S_PATROL:
			_e_patrol(delta)
		S_INVEST:
			_e_invest(delta)
		S_ALERT:
			_e_alert(delta, sees)
		S_SEARCH:
			_e_search(delta)

	_animate_soldier(delta)
	move_and_slide()


func _e_set(s: int) -> void:
	st = s
	cov = COV_NONE
	if s == S_PATROL:
		aware = 0.0
		wait_t = 0.0
	elif s == S_INVEST:
		arrived = false
		inv_t = E_INVEST
	elif s == S_ALERT:
		_play_3d("spot")
		aware = 1.0
		react_t = 0.6
		fight_t = 0.0
		shot_cd = 0.0
	elif s == S_SEARCH:
		srch_t = E_SEARCH
		srch_tgt = _around(lk, 6.0)


func _e_patrol(delta: float) -> void:
	if sentry:
		_stop()
		return
	if aware >= E_SUSPICION:
		_e_set(S_INVEST)
		return
	if pts.is_empty():
		_stop()
		return
	if wait_t > 0.0:
		wait_t -= delta
		_stop()
		if wait_t <= 0.0:
			pidx = (pidx + 1) % pts.size()
		return
	if _move_to(pts[pidx], E_WALK, delta):
		wait_t = E_WAIT


func _e_invest(delta: float) -> void:
	if sentry:
		_stop()
		return
	inv_t -= delta
	if inv_t <= 0.0:
		_e_set(S_PATROL)
		return
	if not arrived:
		arrived = _move_to(lk, E_WALK * 1.3, delta)
	else:
		_stop()
		rotate_y(delta * 1.5)


func _e_alert(delta: float, sees: bool) -> void:
	hurt_t = maxf(hurt_t - delta, 0.0)
	if sentry:
		_stop()
		if sees:
			_face(_dir_to_player(), delta)
			_shoot_step(delta, _dist_to_player())
		return
	if react_t > 0.0:
		react_t -= delta
		_stop()
		if sees:
			_face(_dir_to_player(), delta)
		return

	if cov == COV_NONE:
		if not sees:
			if lost_t >= E_LOST:
				_e_set(S_SEARCH)
			else:
				_move_to(lk, E_RUN, delta)
			return
		var dist := _dist_to_player()
		if dist > E_ATTACK_RANGE:
			_move_to(player.global_position, E_RUN, delta)
			return
		# Fight in the open. Take cover when hit, or after about 5 seconds
		# of shooting, so the enemy repositions instead of standing still.
		_stop()
		_face(_dir_to_player(), delta)
		_shoot_step(delta, dist)
		fight_t += delta
		cover_cd -= delta
		if (hurt_t > 0.0 or fight_t > 5.0) and cover_cd <= 0.0:
			cover_cd = 0.8
			if _find_cover():
				cov = COV_MOVING
				cov_t = 4.0
				fight_t = 0.0
				hurt_t = 0.0
		return

	if cov == COV_MOVING:
		cov_t -= delta
		if _move_to(cover_pt, E_WALK * 1.8, delta) or cov_t <= 0.0:
			_stop()
			cov = COV_HIDDEN
			cov_t = randf_range(1.2, 2.2)
		return

	if cov == COV_HIDDEN:
		_stop()
		cov_t -= delta
		if cov_t <= 0.0:
			cov = COV_PEEK
			cov_t = 1.4
		return

	# COV_PEEK: step out, fire, then look for a better position.
	_stop()
	if sees:
		var dist2 := _dist_to_player()
		_face(_dir_to_player(), delta)
		_shoot_step(delta, dist2)
	cov_t -= delta
	if cov_t <= 0.0:
		cov = COV_NONE
		cover_cd = 0.0


func _e_search(delta: float) -> void:
	if sentry:
		_stop()
		return
	srch_t -= delta
	if srch_t <= 0.0:
		_e_set(S_PATROL)
		return
	if _move_to(srch_tgt, E_WALK, delta):
		srch_tgt = _around(lk, 6.0)


func _e_shoot(dist: float) -> void:
	var chance := 0.5 * clampf(1.0 - dist / 60.0, 0.25, 1.0)
	if player.crouching:
		chance *= 0.6
	_play_3d("shot")
	_fire_effects()
	fire_anim_t = 0.6
	if randf() < chance:
		player.take_damage(E_DAMAGE)


func _sees() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player.alive:
		return false
	var eye := global_position + Vector3(0, E_EYE, 0)
	var h: float = 0.6 if player.crouching else 1.2
	var tgt: Vector3 = player.global_position + Vector3(0, h, 0)
	var to := tgt - eye
	var max_d: float = E_SIGHT * (0.5 if player.crouching else 1.0)
	if to.length() > max_d:
		return false
	var fwd := -global_transform.basis.z
	if rad_to_deg(fwd.angle_to(to)) > E_HALF_ANGLE:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, tgt)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] == player


func hear_noise(pos: Vector3, loudness: float) -> void:
	if st == S_DEAD or st == S_ALERT:
		return
	var d := global_position.distance_to(pos)
	if d > loudness:
		return
	aware = minf(aware + (1.0 - d / loudness) * 0.35, 1.0)
	lk = pos
	if st == S_PATROL and aware >= E_SUSPICION:
		_e_set(S_INVEST)
	elif st == S_INVEST:
		inv_t = E_INVEST
		arrived = false
	elif st == S_SEARCH:
		srch_tgt = pos


func _move_to(target: Vector3, speed: float, delta: float) -> bool:
	var flat_t := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat_t.length() < 1.0:
		_stop()
		return true
	nav.target_position = target
	var dir := flat_t.normalized()
	if not nav.is_navigation_finished():
		var nxt: Vector3 = nav.get_next_path_position()
		var d := Vector3(nxt.x - global_position.x, 0.0, nxt.z - global_position.z)
		if d.length() > 0.05:
			dir = d.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)
	return false


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(E_TURN * delta, 0.0, 1.0))


func _around(center: Vector3, r: float) -> Vector3:
	return center + Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))


func _die_enemy() -> void:
	st = S_DEAD
	velocity = Vector3.ZERO
	remove_from_group("enemies")
	ecol.set_deferred("disabled", true)
	emesh.rotation.z = PI / 2.0
	emesh.position.y = 0.35
	if anim:
		anim.stop()
	get_tree().call_group("enemies", "hear_noise", global_position, 12.0)


# ================= Shared damage (player or enemy) =================

func take_damage(amount: int, pos: Vector3 = Vector3.ZERO) -> bool:
	if role == "player":
		if not alive:
			return false
		health = maxi(health - amount, 0)
		if health == 0:
			alive = false
			ctrl = false
			died.emit()
		return false
	if role == "enemy":
		if st == S_DEAD:
			return false
		ehp -= amount
		hurt_t = 2.0
		hit_anim_t = 0.45
		if ehp <= 0:
			_die_enemy()
			return true
		if player:
			lk = player.global_position
		_e_set(S_ALERT)
	return false


# ================= Shared controls (called by main) =================

func set_controls(on: bool) -> void:
	ctrl = on
	if not on:
		velocity.x = 0.0
		velocity.z = 0.0


func revive(spawn_pos: Vector3) -> void:
	health = MAX_HEALTH
	alive = true
	ctrl = true
	bandages = BANDAGE_START
	heal_ticks = 0
	slot = 1
	mag_max = MAG_SIZE
	weapon.visible = true
	pistol_node.visible = false
	rifle_mag = MAG_SIZE
	rifle_res = RESERVE_START
	mag = MAG_SIZE
	reserve = RESERVE_START
	reloading = false
	recoil = 0.0
	pitch = 0.0
	velocity = Vector3.ZERO
	position = spawn_pos
	ammo_changed.emit()


# ================= Sound (generated in code, no audio files needed) =================

func _play_player(kind: String) -> void:
	if sfx_player == null:
		return
	var is_step := kind == "step"
	if is_step:
		kind = "step" + str(randi() % 3)
	sfx_player.stream = _sfx(kind)
	sfx_player.volume_db = -11.0 if is_step else -2.0
	sfx_player.play()


func _play_3d(kind: String, volume: float = -4.0) -> void:
	if sfx3d == null:
		return
	sfx3d.stream = _sfx(kind)
	sfx3d.volume_db = volume
	sfx3d.play()


func _sfx(kind: String) -> AudioStreamWAV:
	if sfx_cache.has(kind):
		return sfx_cache[kind]
	var rate := 22050
	var n := 1
	if kind == "shot":
		n = int(0.35 * rate)
	elif kind.begins_with("step"):
		n = int(0.18 * rate)
	elif kind == "reload":
		n = int(0.6 * rate)
	elif kind == "click":
		n = int(0.04 * rate)
	elif kind == "silenced":
		n = int(0.07 * rate)
	elif kind == "spot":
		n = int(0.2 * rate)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var prev := 0.0
	var prev2 := 0.0
	var prev3 := 0.0
	for i in range(n):
		var t := float(i) / float(rate)
		var v := 0.0
		if kind == "shot":
			var env := exp(-t * 18.0)
			var noise := randf() * 2.0 - 1.0
			var thump := sin(TAU * 70.0 * t) * exp(-t * 12.0)
			v = (noise * 0.7 + thump * 0.9) * env * 0.9
		elif kind.begins_with("step"):
			var variant := kind.substr(4).to_int()
			# Three cascaded low-pass filters remove the sharp, bright
			# edge that made the step sound like a gunshot.
			var raw := randf() * 2.0 - 1.0
			prev = prev + (raw - prev) * 0.12
			prev2 = prev2 + (prev - prev2) * 0.12
			prev3 = prev3 + (prev2 - prev3) * 0.12
			# Soft grit on dirt: low, quiet, slow attack, short tail.
			var grit := prev3 * 20.0 * exp(-t * 16.0) * clampf(t * 120.0, 0.0, 1.0)
			# Heel thud: a low tone that drops in pitch as it fades.
			var f := (95.0 - float(variant) * 12.0) * (1.0 - t * 1.6)
			var thud := sin(TAU * f * t) * exp(-t * 24.0) * clampf(t * 90.0, 0.0, 1.0)
			# Toe scuff a moment later.
			var toe := 0.0
			var toe_t := t - 0.09
			if toe_t >= 0.0:
				toe = prev3 * 15.0 * exp(-toe_t * 30.0) * 0.35
			v = (thud * 0.7 + grit * 0.45 + toe) * 0.55
		elif kind == "reload":
			var v1 := sin(TAU * 1800.0 * t) * exp(-t * 200.0) * 0.5
			var t2 := t - 0.42
			var v2 := 0.0
			if t2 >= 0.0:
				v2 = sin(TAU * 1100.0 * t2) * exp(-t2 * 200.0) * 0.5
			v = v1 + v2
		elif kind == "click":
			v = sin(TAU * 2000.0 * t) * exp(-t * 120.0) * 0.4
		elif kind == "silenced":
			var nz := randf() * 2.0 - 1.0
			prev = prev * 0.5 + nz * 0.5
			v = prev * exp(-t * 60.0) * 0.6
		elif kind == "spot":
			var attack := clampf(t * 200.0, 0.0, 1.0)
			v = sin(TAU * 880.0 * t) * exp(-t * 6.0) * 0.3 * attack
		buf.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = buf
	sfx_cache[kind] = w
	return w


# ================= Cover helpers =================

func _dist_to_player() -> float:
	var v: Vector3 = player.global_position - global_position
	v.y = 0.0
	return v.length()


func _dir_to_player() -> Vector3:
	var v: Vector3 = player.global_position - global_position
	v.y = 0.0
	return v.normalized()


func _shoot_step(delta: float, dist: float) -> void:
	shot_cd -= delta
	if shot_cd <= 0.0:
		shot_cd = E_FIRE
		_e_shoot(dist)


# Looks for a spot near the enemy that the player cannot see through.
# Spots that sit to the side of the player score better (flanking).
func _find_cover() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var pp: Vector3 = player.global_position
	var pf: Vector3 = -player.global_transform.basis.z
	pf.y = 0.0
	pf = pf.normalized()
	var eye: Vector3 = pp + Vector3(0.0, 1.2, 0.0)
	var best := Vector3.ZERO
	var best_score := INF
	var found := false
	for k in range(16):
		var ang := float(k) / 16.0 * TAU + randf() * 0.2
		var r := randf_range(3.0, 9.0)
		var cand := global_position + Vector3(cos(ang), 0.0, sin(ang)) * r
		var snapped := NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), cand)
		if Vector2(snapped.x - cand.x, snapped.z - cand.z).length() > 1.0:
			continue
		cand = snapped
		if Vector2(cand.x - pp.x, cand.z - pp.z).length() < 4.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, cand + Vector3(0.0, 1.0, 0.0))
		q.exclude = [get_rid(), player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue  # open line of sight, so this is not cover
		var from_p := cand - pp
		from_p.y = 0.0
		from_p = from_p.normalized()
		var lateral := absf(pf.cross(from_p).y)
		var score := global_position.distance_to(cand) * 0.35 - lateral * 4.0
		if score < best_score:
			best_score = score
			best = cand
			found = true
	if found:
		cover_pt = best
	return found


# ================= Main menu =================

func _build_menu() -> void:
	var screen := get_viewport().get_visible_rect().size
	menu_panel = ColorRect.new()
	menu_panel.color = Color(0.03, 0.04, 0.05, 0.93)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel.z_index = 10
	menu_panel.visible = false
	hud.add_child(menu_panel)

	var title := _menu_label("BLACK HORIZON", Vector2(0, screen.y * 0.18), 56)
	title.custom_minimum_size = Vector2(screen.x, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tag := _menu_label("INFILTRATE  |  EXPOSE  |  ELIMINATE", Vector2(0, screen.y * 0.18 + 80.0), 18)
	tag.custom_minimum_size = Vector2(screen.x, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var x: float = screen.x * 0.5 - 160.0
	var y := screen.y * 0.45
	_menu_button("START MISSION 01: DEAD SIGNAL", Vector2(x, y), _select_mission.bind(1))
	_menu_button("MISSION 02: COLD ENTRY", Vector2(x, y + 62.0), _select_mission.bind(2))
	sens_btn = _menu_button("MOUSE SENSITIVITY: " + SENS_NAMES[sens_index], Vector2(x, y + 124.0), _cycle_sens)
	_menu_button("QUIT", Vector2(x, y + 186.0), _quit_game)

	var footer := _menu_label("Esc pauses during the mission", Vector2(0, screen.y - 40.0), 14)
	footer.custom_minimum_size = Vector2(screen.x, 0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _menu_label(text: String, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.9, 0.92, 0.88))
	menu_panel.add_child(l)
	return l


func _menu_button(text: String, pos: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(320, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	menu_panel.add_child(b)
	return b


func _show_menu() -> void:
	phase = PHASE_MENU
	panel.visible = false
	menu_panel.visible = true
	_set_captured(false)


func _open_briefing() -> void:
	phase = PHASE_BRIEF
	menu_panel.visible = false
	_show_panel(_briefing_text())


func _cycle_sens() -> void:
	sens_index = (sens_index + 1) % SENS_VALUES.size()
	sens_btn.text = "MOUSE SENSITIVITY: " + SENS_NAMES[sens_index]
	if player:
		player.mouse_sens = SENS_VALUES[sens_index]


func _quit_game() -> void:
	get_tree().quit()


# ================= Soldier model (Steve + Mixamo animations) =================

func _build_soldier() -> void:
	var scene := load(SOLDIER_FOLDER + SOLDIER_MODEL) as PackedScene
	if scene == null:
		push_error("Could not load " + SOLDIER_MODEL + ". Using a placeholder capsule.")
		var fallback := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.35
		cm.height = 1.8
		fallback.mesh = cm
		fallback.position.y = 0.9
		emesh.add_child(fallback)
		return
	var model := scene.instantiate() as Node3D
	emesh.add_child(model)
	_fit_model(model, 1.8)
	_make_matte(model)
	anim = _soldier_anim_player(model)
	if anim == null:
		push_error(SOLDIER_MODEL + " has no AnimationPlayer.")
		return
	_import_anims()
	_attach_rifle(model, model.scale.x)
	_play_anim("aim")


# Scales the model to the target height and stands it on the floor.
func _fit_model(node: Node3D, target: float) -> void:
	var box := AABB()
	var found := false
	for m in _model_meshes(node):
		var mi := m as MeshInstance3D
		var b: AABB = node.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		if found:
			box = box.merge(b)
		else:
			box = b
			found = true
	if not found or box.size.y <= 0.0:
		return
	var s: float = target / box.size.y
	node.scale = Vector3.ONE * s
	node.position = Vector3(-s * box.get_center().x, -s * box.position.y, -s * box.get_center().z)


func _model_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_model_meshes(c))
	return out


func _soldier_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found := _soldier_anim_player(c)
		if found:
			return found
	return null


# Copies each Mixamo animation file's clip into the soldier's player.
# Loads each Mixamo animation once per session, then gives every guard the same clips.
func _import_anims() -> void:
	var clips: Dictionary = Engine.get_meta("soldier_clips", {})
	if clips.is_empty():
		for key in SOLDIER_ANIMS:
			var s := load(SOLDIER_FOLDER + SOLDIER_ANIMS[key]) as PackedScene
			if s == null:
				push_error("Missing animation file: " + SOLDIER_ANIMS[key])
				continue
			var inst := s.instantiate()
			var src_player := _soldier_anim_player(inst)
			if src_player:
				for anim_name in src_player.get_animation_list():
					if anim_name == "RESET":
						continue
					var clip := src_player.get_animation(anim_name)
					clip.loop_mode = Animation.LOOP_LINEAR if key in ["walk", "run", "aim"] else Animation.LOOP_NONE
					clips[key] = clip
					break
			inst.queue_free()
		Engine.set_meta("soldier_clips", clips)
	var lib: AnimationLibrary = anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
	for key in clips:
		if not lib.has_animation(key):
			lib.add_animation(key, clips[key])


func _play_anim(key: String) -> void:
	if anim == null or not anim.has_animation(key):
		return
	if anim_key == key:
		return
	anim_key = key
	anim.play(key)


func _animate_soldier(delta: float) -> void:
	if anim == null:
		return
	fire_anim_t = maxf(fire_anim_t - delta, 0.0)
	hit_anim_t = maxf(hit_anim_t - delta, 0.0)
	var speed := Vector2(velocity.x, velocity.z).length()
	var key := "walk" if speed > 0.3 else "aim"
	if st == S_ALERT:
		key = "run" if speed > 0.5 else "aim"
	if fire_anim_t > 0.0:
		key = "fire"
	if hit_anim_t > 0.0:
		key = "hit"
	_play_anim(key)


# Removes the plastic shine from the model's materials so it reads more like cloth and gear.
func _make_matte(node: Node) -> void:
	for mi in _model_meshes(node):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in range(m.mesh.get_surface_count()):
			var mat := m.get_active_material(s) as BaseMaterial3D
			if mat == null:
				print("DIAG Steve surface ", s, ": no standard material")
				continue
			var matte := mat.duplicate() as BaseMaterial3D
			print("DIAG Steve surface ", s, ": texture=", matte.albedo_texture != null, " colour=", matte.albedo_color)
			matte.roughness = 0.9
			matte.metallic = 0.0
			matte.metallic_specular = 0.25
			m.set_surface_override_material(s, matte)


# ================= Enemy rifle and firing effects =================

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var found := _find_skeleton(c)
		if found:
			return found
	return null


func _gun_part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# Builds a simple rifle and attaches it to the right hand bone so it follows the animation.
# If the hand bone can't be found, the rifle is placed in front of the chest instead.
func _attach_rifle(model: Node3D, model_scale: float) -> void:
	var rifle := Node3D.new()
	var gun := _mat(Color(0.05, 0.05, 0.06))
	_gun_part(rifle, Vector3(0.07, 0.10, 0.45), Vector3(0.0, 0.0, -0.1), gun)
	_gun_part(rifle, Vector3(0.03, 0.03, 0.35), Vector3(0.0, 0.02, -0.46), gun)
	_gun_part(rifle, Vector3(0.05, 0.08, 0.2), Vector3(0.0, -0.02, 0.2), gun)
	_gun_part(rifle, Vector3(0.04, 0.13, 0.06), Vector3(0.0, -0.11, -0.14), gun)

	var skel := _find_skeleton(model)
	var idx := -1
	if skel:
		idx = skel.find_bone("mixamorig_RightHand")
		if idx == -1:
			idx = skel.find_bone("mixamorig:RightHand")

	if idx == -1:
		emesh.add_child(rifle)
		rifle.position = RIFLE_FALLBACK_POS
		return

	var attach := BoneAttachment3D.new()
	attach.bone_name = skel.get_bone_name(idx)
	skel.add_child(attach)
	attach.add_child(rifle)
	# Cancel the model's scale so the rifle keeps its real size.
	rifle.scale = Vector3.ONE / model_scale
	rifle.position = RIFLE_BONE_OFFSET
	rifle.rotation_degrees = RIFLE_BONE_ROT


# Brief muzzle flash and a visible tracer toward the player.
func _fire_effects() -> void:
	if player == null:
		return
	var muzzle := to_global(Vector3(0.2, 1.3, -0.7))
	var target: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)

	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	flash.mesh = sm
	flash.material_override = _mat(Color(1.0, 0.8, 0.3), Color(1.0, 0.7, 0.2))
	get_parent().add_child(flash)
	flash.global_position = muzzle
	get_tree().create_timer(0.05).timeout.connect(flash.queue_free)

	var tracer := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, muzzle.distance_to(target))
	tracer.mesh = bm
	tracer.material_override = _mat(Color(1.0, 0.85, 0.5), Color(1.0, 0.8, 0.4))
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(tracer)
	tracer.global_position = (muzzle + target) * 0.5
	tracer.look_at(target, Vector3.UP)
	get_tree().create_timer(0.07).timeout.connect(tracer.queue_free)


# ================= Mission 01: signal source =================

func _on_signal_entered(body: Node3D) -> void:
	if body == player and not has_signal:
		near_signal = true
		_status("Press E to locate the signal source.", 3.0)


func _on_signal_exited(body: Node3D) -> void:
	if body == player:
		near_signal = false


func _locate_signal() -> void:
	has_signal = true
	near_signal = false
	_status("Signal source located. Escape to the extraction point.", 5.0)


# Radio tower outside the station, for the setting.
func _build_tower() -> void:
	var steel := Color(0.28, 0.31, 0.33)
	var cable := Color(0.16, 0.18, 0.19)
	var base := Vector3(-24.0, 0.0, -30.0)
	# Four narrow mast legs with repeated cross-bracing.
	for sx in [-0.8, 0.8]:
		for sz in [-0.8, 0.8]:
			_arch_visual(base + Vector3(sx, 7.0, sz), Vector3(0.12, 14.0, 0.12), steel)
	for h in [2.0, 5.0, 8.0, 11.0, 13.5]:
		_arch_visual(base + Vector3(0.0, h, -0.8), Vector3(1.7, 0.10, 0.10), steel)
		_arch_visual(base + Vector3(0.0, h, 0.8), Vector3(1.7, 0.10, 0.10), steel)
		_arch_visual(base + Vector3(-0.8, h, 0.0), Vector3(0.10, 0.10, 1.7), steel)
		_arch_visual(base + Vector3(0.8, h, 0.0), Vector3(0.10, 0.10, 1.7), steel)
	# Cross braces on two visible faces.
	for h in [1.5, 4.5, 7.5, 10.5]:
		_beam_between(base + Vector3(-0.8, h, -0.8), base + Vector3(0.8, h + 3.0, -0.8), 0.075, cable)
		_beam_between(base + Vector3(0.8, h, -0.8), base + Vector3(-0.8, h + 3.0, -0.8), 0.075, cable)
	_arch_visual(base + Vector3(0.0, 14.1, 0.0), Vector3(2.2, 0.18, 2.2), steel)
	_cyl_visual(base + Vector3(0.0, 15.0, 0.0), 0.055, 1.8, steel)
	_cyl_visual(base + Vector3(0.0, 16.0, 0.0), 0.04, 0.45, Color(0.82, 0.12, 0.1))
	# Directional microwave dish and a small red obstruction beacon.
	var dish := SphereMesh.new()
	dish.radius = 0.85
	dish.height = 0.24
	var dish_node := MeshInstance3D.new()
	dish_node.mesh = dish
	dish_node.scale = Vector3(1.0, 0.16, 1.0)
	dish_node.position = base + Vector3(0.0, 10.4, 1.0)
	dish_node.rotation_degrees.x = -28.0
	dish_node.material_override = _mat(Color(0.62, 0.64, 0.62))
	dish_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dish_node)
	var beacon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	beacon.mesh = sm
	beacon.material_override = _mat(Color(0.8, 0.1, 0.1), Color(1.0, 0.1, 0.1))
	beacon.position = base + Vector3(0.0, 16.3, 0.0)
	add_child(beacon)

# ================= Climbing =================


# Only stair treads (tagged "stairs" in the villa code) can be climbed. Any other ledge or wall blocks movement.
func _try_climb(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var probe := global_position + dir * 0.5
	var space := get_world_3d().direct_space_state

	# Find the top of the surface in front of the player.
	var down := PhysicsRayQueryParameters3D.create(probe + Vector3(0.0, STEP_HEIGHT + 0.1, 0.0), probe + Vector3(0.0, -0.05, 0.0))
	down.exclude = [get_rid()]
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		return
	var collider = hit["collider"]
	if not (collider is Node) or not (collider as Node).is_in_group("stairs"):
		return
	var rise: float = hit["position"].y - global_position.y
	if rise < 0.05 or rise > STEP_HEIGHT:
		return

	# Make sure there is room above the tread.
	var clear := PhysicsRayQueryParameters3D.create(probe + Vector3(0.0, rise + 0.1, 0.0), probe + Vector3(0.0, rise + 1.2, 0.0))
	clear.exclude = [get_rid()]
	if not space.intersect_ray(clear).is_empty():
		return

	global_position += Vector3(0.0, rise + 0.02, 0.0) + dir * 0.4
	velocity.y = 0.0


# ================= Mission select and Mission 02: Cold Entry =================

func _select_mission(n: int) -> void:
	Engine.set_meta("mission", n)
	Engine.set_meta("skip_menu", true)
	get_tree().reload_current_scene()


func _briefing_two() -> String:
	var t := "MISSION 02 - COLD ENTRY\n\n"
	t += "Location: Forest military base\n\n"
	t += "Infiltrate an enemy base hidden in a forest and steal an encrypted laptop "
	t += "containing information about the secret organization.\n\n"
	t += "Watch for security cameras. If one spots you, the alarm sounds and the guards search for you.\n\n"
	t += "CONTROLS\n"
	t += "WASD move  |  Mouse look  |  Shift sprint  |  Ctrl crouch  |  Space jump  |  B bandage\n"
	t += "Right mouse aim  |  Left mouse fire  |  R reload  |  E interact / gate locker  |  T tablet  |  M map  |  Esc pause  |  1/2 weapon\n\n"
	t += "Press ENTER to deploy."
	return t


func _forest_specs() -> Array:
	return [
		# Main gate
		{"pos": Vector3(0.0, 0.0, -14.0), "patrol": [Vector3(0.0, 0.0, -14.0), Vector3(-10.0, 0.0, -16.0), Vector3(10.0, 0.0, -16.0)]},
		{"pos": Vector3(-8.0, 0.0, -13.0), "patrol": [Vector3(-8.0, 0.0, -13.0), Vector3(-14.0, 0.0, -12.0), Vector3(-8.0, 0.0, -18.0)]},
		# Inside the compound
		{"pos": Vector3(-32.0, 0.0, -22.0), "patrol": [Vector3(-32.0, 0.0, -22.0), Vector3(-32.0, 0.0, -38.0), Vector3(-36.0, 0.0, -58.0), Vector3(-32.0, 0.0, -76.0)]},
		{"pos": Vector3(32.0, 0.0, -22.0), "patrol": [Vector3(32.0, 0.0, -22.0), Vector3(32.0, 0.0, -44.0), Vector3(34.0, 0.0, -60.0), Vector3(32.0, 0.0, -76.0)]},
		{"pos": Vector3(0.0, 0.0, -78.0), "patrol": [Vector3(0.0, 0.0, -78.0), Vector3(-30.0, 0.0, -78.0), Vector3(30.0, 0.0, -78.0)]},
		# Barracks: front gate guards and roof sentries
		{"pos": Vector3(-22.0, 0.0, -20.0), "patrol": [Vector3(-22.0, 0.0, -20.0), Vector3(-10.0, 0.0, -22.0), Vector3(-14.0, 0.0, -14.0)]},
		{"pos": Vector3(22.0, 0.0, -20.0), "patrol": [Vector3(22.0, 0.0, -20.0), Vector3(12.0, 0.0, -24.0), Vector3(28.0, 0.0, -18.0)]},
		{"pos": Vector3(-22.5, 3.5, -30.5), "sentry": true, "patrol": [Vector3(-22.5, 3.5, -30.5)]},
		{"pos": Vector3(22.5, 3.5, -30.5), "sentry": true, "patrol": [Vector3(22.5, 3.5, -30.5)]},
		# Villa: forecourt, garden, ground floor rooms and the first floor
		{"pos": Vector3(-8.0, 0.0, -51.0), "patrol": [Vector3(-8.0, 0.0, -51.0), Vector3(-13.0, 0.0, -52.0), Vector3(-8.0, 0.0, -53.5)]},
		{"pos": Vector3(-17.5, 0.0, -56.0), "patrol": [Vector3(-17.5, 0.0, -56.0), Vector3(-17.5, 0.0, -70.0), Vector3(-17.5, 0.0, -62.0)]},
		{"pos": Vector3(17.5, 0.0, -56.0), "patrol": [Vector3(17.5, 0.0, -56.0), Vector3(17.5, 0.0, -70.0), Vector3(17.5, 0.0, -62.0)]},
		{"pos": Vector3(-14.0, 0.0, -74.0), "patrol": [Vector3(-14.0, 0.0, -74.0), Vector3(-17.5, 0.0, -74.0), Vector3(-17.5, 0.0, -68.0)]},
		{"pos": Vector3(-14.5, 0.0, -57.5), "patrol": [Vector3(-14.5, 0.0, -57.5), Vector3(-14.5, 0.0, -69.0), Vector3(-8.5, 0.0, -69.0)]},
		{"pos": Vector3(14.0, 0.0, -57.5), "patrol": [Vector3(14.0, 0.0, -57.5), Vector3(14.0, 0.0, -69.0), Vector3(8.5, 0.0, -69.0)]},
		{"pos": Vector3(-8.5, 3.6, -60.0), "patrol": [Vector3(-8.5, 3.6, -60.0), Vector3(-8.5, 3.6, -66.5), Vector3(-8.5, 3.6, -58.0)]},
		{"pos": Vector3(8.5, 3.6, -60.0), "patrol": [Vector3(8.5, 3.6, -60.0), Vector3(8.5, 3.6, -66.5), Vector3(8.5, 3.6, -58.0)]},
		# Villa sentries: first-floor roof and the terrace by the balcony door
		{"pos": Vector3(-6.0, 7.5, -62.5), "sentry": true, "patrol": [Vector3(-6.0, 7.5, -62.5)]},
		{"pos": Vector3(6.0, 7.5, -62.5), "sentry": true, "patrol": [Vector3(6.0, 7.5, -62.5)]},
		{"pos": Vector3(0.0, 3.8, -56.0), "sentry": true, "patrol": [Vector3(0.0, 3.8, -56.0)]},
		# Vehicle depot, fuel tanks and trucks
		{"pos": Vector3(28.0, 0.0, -63.0), "patrol": [Vector3(28.0, 0.0, -63.0), Vector3(34.0, 0.0, -63.0), Vector3(22.0, 0.0, -60.0)]},
		{"pos": Vector3(-29.0, 0.0, -62.0), "patrol": [Vector3(-29.0, 0.0, -62.0), Vector3(-24.0, 0.0, -60.0), Vector3(-30.0, 0.0, -58.0)]},
		{"pos": Vector3(-26.0, 0.0, -48.0), "patrol": [Vector3(-26.0, 0.0, -48.0), Vector3(-26.0, 0.0, -38.0), Vector3(-24.0, 0.0, -46.0)]},
		# Corner watch towers
		{"pos": Vector3(-40.0, 6.0, -10.0), "sentry": true, "patrol": [Vector3(-40.0, 6.0, -10.0)]},
		{"pos": Vector3(40.0, 6.0, -10.0), "sentry": true, "patrol": [Vector3(40.0, 6.0, -10.0)]},
		{"pos": Vector3(-40.5, 6.0, -81.0), "sentry": true, "patrol": [Vector3(-40.5, 6.0, -81.0)]},
		{"pos": Vector3(40.5, 6.0, -81.0), "sentry": true, "patrol": [Vector3(40.5, 6.0, -81.0)]},
		# Forest and road patrols
		{"pos": Vector3(-70.0, 0.0, -40.0), "patrol": [Vector3(-70.0, 0.0, -40.0), Vector3(-82.0, 0.0, -22.0), Vector3(-64.0, 0.0, -14.0)]},
		{"pos": Vector3(68.0, 0.0, -60.0), "patrol": [Vector3(68.0, 0.0, -60.0), Vector3(80.0, 0.0, -42.0), Vector3(66.0, 0.0, -30.0)]},
		{"pos": Vector3(-20.0, 0.0, -102.0), "patrol": [Vector3(-20.0, 0.0, -102.0), Vector3(-6.0, 0.0, -108.0), Vector3(-30.0, 0.0, -96.0)]},
		{"pos": Vector3(60.0, 0.0, -100.0), "patrol": [Vector3(60.0, 0.0, -100.0), Vector3(50.0, 0.0, -108.0), Vector3(70.0, 0.0, -94.0)]},
		{"pos": Vector3(6.0, 0.0, 40.0), "patrol": [Vector3(6.0, 0.0, 40.0), Vector3(4.0, 0.0, 20.0), Vector3(8.0, 0.0, 0.0)]},
		{"pos": Vector3(-10.0, 0.0, 50.0), "patrol": [Vector3(-10.0, 0.0, 50.0), Vector3(-16.0, 0.0, 36.0), Vector3(-6.0, 0.0, 44.0)]},
	]


func _build_forest_base() -> void:
	seed(11)
	# Keep trees away from every guard route.
	var keep: Array = []
	for spec in _forest_specs():
		for p in spec["patrol"]:
			keep.append(Vector2(p.x, p.z))

	# Forest floor and gravel road from the south edge to the compound gate.
	_solid(Vector3(0.0, -0.5, 0.0), Vector3(240.0, 1.0, 240.0), Color(0.84, 0.87, 0.92))
	_vis(Vector3(0.0, 0.01, 0.0), Vector3(700.0, 0.02, 700.0), Color(0.82, 0.85, 0.9))
	_build_road()
	_build_ice()

	# Invisible limits so the player cannot walk off the map. No visible walls.
	_invisible_wall(Vector3(0.0, 1.5, -118.0), Vector3(240.0, 3.0, 1.0))
	_invisible_wall(Vector3(0.0, 1.5, 118.0), Vector3(240.0, 3.0, 1.0))
	_invisible_wall(Vector3(-118.0, 1.5, 0.0), Vector3(1.0, 3.0, 240.0))
	_invisible_wall(Vector3(118.0, 1.5, 0.0), Vector3(1.0, 3.0, 240.0))

	# Rock outcrops: [x, z, width, height]
	var rock := Color(0.34, 0.32, 0.3)
	for r in [[-84.0, -20.0, 9.0, 6.0], [80.0, 24.0, 12.0, 7.0], [-92.0, 60.0, 8.0, 5.0], [96.0, -40.0, 10.0, 6.0], [-60.0, 100.0, 14.0, 8.0], [60.0, 100.0, 9.0, 5.0]]:
		_solid(Vector3(r[0], r[3] * 0.5, r[1]), Vector3(r[2], r[3], r[2] * 0.8), rock)

	_plant_forest(keep)
	_build_compound()

	# Watchtowers outside the compound.
	_watchtower(Vector3(-55.0, 0.0, -30.0))
	_watchtower(Vector3(55.0, 0.0, -40.0))
	_watchtower(Vector3(-55.0, 0.0, -100.0))
	_watchtower(Vector3(48.0, 0.0, -100.0))
	_build_far_view()


func _build_compound() -> void:
	var concrete := Color(0.42, 0.41, 0.38)
	var steel := Color(0.35, 0.36, 0.38)
	var fence := Color(0.4, 0.4, 0.42)
	var dark := Color(0.2, 0.2, 0.2)
	var wood := Color(0.36, 0.27, 0.16)

	# Compound perimeter: collision remains continuous, but the visible barrier
	# is a metal security fence rather than five thick concrete-looking blocks.
	_fence_run(Vector3(-40.0, 0.0, -80.0), Vector3(40.0, 0.0, -80.0), 2.5)
	_fence_run(Vector3(-40.0, 0.0, -80.0), Vector3(-40.0, 0.0, -10.0), 2.5)
	_fence_run(Vector3(40.0, 0.0, -80.0), Vector3(40.0, 0.0, -10.0), 2.5)
	_fence_run(Vector3(-40.0, 0.0, -10.0), Vector3(-5.0, 0.0, -10.0), 2.5)
	_fence_run(Vector3(5.0, 0.0, -10.0), Vector3(40.0, 0.0, -10.0), 2.5)
	_solid(Vector3(-5.0, 1.6, -10.0), Vector3(0.8, 3.2, 0.8), steel)
	_solid(Vector3(5.0, 1.6, -10.0), Vector3(0.8, 3.2, 0.8), steel)
	_build_hackable_gate()

	# Corner watch towers. The solid tops are where the sentries stand.
	for p in [Vector3(-40.0, 0.0, -10.0), Vector3(40.0, 0.0, -10.0), Vector3(-40.0, 0.0, -80.0), Vector3(40.0, 0.0, -80.0)]:
		_solid(p + Vector3(0.0, 3.0, 0.0), Vector3(3.5, 6.0, 3.5), concrete)

	# Villa, walled garden and pool: see _build_villa() below.
	_build_villa()

	# Barracks, each with its own doorway gate.
	_block_building(Vector3(-22.0, 0.0, -30.0), Vector3(12.0, 3.2, 7.0), Color(0.4, 0.42, 0.36), 2.2)
	_block_building(Vector3(22.0, 0.0, -30.0), Vector3(12.0, 3.2, 7.0), Color(0.4, 0.42, 0.36), 2.2)

	# Vehicle depot with a roller gate across the front.
	var depot := Vector3(28.0, 0.0, -72.0)
	for dx in [-6.6, 6.6]:
		for dz in [-2.6, 2.6]:
			_solid(depot + Vector3(dx, 2.25, dz), Vector3(0.4, 4.5, 0.4), steel)
	_vis(depot + Vector3(0.0, 4.6, 0.0), Vector3(14.6, 0.3, 6.6), Color(0.3, 0.3, 0.28))
	_solid(depot + Vector3(-3.4, 1.6, 2.6), Vector3(0.5, 3.2, 0.5), steel)
	_solid(depot + Vector3(3.4, 1.6, 2.6), Vector3(0.5, 3.2, 0.5), steel)
	_vis(depot + Vector3(0.0, 1.4, 2.6), Vector3(6.2, 2.8, 0.1), Color(0.3, 0.32, 0.26))
	_truck(depot + Vector3(-1.0, 0.0, -1.5))

	# Parked trucks and fuel tanks.
	_truck(Vector3(-30.0, 0.0, -42.0))
	_truck(Vector3(-30.0, 0.0, -54.0))
	_cyl_solid(Vector3(-32.0, 0.0, -66.0), 2.2, 4.0, Color(0.5, 0.5, 0.46))
	_cyl_solid(Vector3(-27.0, 0.0, -66.0), 2.2, 4.0, Color(0.5, 0.5, 0.46))

	# Sandbag walls and crates.
	var sand := Color(0.55, 0.5, 0.36)
	for sx in [-16.0, 9.0]:
		for i in range(4):
			_solid(Vector3(sx + i * 2.2, 0.45, -18.0), Vector3(2.0, 0.9, 0.7), sand)
	for i in range(3):
		_solid(Vector3(-4.5 + i * 2.2, 0.45, -40.0), Vector3(2.0, 0.9, 0.7), sand)
	_solid(Vector3(-36.0, 0.6, -36.0), Vector3(1.2, 1.2, 1.2), wood)
	_solid(Vector3(-36.0, 1.8, -36.0), Vector3(1.2, 1.2, 1.2), wood)
	_solid(Vector3(34.0, 0.6, -40.0), Vector3(1.2, 1.2, 1.2), wood)
	_solid(Vector3(12.0, 0.6, -36.0), Vector3(1.4, 1.2, 1.4), wood)

	# Façade, rooftop-service and security details make the compound read as an
	# occupied military installation without adding expensive high-poly assets.
	_decorate_vehicle_depot(depot)
	_build_gatehouse()


# Solid building: four walls, a doorway with gate posts, and a flat roof deck.
func _block_building(c: Vector3, size: Vector3, col: Color, door_w: float) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	var t := 0.4
	_solid(c + Vector3(0.0, h * 0.5, -hz), Vector3(size.x, h, t), col)
	_solid(c + Vector3(-hx, h * 0.5, 0.0), Vector3(t, h, size.z), col)
	_solid(c + Vector3(hx, h * 0.5, 0.0), Vector3(t, h, size.z), col)
	var seg := (size.x - door_w) * 0.5
	_solid(c + Vector3(-(door_w * 0.5 + seg * 0.5), h * 0.5, hz), Vector3(seg, h, t), col)
	_solid(c + Vector3(door_w * 0.5 + seg * 0.5, h * 0.5, hz), Vector3(seg, h, t), col)
	# Roof deck that sentries can stand on.
	_solid(c + Vector3(0.0, h + 0.15, 0.0), Vector3(size.x, 0.3, size.z), Color(0.25, 0.24, 0.22))
	# Gate posts and a lintel at the doorway.
	var gp := Color(0.3, 0.3, 0.32)
	_solid(c + Vector3(-(door_w * 0.5 + 0.3), 1.2, hz + 0.5), Vector3(0.6, 2.4, 0.6), gp)
	_solid(c + Vector3(door_w * 0.5 + 0.3, 1.2, hz + 0.5), Vector3(0.6, 2.4, 0.6), gp)
	_vis(c + Vector3(0.0, 2.5, hz + 0.5), Vector3(door_w + 1.2, 0.3, 0.3), gp)

	# Narrow, reinforced windows on each elevation.
	for side in [-1.0, 1.0]:
		_window_detail(c + Vector3(side * size.x * 0.27, h * 0.65, -hz - 0.045), 1.35, 0.72)
		_window_detail(c + Vector3(side * size.x * 0.27, h * 0.65, hz + 0.045), 1.15, 0.68)
		_window_detail(c + Vector3(side * (hx + 0.045), h * 0.65, 0.0), 1.25, 0.7, PI * 0.5)

	# Roof coping, entrance light, signage and compact HVAC boxes.
	var trim := Color(0.23, 0.25, 0.25)
	_arch_visual(c + Vector3(0.0, h + 0.34, -hz), Vector3(size.x + 0.25, 0.12, 0.18), trim)
	_arch_visual(c + Vector3(0.0, h + 0.34, hz), Vector3(size.x + 0.25, 0.12, 0.18), trim)
	_arch_visual(c + Vector3(-hx, h + 0.34, 0.0), Vector3(0.18, 0.12, size.z), trim)
	_arch_visual(c + Vector3(hx, h + 0.34, 0.0), Vector3(0.18, 0.12, size.z), trim)
	_wall_lamp(c + Vector3(0.0, h * 0.92, hz + 0.12))
	_arch_visual(c + Vector3(0.0, 2.82, hz + 0.055), Vector3(1.7, 0.28, 0.08), Color(0.12, 0.16, 0.15))
	_roof_unit(c + Vector3(-size.x * 0.28, h + 0.58, 0.0), Vector3(1.4, 0.58, 1.0))
	_roof_unit(c + Vector3(size.x * 0.28, h + 0.58, 0.0), Vector3(1.2, 0.5, 0.9))


func _truck(c: Vector3) -> void:
	# Static 4x4 military transport truck. The main body remains collision-enabled;
	# trim, glass, lamps and wheel detailing are lightweight visual meshes.
	var paint := Color(0.14, 0.18, 0.15)
	var paint_light := Color(0.22, 0.26, 0.22)
	var rubber := Color(0.022, 0.025, 0.026)
	var metal := Color(0.10, 0.12, 0.12)
	var glass := Color(0.025, 0.065, 0.078)
	var lamp := Color(0.82, 0.72, 0.48)
	# Ladder chassis, lower frame and protected fuel tank.
	_solid(c + Vector3(0.0, 0.62, -0.05), Vector3(2.35, 0.38, 7.15), metal)
	_arch_visual(c + Vector3(0.0, 0.42, 0.0), Vector3(1.85, 0.18, 6.4), Color(0.055, 0.065, 0.06))
	_arch_visual(c + Vector3(-0.82, 0.56, 0.55), Vector3(0.42, 0.35, 0.95), Color(0.18, 0.19, 0.16))
	# Cargo bed, pressed side panels, ribs and rear tailgate.
	_solid(c + Vector3(0.0, 1.35, 0.25), Vector3(2.30, 1.55, 4.45), paint)
	_arch_visual(c + Vector3(0.0, 2.16, 0.25), Vector3(2.18, 0.08, 4.25), paint_light)
	for side in [-1.0, 1.0]:
		_arch_visual(c + Vector3(side * 1.17, 1.42, 0.25), Vector3(0.10, 1.45, 4.55), metal)
		for zoff in [-1.55, -0.55, 0.45, 1.45, 2.05]:
			_arch_visual(c + Vector3(side * 1.23, 1.42, zoff), Vector3(0.045, 1.34, 0.065), paint_light)
	_arch_visual(c + Vector3(0.0, 1.40, 2.53), Vector3(2.28, 1.42, 0.12), paint)
	_arch_visual(c + Vector3(0.0, 0.92, 2.61), Vector3(1.55, 0.08, 0.04), metal)
	# Canvas frame and support bows above the open cargo bed.
	for zoff in [-1.45, -0.25, 0.95, 2.0]:
		_arch_visual(c + Vector3(0.0, 2.28, zoff), Vector3(2.18, 0.055, 0.055), metal)
	# Cab shell, sloped windshield, side windows and front engine hood.
	_solid(c + Vector3(0.0, 1.10, -3.08), Vector3(2.22, 1.72, 1.82), paint)
	_arch_visual(c + Vector3(0.0, 1.66, -4.015), Vector3(1.88, 0.68, 0.055), glass, -7.0)
	_arch_visual(c + Vector3(-1.125, 1.58, -3.28), Vector3(0.055, 0.62, 0.72), glass)
	_arch_visual(c + Vector3(1.125, 1.58, -3.28), Vector3(0.055, 0.62, 0.72), glass)
	_arch_visual(c + Vector3(0.0, 0.76, -4.05), Vector3(2.18, 0.40, 1.12), paint_light)
	_arch_visual(c + Vector3(0.0, 0.50, -4.18), Vector3(2.42, 0.22, 0.24), metal)
	# Front grille with vertical slats, bumper, tow hooks and headlights.
	_arch_visual(c + Vector3(0.0, 0.91, -4.17), Vector3(0.76, 0.38, 0.055), Color(0.035, 0.045, 0.043))
	for gx in [-0.27, -0.135, 0.0, 0.135, 0.27]:
		_arch_visual(c + Vector3(gx, 0.91, -4.205), Vector3(0.035, 0.34, 0.025), metal)
	for side in [-1.0, 1.0]:
		_arch_visual(c + Vector3(side * 0.82, 1.04, -4.18), Vector3(0.30, 0.24, 0.075), lamp)
		_arch_visual(c + Vector3(side * 0.98, 0.72, -4.17), Vector3(0.18, 0.12, 0.10), Color(0.62, 0.12, 0.055))
		_arch_visual(c + Vector3(side * 1.18, 0.58, -4.08), Vector3(0.12, 0.48, 0.18), metal)
	_arch_visual(c + Vector3(0.0, 0.43, -4.22), Vector3(2.65, 0.18, 0.28), metal)
	for side in [-0.72, 0.72]:
		_arch_visual(c + Vector3(side, 0.32, -4.30), Vector3(0.12, 0.20, 0.12), metal)
	# Cab doors, handles, mirrors, wipers and side steps.
	for side in [-1.0, 1.0]:
		_arch_visual(c + Vector3(side * 1.13, 1.12, -3.05), Vector3(0.055, 0.72, 0.90), paint_light)
		_arch_visual(c + Vector3(side * 1.17, 1.34, -2.72), Vector3(0.035, 0.045, 0.16), metal)
		_arch_visual(c + Vector3(side * 1.32, 1.82, -3.48), Vector3(0.08, 0.34, 0.28), metal)
		_arch_visual(c + Vector3(side * 1.38, 1.84, -3.48), Vector3(0.035, 0.20, 0.18), glass)
		_arch_visual(c + Vector3(side * 1.23, 0.54, -2.95), Vector3(0.18, 0.12, 0.78), metal)
	for wiper in [-0.38, 0.38]:
		_arch_visual(c + Vector3(wiper, 1.39, -4.055), Vector3(0.045, 0.025, 0.52), rubber, -12.0)
	# Four deep-tread tyres with steel hubs and raised tread blocks.
	for side in [-1.0, 1.0]:
		for zoff in [-2.45, 1.95]:
			_cyl_visual(c + Vector3(side * 1.24, 0.58, zoff), 0.53, 0.34, rubber, Vector3(0.0, 0.0, PI * 0.5))
			_cyl_visual(c + Vector3(side * 1.43, 0.58, zoff), 0.29, 0.055, metal, Vector3(0.0, 0.0, PI * 0.5))
			_cyl_visual(c + Vector3(side * 1.47, 0.58, zoff), 0.12, 0.06, Color(0.40, 0.43, 0.40), Vector3(0.0, 0.0, PI * 0.5))
			for tread_i in range(12):
				var angle: float = float(tread_i) * TAU / 12.0
				_box(c + Vector3(side * 1.43, 0.58 + cos(angle) * 0.49, zoff + sin(angle) * 0.49), Vector3(0.075, 0.11, 0.18), rubber)
	# Rear lamps, registration plate, exhaust and small roof marker lights.
	for side in [-1.0, 1.0]:
		_arch_visual(c + Vector3(side * 0.94, 0.88, 2.69), Vector3(0.20, 0.42, 0.08), Color(0.58, 0.055, 0.035))
		_arch_visual(c + Vector3(side * 0.94, 1.35, 2.69), Vector3(0.20, 0.18, 0.08), Color(0.78, 0.48, 0.12))
		_arch_visual(c + Vector3(side * 0.86, 2.02, -3.15), Vector3(0.12, 0.12, 0.12), lamp)
	_arch_visual(c + Vector3(0.0, 0.83, 2.70), Vector3(0.55, 0.18, 0.045), Color(0.68, 0.69, 0.63))
	_cyl_visual(c + Vector3(-0.88, 0.88, 2.35), 0.055, 1.2, metal, Vector3(PI * 0.5, 0.0, 0.0))

func _watchtower(c: Vector3) -> void:
	var steel := Color(0.27, 0.3, 0.31)
	var rail := Color(0.19, 0.22, 0.23)
	# Four braced legs instead of a single oversized central pillar.
	for sx in [-1.25, 1.25]:
		for sz in [-1.25, 1.25]:
			_arch_visual(c + Vector3(sx, 4.45, sz), Vector3(0.18, 8.9, 0.18), steel)
	_vis(c + Vector3(0.0, 8.9, 0.0), Vector3(3.35, 0.28, 3.35), steel)
	# Waist-height safety rails around the sentry deck.
	for side in [-1.0, 1.0]:
		_arch_visual(c + Vector3(0.0, 10.0, side * 1.58), Vector3(3.2, 0.08, 0.08), rail)
		_arch_visual(c + Vector3(side * 1.58, 10.0, 0.0), Vector3(0.08, 0.08, 3.2), rail)
		for p in [-1.35, 0.0, 1.35]:
			_arch_visual(c + Vector3(p, 9.55, side * 1.58), Vector3(0.07, 0.95, 0.07), rail)
			_arch_visual(c + Vector3(side * 1.58, 9.55, p), Vector3(0.07, 0.95, 0.07), rail)
	_vis(c + Vector3(0.0, 11.1, 0.0), Vector3(3.7, 0.18, 3.7), Color(0.22, 0.24, 0.23))
	# Ladder and work light.
	_arch_visual(c + Vector3(-1.65, 4.7, 0.0), Vector3(0.08, 9.0, 0.08), rail)
	_arch_visual(c + Vector3(-1.95, 4.7, 0.0), Vector3(0.08, 9.0, 0.08), rail)
	for rung in range(1, 17):
		_arch_visual(c + Vector3(-1.8, rung * 0.55, 0.0), Vector3(0.38, 0.055, 0.07), rail)
	_wall_lamp(c + Vector3(0.0, 10.7, 1.72))


# Visual only: no collision, so the player and the navigation mesh ignore it.
func _vis(pos: Vector3, size: Vector3, color: Color, rot_z: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation_degrees.z = rot_z
	add_child(mi)
	return mi


# Solid cylinder, placed by its base centre.
func _cyl_solid(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0.0, height * 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _mat(color)
	body.add_child(mi)
	level.add_child(body)


# ================= Low-cost architectural detailing =================

func _arch_visual(pos: Vector3, size: Vector3, color: Color, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _cyl_visual(pos: Vector3, radius: float, height: float, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _beam_between(a: Vector3, b: Vector3, thickness: float, color: Color) -> void:
	var direction := b - a
	var length := direction.length()
	if length < 0.02:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thickness, thickness, length)
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), (a + b) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _window_detail(center: Vector3, width: float, height: float, rot_y: float = 0.0) -> void:
	var frame := Color(0.16, 0.19, 0.2)
	var glass := Color(0.035, 0.065, 0.08)
	_arch_visual(center, Vector3(width, height, 0.075), glass, rot_y)
	_arch_visual(center + Vector3(0.0, height * 0.5 + 0.055, 0.0), Vector3(width + 0.16, 0.09, 0.13), frame, rot_y)
	_arch_visual(center - Vector3(0.0, height * 0.5 + 0.055, 0.0), Vector3(width + 0.16, 0.09, 0.13), frame, rot_y)
	_arch_visual(center + Vector3(-width * 0.5 - 0.04, 0.0, 0.0), Vector3(0.09, height + 0.18, 0.13), frame, rot_y)
	_arch_visual(center + Vector3(width * 0.5 + 0.04, 0.0, 0.0), Vector3(0.09, height + 0.18, 0.13), frame, rot_y)
	_arch_visual(center, Vector3(0.045, height, 0.15), frame, rot_y)
	# A lower sill gives the window a recessed, built-up appearance.
	_arch_visual(center + Vector3(0.0, -height * 0.5 - 0.12, 0.02), Vector3(width + 0.35, 0.12, 0.22), Color(0.3, 0.31, 0.3), rot_y)


func _wall_lamp(center: Vector3) -> void:
	var housing := Color(0.09, 0.11, 0.12)
	_arch_visual(center, Vector3(0.3, 0.2, 0.16), housing)
	var lens: MeshInstance3D = _arch_visual(center + Vector3(0.0, -0.08, 0.09), Vector3(0.2, 0.07, 0.035), Color(0.9, 0.72, 0.4))
	lens.material_override = _mat(Color(0.9, 0.72, 0.4), Color(0.5, 0.32, 0.12))


func _roof_unit(center: Vector3, size: Vector3) -> void:
	var shell := Color(0.3, 0.33, 0.33)
	_arch_visual(center, size, shell)
	_arch_visual(center + Vector3(0.0, size.y * 0.5 + 0.035, 0.0), Vector3(size.x * 0.88, 0.07, size.z * 0.88), Color(0.18, 0.2, 0.2))
	var count := maxi(3, int(size.x / 0.22))
	for i in range(count):
		var x: float = -size.x * 0.34 + float(i) * (size.x * 0.68 / float(maxi(count - 1, 1)))
		_arch_visual(center + Vector3(x, 0.0, size.z * 0.5 + 0.035), Vector3(0.035, size.y * 0.55, 0.045), Color(0.12, 0.14, 0.15))


func _build_mountain_station_details() -> void:
	var concrete := Color(0.36, 0.37, 0.36)
	var trim := Color(0.22, 0.24, 0.24)
	var steel := Color(0.18, 0.21, 0.22)
	# Reinforced roof slab and raised perimeter coping.
	_solid(Vector3(-12.0, 3.18, -16.0), Vector3(8.8, 0.36, 8.8), concrete)
	_arch_visual(Vector3(-12.0, 3.42, -20.0), Vector3(8.9, 0.13, 0.16), trim)
	_arch_visual(Vector3(-12.0, 3.42, -12.0), Vector3(8.9, 0.13, 0.16), trim)
	_arch_visual(Vector3(-16.0, 3.42, -16.0), Vector3(0.16, 0.13, 8.0), trim)
	_arch_visual(Vector3(-8.0, 3.42, -16.0), Vector3(0.16, 0.13, 8.0), trim)

	# Heavy corner piers, concrete plinth and a shallow entrance canopy.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_arch_visual(Vector3(-12.0 + sx * 3.72, 1.55, -16.0 + sz * 3.72), Vector3(0.42, 3.1, 0.42), Color(0.29, 0.3, 0.3))
	_arch_visual(Vector3(-12.0, 0.14, -16.0), Vector3(8.5, 0.28, 8.5), Color(0.28, 0.29, 0.28))
	_arch_visual(Vector3(-12.0, 3.0, -10.95), Vector3(3.6, 0.2, 1.5), trim)
	_arch_visual(Vector3(-13.5, 1.4, -11.15), Vector3(0.16, 2.8, 0.16), steel)
	_arch_visual(Vector3(-10.5, 1.4, -11.15), Vector3(0.16, 2.8, 0.16), steel)
	_arch_visual(Vector3(-12.0, 0.12, -10.35), Vector3(3.5, 0.24, 0.8), Color(0.43, 0.43, 0.4))
	_arch_visual(Vector3(-12.0, 0.27, -9.85), Vector3(3.1, 0.18, 0.55), Color(0.37, 0.38, 0.36))

	# Narrow observation slits and recessed mechanical ventilation panels.
	_window_detail(Vector3(-16.28, 2.0, -17.0), 1.55, 0.38, PI * 0.5)
	_window_detail(Vector3(-7.72, 2.0, -17.0), 1.55, 0.38, PI * 0.5)
	_arch_visual(Vector3(-14.4, 2.35, -20.28), Vector3(1.05, 0.55, 0.07), Color(0.12, 0.15, 0.16))
	for i in range(6):
		_arch_visual(Vector3(-14.82 + i * 0.17, 2.35, -20.34), Vector3(0.045, 0.45, 0.04), steel)
	_wall_lamp(Vector3(-13.6, 2.65, -11.78))
	_wall_lamp(Vector3(-10.4, 2.65, -11.78))

	# Rooftop power and cooling equipment, plus a compact microwave aerial.
	_roof_unit(Vector3(-14.2, 3.85, -18.4), Vector3(1.35, 0.62, 1.0))
	_roof_unit(Vector3(-9.7, 3.72, -18.6), Vector3(1.0, 0.42, 0.85))
	_cyl_visual(Vector3(-12.0, 4.15, -14.2), 0.055, 1.35, steel)
	var dish := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.48
	sm.height = 0.13
	dish.mesh = sm
	dish.scale = Vector3(1.0, 0.16, 1.0)
	dish.position = Vector3(-12.0, 4.75, -14.2)
	dish.rotation_degrees.x = -25.0
	dish.material_override = _mat(Color(0.62, 0.64, 0.62))
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dish)

	# External cable conduit, downpipe and a small equipment warning panel.
	_cyl_visual(Vector3(-16.34, 1.55, -13.8), 0.055, 2.8, steel)
	_arch_visual(Vector3(-16.34, 1.25, -13.8), Vector3(0.12, 0.12, 0.4), trim)
	_arch_visual(Vector3(-12.0, 2.25, -11.72), Vector3(0.46, 0.34, 0.055), Color(0.62, 0.42, 0.12))


func _fence_run(a: Vector3, b: Vector3, height: float) -> void:
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 0.5:
		return
	var along_x := absf(delta.x) >= absf(delta.z)
	var mid := (a + b) * 0.5 + Vector3(0.0, height * 0.5, 0.0)
	var collider_size := Vector3(length, height, 0.16) if along_x else Vector3(0.16, height, length)
	_invisible_wall(mid, collider_size)

	# One MultiMesh per run keeps the fence to a small number of draw calls.
	var transforms: Array = []
	var colors: Array = []
	var metal := Color(0.31, 0.35, 0.36)
	var wire := Color(0.22, 0.26, 0.27)
	var segment_count := maxi(1, int(ceil(length / 3.0)))
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var point := a.lerp(b, t) + Vector3(0.0, height * 0.5, 0.0)
		var post_scale := Vector3(0.09, height + 0.12, 0.09)
		transforms.append(Transform3D(Basis.from_scale(post_scale), point))
		colors.append(metal)
	for y in [0.12, height * 0.5, height - 0.12]:
		var rail_scale := Vector3(length, 0.055, 0.055) if along_x else Vector3(0.055, 0.055, length)
		transforms.append(Transform3D(Basis.from_scale(rail_scale), mid + Vector3(0.0, y - height * 0.5, 0.0)))
		colors.append(metal)
	var wire_count := maxi(2, int(length / 0.55))
	for i in range(1, wire_count):
		var t := float(i) / float(wire_count)
		var point := a.lerp(b, t) + Vector3(0.0, height * 0.5, 0.0)
		var wire_scale := Vector3(0.025, height - 0.18, 0.025)
		transforms.append(Transform3D(Basis.from_scale(wire_scale), point))
		colors.append(wire)
	var horizontal_count := int(height / 0.45)
	for i in range(1, horizontal_count):
		var y := float(i) * 0.45
		var rail_scale := Vector3(length, 0.022, 0.022) if along_x else Vector3(0.022, 0.022, length)
		transforms.append(Transform3D(Basis.from_scale(rail_scale), mid + Vector3(0.0, y - height * 0.5, 0.0)))
		colors.append(wire)
	_multimesh(BoxMesh.new(), transforms, colors)


func _decorate_vehicle_depot(center: Vector3) -> void:
	var steel := Color(0.22, 0.25, 0.25)
	var hazard := Color(0.62, 0.45, 0.15)
	# Corrugated roller shutter, upper signage and corner protection bollards.
	for i in range(12):
		var y := 0.35 + float(i) * 0.2
		_arch_visual(center + Vector3(0.0, y, 2.67), Vector3(6.05, 0.035, 0.08), steel)
	_arch_visual(center + Vector3(0.0, 3.55, 2.72), Vector3(5.7, 0.48, 0.12), Color(0.12, 0.16, 0.16))
	_arch_visual(center + Vector3(0.0, 3.56, 2.8), Vector3(3.2, 0.12, 0.035), hazard)
	for x in [-3.5, 3.5]:
		_cyl_visual(center + Vector3(x, 0.55, 3.0), 0.12, 1.1, hazard)
	_wall_lamp(center + Vector3(-5.5, 3.65, 2.9))
	_wall_lamp(center + Vector3(5.5, 3.65, 2.9))
	# Roof purlins and a modest exhaust stack.
	for z in [-2.4, -1.2, 0.0, 1.2, 2.4]:
		_arch_visual(center + Vector3(0.0, 4.72, z), Vector3(13.2, 0.08, 0.08), steel)
	_arch_visual(center + Vector3(5.1, 5.1, -1.6), Vector3(0.5, 0.7, 0.5), Color(0.28, 0.3, 0.29))


func _build_gatehouse() -> void:
	var wall := Color(0.36, 0.38, 0.36)
	var trim := Color(0.19, 0.22, 0.22)
	# Small guard checkpoint beside the vehicle gate, outside the main patrol route.
	_solid(Vector3(-9.0, 1.35, -4.0), Vector3(5.0, 2.7, 4.0), wall)
	_arch_visual(Vector3(-9.0, 2.75, -4.0), Vector3(5.25, 0.16, 4.2), trim)
	_window_detail(Vector3(-9.0, 1.95, -1.96), 2.4, 0.8)
	_window_detail(Vector3(-11.55, 1.95, -4.0), 1.7, 0.8, PI * 0.5)
	_arch_visual(Vector3(-9.0, 0.12, -1.7), Vector3(2.5, 0.24, 0.6), Color(0.42, 0.42, 0.39))
	_wall_lamp(Vector3(-9.0, 2.85, -1.8))
	# Gate warning board and reflective hazard markings.
	_arch_visual(Vector3(0.0, 3.05, -9.72), Vector3(5.6, 0.55, 0.16), Color(0.12, 0.16, 0.15))
	for x in [-2.3, -1.15, 0.0, 1.15, 2.3]:
		_arch_visual(Vector3(x, 2.85, -9.61), Vector3(0.12, 0.2, 0.035), Color(0.78, 0.58, 0.18))


func _build_hackable_gate() -> void:
	# Heavy sliding security barrier: visibly closed until the locker is hacked.
	gate_panel = Node3D.new()
	gate_panel.position = Vector3(0.0, 0.0, -10.0)
	add_child(gate_panel)
	var frame_mat := _mat(Color(0.12, 0.16, 0.18))
	var slat_mat := _mat(Color(0.24, 0.29, 0.31))
	var warning_mat := _mat(Color(0.78, 0.48, 0.12))
	for i in range(17):
		var x := -4.55 + float(i) * 0.57
		var slat := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 2.75, 0.22)
		slat.mesh = bm
		slat.material_override = slat_mat
		slat.position = Vector3(x, 1.45, 0.0)
		gate_panel.add_child(slat)
	for y in [0.18, 1.42, 2.78]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(9.55, 0.16, 0.28)
		rail.mesh = rb
		rail.material_override = frame_mat
		rail.position = Vector3(0.0, y, 0.0)
		gate_panel.add_child(rail)
	for x in [-4.25, 4.25]:
		var brace := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.12, 2.6, 0.3)
		brace.mesh = bb
		brace.material_override = warning_mat
		brace.position = Vector3(x, 1.45, -0.04)
		brace.rotation.z = deg_to_rad(18.0 if x < 0.0 else -18.0)
		gate_panel.add_child(brace)
	# Enclosed overhead sliding track and compact motor housing.
	var track := MeshInstance3D.new()
	var track_mesh := BoxMesh.new()
	track_mesh.size = Vector3(10.2, 0.22, 0.5)
	track.mesh = track_mesh
	track.material_override = frame_mat
	track.position = Vector3(0.0, 3.02, 0.0)
	gate_panel.add_child(track)
	var motor := MeshInstance3D.new()
	var motor_mesh := BoxMesh.new()
	motor_mesh.size = Vector3(0.9, 0.42, 0.65)
	motor.mesh = motor_mesh
	motor.material_override = warning_mat
	motor.position = Vector3(-4.35, 3.08, 0.0)
	gate_panel.add_child(motor)
	var gate_body := AnimatableBody3D.new()
	gate_body.position = Vector3(0.0, 1.45, -10.0)
	gate_collision = CollisionShape3D.new()
	var gate_shape := BoxShape3D.new()
	gate_shape.size = Vector3(9.5, 2.9, 0.4)
	gate_collision.shape = gate_shape
	gate_body.add_child(gate_collision)
	add_child(gate_body)

	# Weatherproof industrial control locker mounted beside the gate.
	var locker := Node3D.new()
	locker.position = Vector3(-6.15, 0.0, -8.85)
	add_child(locker)
	var foot := MeshInstance3D.new()
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.9, 0.14, 0.55)
	foot.mesh = foot_mesh
	foot.material_override = _mat(Color(0.11, 0.14, 0.15))
	foot.position = Vector3(0.0, 0.07, 0.0)
	locker.add_child(foot)
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := BoxMesh.new()
	pedestal_mesh.size = Vector3(0.58, 0.72, 0.4)
	pedestal.mesh = pedestal_mesh
	pedestal.material_override = _mat(Color(0.12, 0.16, 0.17))
	pedestal.position = Vector3(0.0, 0.48, 0.0)
	locker.add_child(pedestal)
	var case := MeshInstance3D.new()
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.72, 1.15, 0.34)
	case.mesh = case_mesh
	case.material_override = _mat(Color(0.16, 0.2, 0.22))
	case.position = Vector3(0.0, 1.35, 0.0)
	locker.add_child(case)
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.48, 0.32, 0.025)
	screen.mesh = screen_mesh
	screen.material_override = _mat(Color(0.04, 0.18, 0.19), Color(0.08, 0.75, 0.66))
	screen.position = Vector3(0.0, 1.52, 0.185)
	locker.add_child(screen)
	var status_led := MeshInstance3D.new()
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.045
	led_mesh.height = 0.09
	status_led.mesh = led_mesh
	status_led.material_override = _mat(Color(0.9, 0.2, 0.12), Color(0.9, 0.08, 0.04))
	status_led.position = Vector3(0.23, 1.05, 0.2)
	locker.add_child(status_led)
	var keypad := MeshInstance3D.new()
	var key_mesh := BoxMesh.new()
	key_mesh.size = Vector3(0.42, 0.24, 0.035)
	keypad.mesh = key_mesh
	keypad.material_override = _mat(Color(0.055, 0.075, 0.08))
	keypad.position = Vector3(0.0, 1.08, 0.19)
	locker.add_child(keypad)
	var locker_area := Area3D.new()
	locker_area.position = Vector3(-6.15, 1.0, -8.0)
	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.4
	area_shape.shape = sphere
	locker_area.add_child(area_shape)
	locker_area.body_entered.connect(_on_gate_locker_entered)
	locker_area.body_exited.connect(_on_gate_locker_exited)
	add_child(locker_area)


func _on_gate_locker_entered(body: Node3D) -> void:
	if body == player and not security_gate_open:
		near_gate_locker = true
		_status("Press E to open the gate locker access terminal.", 4.0)


func _on_gate_locker_exited(body: Node3D) -> void:
	if body == player:
		near_gate_locker = false


func _tree_blocked(x: float, z: float, keep: Array) -> bool:
	if x > -44.0 and x < 44.0 and z > -86.0 and z < -4.0:
		return true  # compound
	if absf(x) < 8.0 and z > -6.0:
		return true  # road
	if Vector2(x, z).distance_to(Vector2(0.0, 92.0)) < 9.0:
		return true  # start
	if Vector2(x, z).distance_to(Vector2(0.0, -112.0)) < 12.0:
		return true  # extraction
	for p in [Vector2(-55.0, -30.0), Vector2(55.0, -40.0), Vector2(-55.0, -100.0), Vector2(48.0, -100.0)]:
		if Vector2(x, z).distance_to(p) < 7.0:
			return true  # watchtowers
	if absf(x + 62.0) < 13.0 and absf(z + 62.0) < 10.0:
		return true  # frozen lake
	for k in keep:
		if Vector2(x, z).distance_to(k) < 3.0:
			return true  # guard routes
	return false


# Trees and undergrowth. Trunks block movement; canopies and bushes are visual only.
func _plant_forest(keep: Array) -> void:
	var trunk_xf: Array = []
	var trunk_col: Array = []
	var pine_xf: Array = []
	var pine_col: Array = []
	var leaf_xf: Array = []
	var leaf_col: Array = []
	var bush_xf: Array = []
	var bush_col: Array = []
	var trunks := StaticBody3D.new()
	level.add_child(trunks)
	var grid: Dictionary = {}

	var placed := 0
	var tries := 0
	while placed < 450 and tries < 30000:
		tries += 1
		var x: float
		var z: float
		if randf() < 0.4:
			# Thick band of forest around the compound.
			x = randf_range(-80.0, 80.0)
			z = randf_range(-115.0, 6.0)
		else:
			x = randf_range(-112.0, 112.0)
			z = randf_range(-112.0, 112.0)
		if _tree_blocked(x, z, keep) or _near_tree(x, z, grid, 3.0):
			continue
		_add_to_grid(x, z, grid)
		placed += 1
		var th := randf_range(9.0, 15.0)
		var tr := randf_range(0.8, 1.2)
		var shade := randf_range(0.8, 1.1)
		var kind := randf()

		var trunk_c := Color(0.3, 0.22, 0.15) * shade
		if kind > 0.85:
			trunk_c = Color(0.75, 0.72, 0.66) * shade  # birch
		trunk_xf.append(Transform3D(Basis.from_scale(Vector3(tr, th, tr)), Vector3(x, th * 0.5, z)))
		trunk_col.append(trunk_c)

		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.28 * tr
		cyl.height = th
		cs.shape = cyl
		cs.position = Vector3(x, th * 0.5, z)
		trunks.add_child(cs)

		if kind < 0.55:
			# Layered evergreen crowns: irregular, overlapping branch skirts rather than three toy-like cones.
			var crown_base := th * 0.27
			var tiers := 5
			for tier in range(tiers):
				var f := float(tier) / float(tiers - 1)
				var radius := lerpf(3.5, 0.65, f) * randf_range(0.88, 1.12)
				var height := randf_range(3.0, 4.4) * (1.0 - f * 0.24)
				var y := crown_base + float(tier) * 1.55 + height * 0.42
				var ox := randf_range(-0.22, 0.22)
				var oz := randf_range(-0.22, 0.22)
				var yaw := randf_range(0.0, TAU)
				var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(radius, height, radius))
				pine_xf.append(Transform3D(basis, Vector3(x + ox, y, z + oz)))
				var pc := Color(0.055, 0.14, 0.085).lerp(Color(0.34, 0.43, 0.3), randf_range(0.08, 0.24)) * shade
				pine_col.append(pc)
		elif kind < 0.85:
			# Broadleaf crown made from several offset foliage masses, not one perfect sphere.
			var r := randf_range(2.4, 3.4)
			for clump in range(6):
				var a := float(clump) / 6.0 * TAU + randf_range(-0.25, 0.25)
				var rr := r * randf_range(0.45, 0.7)
				var cx := x + cos(a) * r * 0.48
				var cz := z + sin(a) * r * 0.48
				var cy := th * 0.76 + randf_range(-0.45, 0.55)
				var scale := Vector3(rr * randf_range(0.85, 1.2), rr * randf_range(0.65, 0.95), rr * randf_range(0.85, 1.15))
				leaf_xf.append(Transform3D(Basis(Vector3.UP, randf_range(0.0, TAU)) * Basis.from_scale(scale), Vector3(cx, cy, cz)))
				leaf_col.append(Color(0.10, 0.22, 0.09).lerp(Color(0.32, 0.42, 0.19), randf_range(0.15, 0.45)) * shade)
		else:
			# Birch: narrow crown clusters with pale bark and muted olive leaves.
			var r3b := randf_range(1.7, 2.3)
			for clump in range(4):
				var a := float(clump) / 4.0 * TAU
				var scale_b := Vector3(r3b * 0.72, r3b * 0.95, r3b * 0.72)
				leaf_xf.append(Transform3D(Basis.from_scale(scale_b), Vector3(x + cos(a) * r3b * 0.35, th * 0.8 + randf_range(-0.25, 0.4), z + sin(a) * r3b * 0.35)))
				leaf_col.append(Color(0.3, 0.42, 0.17) * shade)

	# Undergrowth between the trunks.
	var bushes := 0
	tries = 0
	while bushes < 150 and tries < 4000:
		tries += 1
		var bx := randf_range(-112.0, 112.0)
		var bz := randf_range(-112.0, 112.0)
		if _tree_blocked(bx, bz, keep):
			continue
		bushes += 1
		var br := randf_range(0.6, 1.2)
		bush_xf.append(Transform3D(Basis.from_scale(Vector3(br * 1.3, br, br * 1.3)), Vector3(bx, br * 0.6, bz)))
		bush_col.append(Color(0.18, 0.26, 0.12) * randf_range(0.8, 1.1))

	_multimesh(_trunk_mesh(), trunk_xf, trunk_col)
	_multimesh(_cone_mesh(), pine_xf, pine_col)
	_multimesh(_sphere_mesh(), leaf_xf, leaf_col)
	_multimesh(_sphere_mesh(), bush_xf, bush_col)


# Spatial grid, so checking spacing stays fast with many trees.
func _add_to_grid(x: float, z: float, grid: Dictionary) -> void:
	var key := Vector2i(int(floor(x / 4.0)), int(floor(z / 4.0)))
	if not grid.has(key):
		grid[key] = []
	grid[key].append(Vector2(x, z))


func _near_tree(x: float, z: float, grid: Dictionary, d: float) -> bool:
	var p := Vector2(x, z)
	var cx := int(floor(x / 4.0))
	var cz := int(floor(z / 4.0))
	for ix in range(cx - 1, cx + 2):
		for iz in range(cz - 1, cz + 2):
			var key := Vector2i(ix, iz)
			if grid.has(key):
				for s in grid[key]:
					if p.distance_to(s) < d:
						return true
	return false


func _multimesh(mesh: Mesh, xforms: Array, colors: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mmi.material_override = m
	mmi.visibility_range_end = 140.0
	add_child(mmi)


func _trunk_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.14
	m.bottom_radius = 0.22
	m.height = 1.0
	return m


func _cone_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 1.0
	m.height = 1.0
	m.radial_segments = 7
	return m


func _sphere_mesh() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 10
	m.rings = 6
	return m



# ================= Mission 02: security cameras and alarm =================

func _build_cameras() -> void:
	var specs := [
		{"pos": Vector3(-4.6, 3.4, -10.2), "yaw": 0.0},      # gate post
		{"pos": Vector3(-38.8, 6.8, -78.8), "yaw": -135.0},  # north-west watch tower
		{"pos": Vector3(38.8, 6.8, -78.8), "yaw": 135.0},    # north-east watch tower
		{"pos": Vector3(30.0, 3.2, -62.0), "yaw": 90.0},     # vehicle depot pole
		{"pos": Vector3(5.1, 3.2, -48.8), "yaw": 180.0},     # villa garden gate post
	]
	var range_m := 30.0
	var half_deg := 42.0
	var cone_mat := _mat(Color(1.0, 0.9, 0.4, 0.045))
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var housing_mat := _mat(Color(0.88, 0.88, 0.86))
	var dark_mat := _mat(Color(0.05, 0.05, 0.06))
	var led_mat := _mat(Color(0.1, 0.9, 0.2), Color(0.1, 0.9, 0.2))
	alarm_lamp_mat = _mat(Color(0.25, 0.04, 0.04), Color(0.25, 0.04, 0.04))

	# Pole for the depot camera.
	_solid(Vector3(30.0, 1.5, -62.0), Vector3(0.4, 3.0, 0.4), Color(0.35, 0.36, 0.38))

	# Alarm control box beside the gate. Its lamp lights when the alarm goes off.
	_vis(Vector3(-5.9, 1.4, -10.3), Vector3(0.35, 0.45, 0.12), Color(0.85, 0.85, 0.8))
	var lamp := _vis(Vector3(-5.9, 1.65, -10.38), Vector3(0.12, 0.12, 0.05), Color(0.2, 0.05, 0.05))
	lamp.material_override = alarm_lamp_mat

	# Alarm status shown on screen.
	var screen := get_viewport().get_visible_rect().size
	lbl_alarm = _hud_label("ALARM: ARMED", Vector2(screen.x - 260.0, 20.0), 18)

	for s in specs:
		var pivot := Node3D.new()
		pivot.position = s["pos"]
		add_child(pivot)
		var camera_body := StaticBody3D.new()
		camera_body.add_to_group("security_cameras")
		var camera_hit := CollisionShape3D.new()
		var camera_shape := SphereShape3D.new()
		camera_shape.radius = 0.42
		camera_hit.shape = camera_shape
		camera_hit.position = Vector3(0.0, 0.0, -0.12)
		camera_body.add_child(camera_hit)
		pivot.add_child(camera_body)

		# CCTV housing, mounting bracket, lens and status light.
		_pivot_box(pivot, Vector3(0.42, 0.26, 0.26), Vector3.ZERO, housing_mat)
		_pivot_box(pivot, Vector3(0.14, 0.14, 0.22), Vector3(0.0, 0.0, 0.24), dark_mat)
		var lens := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.075
		lc.bottom_radius = 0.075
		lc.height = 0.22
		lens.mesh = lc
		lens.material_override = dark_mat
		lens.rotation_degrees.x = 90.0
		lens.position = Vector3(0.0, 0.0, -0.3)
		pivot.add_child(lens)
		var led := MeshInstance3D.new()
		var ls := SphereMesh.new()
		ls.radius = 0.03
		ls.height = 0.06
		led.mesh = ls
		led.material_override = led_mat
		led.position = Vector3(0.15, 0.1, -0.12)
		pivot.add_child(led)

		# Weather hood, reinforced mount, and paired infrared illuminators.
		_pivot_box(pivot, Vector3(0.52, 0.075, 0.42), Vector3(0.0, 0.17, -0.06), dark_mat)
		_pivot_box(pivot, Vector3(0.10, 0.34, 0.10), Vector3(0.0, 0.0, 0.20), housing_mat)
		for ir_x in [-0.105, 0.105]:
			var ir := MeshInstance3D.new()
			var ir_mesh := SphereMesh.new()
			ir_mesh.radius = 0.025
			ir_mesh.height = 0.05
			ir.mesh = ir_mesh
			ir.position = Vector3(ir_x, -0.075, -0.285)
			ir.material_override = _mat(Color(0.12, 0.08, 0.08), Color(0.75, 0.08, 0.035))
			pivot.add_child(ir)

		# Yellow cone that shows what the camera can see.
		var cone := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = range_m * tan(deg_to_rad(half_deg))
		cyl.height = range_m
		cone.mesh = cyl
		cone.material_override = cone_mat
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.rotation_degrees.x = 90.0
		cone.position = Vector3(0.0, 0.0, -0.4 - range_m * 0.5)
		pivot.add_child(cone)

		cameras.append({
			"pivot": pivot,
			"base": deg_to_rad(s["yaw"]),
			"sweep": deg_to_rad(35.0),
			"t": randf() * 6.0,
			"aware": 0.0,
			"led": led_mat,
			"range": range_m,
			"half": half_deg,
			"destroyed": false,
		})


func _pivot_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _update_cameras(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var target: Vector3 = player.global_position + Vector3(0.0, 1.0, 0.0)
	for cam in cameras:
		if cam.get("destroyed", false):
			continue
		cam["t"] += delta * 0.7
		var pivot: Node3D = cam["pivot"]
		pivot.rotation.y = cam["base"] + sin(cam["t"]) * cam["sweep"]
		var seen: bool = _camera_sees(pivot, target, cam["range"], cam["half"])
		if seen:
			cam["aware"] = minf(cam["aware"] + delta * 1.2, 1.0)
		else:
			cam["aware"] = maxf(cam["aware"] - delta * 0.5, 0.0)
		var led: StandardMaterial3D = cam["led"]
		var c := Color(1.0, 0.1, 0.1) if seen else Color(0.1, 0.9, 0.2)
		led.albedo_color = c
		led.emission = c
		if cam["aware"] >= 1.0:
			_raise_alarm(pivot.global_position)
			return


func _destroy_security_camera(camera_body: Node) -> void:
	for cam in cameras:
		if cam.get("destroyed", false):
			continue
		var pivot: Node3D = cam["pivot"]
		if camera_body.get_parent() == pivot:
			cam["destroyed"] = true
			cam["aware"] = 0.0
			pivot.visible = false
			camera_body.set_deferred("collision_layer", 0)
			camera_body.set_deferred("collision_mask", 0)
			var spark := _blob(pivot.global_position, 0.14, Color(1.0, 0.38, 0.08), Color(1.0, 0.18, 0.025))
			var flash_tween := create_tween()
			flash_tween.tween_property(spark, "scale", Vector3.ZERO, 0.28)
			flash_tween.tween_callback(spark.queue_free)
			_status("CCTV DESTROYED. Camera feed offline.", 2.5)
			return


func _camera_sees(pivot: Node3D, target: Vector3, range_m: float, half_deg: float) -> bool:
	var eye := pivot.global_position
	var to := target - eye
	if to.length() > range_m:
		return false
	var fwd := -pivot.global_transform.basis.z
	if rad_to_deg(fwd.angle_to(to)) > half_deg:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] == player


func _raise_alarm(pos: Vector3) -> void:
	if alarm_on:
		return
	alarm_on = true
	if alarm_lamp_mat:
		alarm_lamp_mat.emission = Color(1.0, 0.06, 0.025)
		alarm_lamp_mat.albedo_color = Color(1.0, 0.06, 0.025)
	_status("SECURITY BREACH. Facility alarm activated.", 6.0)
	if alarm_sfx == null:
		alarm_sfx = AudioStreamPlayer3D.new()
		alarm_sfx.name = "FacilityAlarm3D"
		alarm_sfx.max_distance = 120.0
		alarm_sfx.unit_size = 14.0
		add_child(alarm_sfx)
	alarm_sfx.global_position = pos
	alarm_sfx.stream = _alarm_stream()
	alarm_sfx.volume_db = -4.0
	alarm_sfx.play()
	get_tree().call_group("enemies", "alarm", pos)


func _reset_alarm() -> void:
	alarm_on = false
	if alarm_lamp_mat:
		alarm_lamp_mat.emission = Color(0.25, 0.04, 0.04)
		alarm_lamp_mat.albedo_color = Color(0.25, 0.04, 0.04)
	if alarm_sfx:
		alarm_sfx.stop()
	for cam in cameras:
		cam["aware"] = 0.0


# Layered two-tone security siren, looped until the alarm is reset.
func _alarm_stream() -> AudioStreamWAV:
	# Layered industrial warning siren: slow rising/falling horn, upper harmonic,
	# low mechanical pulse and a slight buzzy edge. The full sweep loops cleanly.
	var rate: int = 24000
	var seconds: float = 4.8
	var n: int = int(seconds * float(rate))
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var phase_main: float = 0.0
	var phase_low: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(rate)
		var sweep: float = 0.5 - 0.5 * cos(TAU * t / seconds)
		var freq: float = lerpf(620.0, 1180.0, sweep)
		phase_main += TAU * freq / float(rate)
		phase_low += TAU * 96.0 / float(rate)
		var pulse: float = 0.84 + 0.16 * sin(TAU * 2.0 * t)
		var horn: float = sin(phase_main) * 0.30
		horn += sin(phase_main * 2.0) * 0.105
		horn += sin(phase_main * 3.0) * 0.035
		var low_klaxon: float = sin(phase_low) * 0.075
		var rasp: float = sin(phase_main * 5.0 + 0.3) * 0.018
		var envelope: float = minf(minf(t / 0.06, (seconds - t) / 0.06), 1.0)
		var sample: float = (horn + low_klaxon + rasp) * pulse * clampf(envelope, 0.0, 1.0)
		buf.encode_s16(i * 2, int(clampf(sample, -0.9, 0.9) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = buf
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


# Called on every guard when the alarm goes off: they investigate the camera that spotted you.
func alarm(pos: Vector3) -> void:
	if sentry:
		return
	if st == S_DEAD or st == S_ALERT:
		return
	lk = pos
	_e_set(S_INVEST)
	inv_t = 25.0


# Ice patches: [x, z, width, depth]. Players slide on them.
const ICE_RECTS := [[0.0, 45.0, 11.0, 25.0], [-62.0, -62.0, 30.0, 24.0], [58.0, 8.0, 18.0, 14.0]]


func _build_ice() -> void:
	# A naturally irregular frozen pond: continuous ice sheet, soft shoreline,
	# subtle surface variation and branching fractures. No chunky polygon shards.
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.42, 0.57, 0.64)
	ice_mat.roughness = 0.19
	ice_mat.metallic = 0.04
	ice_mat.clearcoat_enabled = true
	ice_mat.clearcoat = 0.72
	ice_mat.clearcoat_roughness = 0.12
	ice_mat.vertex_color_use_as_albedo = true

	for patch_index in range(ICE_RECTS.size()):
		var r: Array = ICE_RECTS[patch_index]
		var rng := RandomNumberGenerator.new()
		rng.seed = 11831 + patch_index * 997
		var nx := 34
		var nz := 28
		var width := float(r[2]) * 0.5
		var depth := float(r[3]) * 0.5
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for iz in range(nz + 1):
			for ix in range(nx + 1):
				var u := float(ix) / float(nx) * 2.0 - 1.0
				var v := float(iz) / float(nz) * 2.0 - 1.0
				var angle := atan2(v, u)
				var edge_noise := 1.0 + 0.045 * sin(angle * 3.0 + float(patch_index)) + 0.035 * cos(angle * 7.0) + 0.018 * sin(angle * 13.0)
				var radial := sqrt(u * u + v * v)
				var edge_factor := edge_noise
				var px := u * width * edge_factor
				var pz := v * depth * edge_factor
				var ripple := sin(px * 0.31 + float(patch_index)) * cos(pz * 0.27) * 0.012
				var y := 0.055 + ripple + rng.randf_range(-0.003, 0.003)
				verts.append(Vector3(px, y, pz))
				normals.append(Vector3.UP)
				var tint_noise := rng.randf_range(-0.035, 0.035)
				var edge_t := clampf((radial - 0.68) / 0.32, 0.0, 1.0)
				var base := Color(0.48, 0.64, 0.7).lerp(Color(0.32, 0.48, 0.56), edge_t * 0.35)
				colors.append(Color(clampf(base.r + tint_noise, 0.0, 1.0), clampf(base.g + tint_noise, 0.0, 1.0), clampf(base.b + tint_noise, 0.0, 1.0), 1.0))
		for iz in range(nz):
			for ix in range(nx):
				var u := (float(ix) + 0.5) / float(nx) * 2.0 - 1.0
				var v := (float(iz) + 0.5) / float(nz) * 2.0 - 1.0
				var a := atan2(v, u)
				var limit := 1.0 + 0.045 * sin(a * 3.0 + float(patch_index)) + 0.035 * cos(a * 7.0) + 0.018 * sin(a * 13.0)
				if sqrt(u * u + v * v) > limit:
					continue
				var i0 := iz * (nx + 1) + ix
				var i1 := i0 + 1
				var i2 := i0 + nx + 1
				var i3 := i2 + 1
				indices.append_array(PackedInt32Array([i0, i2, i1, i1, i2, i3]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var ice_mesh := ArrayMesh.new()
		ice_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var ice_instance := MeshInstance3D.new()
		ice_instance.mesh = ice_mesh
		ice_instance.material_override = ice_mat
		ice_instance.position = Vector3(float(r[0]), 0.0, float(r[1]))
		ice_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ice_instance)

		# Soft snow build-up around the pond edge.
		var shore_xforms: Array = []
		var shore_colors: Array = []
		for i in range(64):
			var a := float(i) / 64.0 * TAU
			var edge := 1.0 + 0.045 * sin(a * 3.0 + float(patch_index)) + 0.035 * cos(a * 7.0) + 0.018 * sin(a * 13.0)
			var sx := cos(a) * width * edge
			var sz := sin(a) * depth * edge
			var radius := rng.randf_range(0.35, 0.85)
			var shore_scale := Vector3(radius * rng.randf_range(1.0, 1.8), radius * 0.22, radius * rng.randf_range(0.8, 1.5))
			shore_xforms.append(Transform3D(Basis.from_scale(shore_scale), Vector3(float(r[0]) + sx, 0.035, float(r[1]) + sz)))
			shore_colors.append(Color(0.72, 0.79, 0.83) * rng.randf_range(0.9, 1.05))
		_multimesh(_sphere_mesh(), shore_xforms, shore_colors)

		# Branching cracks are thin, irregular line paths embedded in the ice.
		var crack_mat := StandardMaterial3D.new()
		crack_mat.albedo_color = Color(0.16, 0.27, 0.32, 0.7)
		crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for crack_index in range(9):
			var start := Vector3(rng.randf_range(-width * 0.55, width * 0.55), 0.071, rng.randf_range(-depth * 0.55, depth * 0.55))
			var direction := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
			var crack_st := SurfaceTool.new()
			crack_st.begin(Mesh.PRIMITIVE_LINE_STRIP)
			var point := start
			crack_st.add_vertex(point)
			for segment in range(5):
				direction = direction.rotated(rng.randf_range(-0.48, 0.48))
				point += Vector3(direction.x * rng.randf_range(0.5, 1.5), 0.0, direction.y * rng.randf_range(0.5, 1.5))
				crack_st.add_vertex(point)
			crack_st.add_vertex(point)
			var crack_mesh := crack_st.commit()
			var crack_instance := MeshInstance3D.new()
			crack_instance.mesh = crack_mesh
			crack_instance.material_override = crack_mat
			crack_instance.position = Vector3(float(r[0]), 0.0, float(r[1]))
			crack_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(crack_instance)


func _on_ice(p: Vector3) -> bool:
	for r in ice_rects:
		if absf(p.x - r[0]) < r[2] * 0.5 and absf(p.z - r[1]) < r[3] * 0.5:
			return true
	return false


func _build_snow() -> void:
	snow = CPUParticles3D.new()
	snow.amount = 250
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(12.0, 1.0, 12.0)
	snow.direction = Vector3(0.0, -1.0, 0.0)
	snow.spread = 12.0
	snow.gravity = Vector3(0.4, -1.2, 0.2)
	snow.initial_velocity_min = 0.2
	snow.initial_velocity_max = 0.6
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.2
	var flake := SphereMesh.new()
	flake.radius = 0.035
	flake.height = 0.07
	flake.radial_segments = 4
	flake.rings = 2
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.97, 1.0)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	snow.mesh = flake
	snow.position = Vector3(0.0, 9.0, 0.0)
	add_child(snow)
	snow.emitting = true


# Guards far from the player are hidden and stop thinking, which saves a lot of processing.
func _cull_enemies() -> void:
	if player == null or not is_instance_valid(player):
		return
	var pp: Vector3 = player.global_position
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var near: bool = e.global_position.distance_to(pp) < 70.0
		e.visible = near
		e.set_physics_process(near)


# ================= Weapon slots and silenced pistol =================

func _switch_slot(n: int) -> void:
	if n == slot or reloading:
		return
	if slot == 1:
		rifle_mag = mag
		rifle_res = reserve
	else:
		pistol_mag = mag
		pistol_res = reserve
	slot = n
	if slot == 1:
		mag = rifle_mag
		reserve = rifle_res
		mag_max = MAG_SIZE
	else:
		mag = pistol_mag
		reserve = pistol_res
		mag_max = 10
	weapon.visible = slot == 1
	pistol_node.visible = slot == 2
	fire_cd = 0.35
	ammo_changed.emit()


func _build_pistol() -> void:
	var dark := _mat(Color(0.08, 0.08, 0.09))
	var grip := _mat(Color(0.12, 0.1, 0.08))
	_part_on(pistol_node, Vector3(0.05, 0.06, 0.2), Vector3(0.0, 0.02, -0.06), dark)
	_part_on(pistol_node, Vector3(0.045, 0.13, 0.06), Vector3(0.0, -0.07, 0.0), grip)
	_part_on(pistol_node, Vector3(0.03, 0.02, 0.05), Vector3(0.0, -0.01, 0.04), dark)
	var sup := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.024
	sc.bottom_radius = 0.024
	sc.height = 0.16
	sup.mesh = sc
	sup.material_override = dark
	sup.rotation_degrees.x = 90.0
	sup.position = Vector3(0.0, 0.02, -0.25)
	pistol_node.add_child(sup)


func _part_on(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


# ================= Tactical map (tablet) =================

func _toggle_tablet() -> void:
	tablet_open = not tablet_open
	tablet.visible = tablet_open
	if player:
		player.set_controls(not tablet_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and phase == PHASE_ACTIVE)


func _open_gate_hack() -> void:
	hack_active = true
	hack_step = 0
	tablet_open = true
	tablet.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.set_controls(false)
	_status("Gate locker connected. Enter the access sequence on your field tablet.", 3.0)
	tablet.queue_redraw()


func _close_gate_hack() -> void:
	hack_active = false
	tablet_open = false
	tablet.visible = false
	if phase == PHASE_ACTIVE:
		_set_captured(true)
		if player:
			player.set_controls(true)


func _handle_gate_hack_input(event: InputEvent) -> void:
	if event.is_action_pressed("tablet") or event.is_action_pressed("ui_cancel"):
		_close_gate_hack()
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var required := [KEY_2, KEY_4, KEY_1]
	if hack_step < required.size() and key_event.keycode == required[hack_step]:
		hack_step += 1
		if hack_step >= required.size():
			_status("Access sequence accepted. Press ENTER to release the gate lock.", 4.0)
		else:
			_status("Encryption key accepted: %d / 3" % hack_step, 1.5)
		tablet.queue_redraw()
	elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		if hack_step >= required.size():
			_unlock_security_gate()
		else:
			hack_step = 0
			_status("ACCESS DENIED. Sequence reset.", 2.0)
			tablet.queue_redraw()
	elif key_event.keycode >= KEY_0 and key_event.keycode <= KEY_9:
		hack_step = 0
		_status("Incorrect key. Sequence reset.", 1.5)
		tablet.queue_redraw()


func _unlock_security_gate() -> void:
	security_gate_open = true
	hack_active = false
	tablet_open = false
	tablet.visible = false
	if gate_collision:
		gate_collision.set_deferred("disabled", true)
	if gate_panel:
		if gate_tween and gate_tween.is_running():
			gate_tween.kill()
		gate_tween = create_tween()
		gate_tween.set_trans(Tween.TRANS_CUBIC)
		gate_tween.set_ease(Tween.EASE_IN_OUT)
		gate_tween.tween_property(gate_panel, "position:x", 0.06, 0.08)
		gate_tween.tween_property(gate_panel, "position:x", -0.06, 0.08)
		gate_tween.tween_property(gate_panel, "position:x", 0.0, 0.08)
		gate_tween.tween_property(gate_panel, "position:y", 3.35, 3.8)
	_set_captured(true)
	_play_gate_motor()
	_status("ACCESS GRANTED. Hydraulic security barrier rising.", 5.0)
	if player:
		player.set_controls(true)


func _play_gate_motor() -> void:
	if gate_sfx == null:
		gate_sfx = AudioStreamPlayer.new()
		add_child(gate_sfx)
	gate_sfx.stream = _gate_motor_stream()
	gate_sfx.volume_db = -8.0
	gate_sfx.play()


func _gate_motor_stream() -> AudioStreamWAV:
	var rate := 22050
	var n := int(4.0 * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var envelope := minf(t / 0.18, 1.0) * minf((4.0 - t) / 0.45, 1.0)
		var grind := sin(TAU * (48.0 + 9.0 * sin(TAU * 0.35 * t)) * t) * 0.22
		var metal := sin(TAU * 173.0 * t) * 0.055 + sin(TAU * 287.0 * t) * 0.025
		var rattle := (randf() * 2.0 - 1.0) * 0.035
		var sample := (grind + metal + rattle) * clampf(envelope, 0.0, 1.0)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# World position to a point on the tablet map. The map covers -120..120 in x and z, north at the top.
func _mp(x: float, z: float, m0: Vector2, s: float) -> Vector2:
	return m0 + Vector2((x + 120.0) / 240.0 * s, (z + 120.0) / 240.0 * s)


func _mrect(x0: float, z0: float, x1: float, z1: float, m0: Vector2, s: float) -> Rect2:
	var a := _mp(x0, z0, m0, s)
	var b := _mp(x1, z1, m0, s)
	return Rect2(a, b - a)


func _draw_tablet() -> void:
	var c := tablet
	if hack_active:
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(520.0, 380.0)), Color(0.025, 0.045, 0.055, 0.98))
		c.draw_rect(Rect2(Vector2(8.0, 8.0), Vector2(504.0, 364.0)), Color(0.07, 0.12, 0.14), false, 2.0)
		c.draw_rect(Rect2(Vector2(18.0, 18.0), Vector2(484.0, 44.0)), Color(0.08, 0.22, 0.23))
		c.draw_string(ThemeDB.fallback_font, Vector2(32.0, 46.0), "BLACK HORIZON  //  FIELD ACCESS TERMINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.96, 0.87))
		c.draw_string(ThemeDB.fallback_font, Vector2(32.0, 91.0), "REMOTE GATE LOCKER  /  ENCRYPTED CONTROL BUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.82, 0.82))
		c.draw_string(ThemeDB.fallback_font, Vector2(32.0, 126.0), "AUTHENTICATION SEQUENCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.48, 0.72, 0.72))
		for i in range(3):
			var r := Rect2(Vector2(34.0 + float(i) * 154.0, 148.0), Vector2(136.0, 68.0))
			c.draw_rect(r, Color(0.1, 0.2, 0.21) if i < hack_step else Color(0.045, 0.085, 0.095), true)
			c.draw_rect(r, Color(0.28, 0.82, 0.7) if i < hack_step else Color(0.2, 0.34, 0.36), false, 2.0)
			var label: String = ["02", "04", "01"][i] if i < hack_step else "— —"
			c.draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 42.0, r.position.y + 44.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.52, 1.0, 0.84) if i < hack_step else Color(0.45, 0.58, 0.59))
		var msg := "SEQUENCE VERIFIED  /  PRESS ENTER TO UNLOCK" if hack_step >= 3 else "ENTER KEYS:  2   →   4   →   1"
		c.draw_string(ThemeDB.fallback_font, Vector2(32.0, 260.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.35, 1.0, 0.68) if hack_step >= 3 else Color(0.86, 0.9, 0.88))
		c.draw_string(ThemeDB.fallback_font, Vector2(32.0, 318.0), "T / ESC  CLOSE TABLET", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.58, 0.68, 0.7))
		c.draw_string(ThemeDB.fallback_font, Vector2(32.0, 348.0), "LOCAL OVERRIDE DISABLED  //  SIGNAL ENCRYPTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.38, 0.52, 0.54))
		return
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(520.0, 380.0)), Color(0.08, 0.09, 0.1, 0.97))
	c.draw_rect(Rect2(Vector2(12.0, 12.0), Vector2(496.0, 356.0)), Color(0.02, 0.03, 0.03))
	c.draw_string(ThemeDB.fallback_font, Vector2(24.0, 34.0), "TACTICAL MAP   (press M to close)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 0.7))

	var m0 := Vector2(40.0, 52.0)
	var s := 300.0
	c.draw_rect(Rect2(m0, Vector2(s, s)), Color(0.12, 0.2, 0.1))
	c.draw_rect(_mrect(-75.0, -72.0, -49.0, -52.0, m0, s), Color(0.6, 0.78, 0.9))
	c.draw_line(_mp(0.0, 120.0, m0, s), _mp(0.0, -10.0, m0, s), Color(0.7, 0.7, 0.68), 3.0)

	# Compound, villa, garden, barracks, depot and watchtowers
	c.draw_rect(_mrect(-40.0, -80.0, 40.0, -10.0, m0, s), Color(0.3, 0.3, 0.3), false, 2.0)
	c.draw_rect(_mrect(-20.0, -76.0, 20.0, -48.0, m0, s), Color(0.5, 0.5, 0.45), false, 1.5)
	c.draw_rect(_mrect(-16.0, -71.0, 16.0, -55.0, m0, s), Color(0.65, 0.62, 0.55))
	c.draw_rect(_mrect(-28.0, -33.5, -16.0, -26.5, m0, s), Color(0.5, 0.52, 0.48))
	c.draw_rect(_mrect(16.0, -33.5, 28.0, -26.5, m0, s), Color(0.5, 0.52, 0.48))
	c.draw_rect(_mrect(21.0, -75.0, 35.0, -69.0, m0, s), Color(0.45, 0.45, 0.5))
	for w in [Vector2(-55.0, -30.0), Vector2(55.0, -40.0), Vector2(-55.0, -100.0), Vector2(48.0, -100.0)]:
		c.draw_circle(_mp(w.x, w.y, m0, s), 3.0, Color(0.8, 0.8, 0.8))

	# Cameras, with the direction each one faces
	for cam in cameras:
		var pv: Node3D = cam["pivot"]
		var cp := _mp(pv.global_position.x, pv.global_position.z, m0, s)
		var fwd := -pv.global_transform.basis.z
		c.draw_line(cp, cp + Vector2(fwd.x, fwd.z).normalized() * 14.0, Color(1.0, 0.9, 0.3, 0.8), 2.0)
		c.draw_circle(cp, 3.0, Color(1.0, 0.9, 0.3))

	# Objectives
	c.draw_circle(_mp(drive_pos.x, drive_pos.z, m0, s), 5.0, Color(1.0, 0.8, 0.2))
	c.draw_circle(_mp(ext_pos.x, ext_pos.z, m0, s), 7.0, Color(0.3, 1.0, 0.4))

	# Guards: shown when close, or when the alarm is raised
	for e in enemies:
		if not is_instance_valid(e) or e.st == 4:
			continue
		var gp: Vector3 = e.global_position
		var close: bool = player != null and gp.distance_to(player.global_position) < 40.0
		var show_it: bool = alarm_on or e.st == 2 or close
		if show_it:
			c.draw_circle(_mp(gp.x, gp.z, m0, s), 3.5, Color(1.0, 0.25, 0.2))

	# You: an arrow that points where you face
	if player:
		var pp := _mp(player.global_position.x, player.global_position.z, m0, s)
		var f: Vector3 = -player.global_transform.basis.z
		var fw := Vector2(f.x, f.z).normalized()
		var side := Vector2(-fw.y, fw.x)
		c.draw_colored_polygon(PackedVector2Array([pp + fw * 9.0, pp + side * 5.0 - fw * 5.0, pp - side * 5.0 - fw * 5.0]), Color(0.9, 1.0, 0.9))

	c.draw_string(ThemeDB.fallback_font, Vector2(24.0, 372.0), "Yellow: camera   Red: guard   Green: extraction   Gold: laptop   White: you", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.85, 0.8))


# ================= Open forest: road, distant views and invisible limits =================

func _invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	level.add_child(body)


# Dark, worn asphalt access road with a single broken white centre line.
func _build_road() -> void:
	# Main asphalt surface and slightly lighter worn wheel paths.
	_vis(Vector3(0.0, 0.02, 54.0), Vector3(7.2, 0.08, 136.0), Color(0.105, 0.12, 0.13))
	for tx in [-1.75, 1.75]:
		_vis(Vector3(tx, 0.067, 54.0), Vector3(1.05, 0.012, 136.0), Color(0.14, 0.15, 0.15))
	# Narrow, broken white centre marking: one line, like a real two-way road.
	var mark_z := -10.0
	while mark_z < 120.0:
		_vis(Vector3(0.0, 0.071, mark_z + 1.8), Vector3(0.13, 0.014, 3.6), Color(0.88, 0.89, 0.85))
		mark_z += 7.2
	# Gravel shoulders blend the asphalt into the snowy forest floor.
	for side in [-1.0, 1.0]:
		_vis(Vector3(side * 4.0, 0.015, 54.0), Vector3(1.0, 0.05, 136.0), Color(0.28, 0.27, 0.24))
	var bank := Color(0.88, 0.91, 0.94)
	var z := -10.0
	while z < 120.0:
		var seg := randf_range(6.0, 14.0)
		var h := randf_range(0.25, 0.55)
		_vis(Vector3(-4.9, h * 0.5, z + seg * 0.5), Vector3(0.8, h, seg), bank)
		_vis(Vector3(4.9, h * 0.5, z + seg * 0.5), Vector3(0.8, h, seg), bank)
		z += seg + randf_range(0.5, 3.0)


# Tree line and snowy mountains beyond the map edge, so the open area still feels like a forest.
func _build_far_view() -> void:
	seed(23)
	var xf: Array = []
	var cols: Array = []
	for i in range(320):
		var ang := randf() * TAU
		var rad := randf_range(130.0, 190.0)
		var hgt := randf_range(16.0, 30.0)
		var w := randf_range(4.0, 6.5)
		xf.append(Transform3D(Basis.from_scale(Vector3(w, hgt, w)), Vector3(cos(ang) * rad, hgt * 0.5, sin(ang) * rad)))
		cols.append(Color(0.08, 0.16, 0.1).lerp(Color(0.85, 0.9, 0.95), 0.2) * randf_range(0.85, 1.1))
	_far_multimesh(_cone_mesh(), xf, cols)

	var mxf: Array = []
	var mcols: Array = []
	for i in range(10):
		var ang2 := float(i) / 10.0 * TAU + randf() * 0.3
		var mr := randf_range(70.0, 100.0)
		var mh := randf_range(60.0, 110.0)
		mxf.append(Transform3D(Basis.from_scale(Vector3(mr, mh, mr)), Vector3(cos(ang2) * 260.0, mh * 0.5, sin(ang2) * 260.0)))
		mcols.append(Color(0.42, 0.47, 0.54).lerp(Color(0.95, 0.97, 1.0), randf_range(0.2, 0.5)))
	_far_multimesh(_cone_mesh(), mxf, mcols)


# Like _multimesh, but without a distance limit, so distant scenery stays visible.
func _far_multimesh(mesh: Mesh, xforms: Array, colors: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mmi.material_override = m
	add_child(mmi)


# ================= Villa: stepped two-storey house, roof terrace, pool and garden =================
# Layout in world units. The house stands inside the walled garden (x -20..20, z -76..-48) and
# faces the gate, which is on +z. Ground floor: x -16..16, z -71..-55. First floor, set back on
# every side: x -13..13, z -69..-57. The ground-floor roof around it is a walkable terrace behind
# rails. The first-floor roof carries sentries. The central-hall stair climbs through a hole in
# the ground-floor ceiling slab.

# Set to true to spawn the guards and sentries again (both missions).
const ENEMIES_ENABLED := false

const VILLA_H1 := 3.3      # ground-floor wall height
const VILLA_FLOOR2 := 3.6  # ground-floor ceiling top, which is the first-floor level
const VILLA_ROOF := 7.2    # first-floor roof top


func _build_villa() -> void:
	var stone := Color(0.20, 0.22, 0.23)
	var plaster := Color(0.34, 0.36, 0.37)
	var inner := Color(0.56, 0.55, 0.50)
	var trim := Color(0.10, 0.12, 0.13)
	var floor_col := Color(0.25, 0.27, 0.26)
	var wood := Color(0.16, 0.12, 0.09)
	var iron := Color(0.07, 0.09, 0.10)
	_villa_garden()
	_villa_ground_floor(stone, inner, trim, floor_col)
	_villa_first_floor(plaster, inner, trim)
	_villa_roof_and_terrace(plaster, iron)
	_villa_porch(stone, trim, iron)
	_villa_furniture(wood)
	_villa_decor()


# Walled garden (same wall line as before), gate, drive, lap pool and cypress trees.
func _villa_garden() -> void:
	var wall := Color(0.16, 0.18, 0.19)
	var steel := Color(0.08, 0.10, 0.11)
	_solid(Vector3(-12.25, 1.1, -48.0), Vector3(15.5, 2.2, 0.4), wall)
	_solid(Vector3(12.25, 1.1, -48.0), Vector3(15.5, 2.2, 0.4), wall)
	_solid(Vector3(-5.1, 1.8, -48.0), Vector3(1.2, 3.6, 1.2), wall)
	_solid(Vector3(5.1, 1.8, -48.0), Vector3(1.2, 3.6, 1.2), wall)
	_vis(Vector3(0.0, 3.5, -48.0), Vector3(10.2, 0.5, 1.2), steel)
	_solid(Vector3(-20.0, 1.1, -62.0), Vector3(0.4, 2.2, 28.0), wall)
	_solid(Vector3(20.0, 1.1, -62.0), Vector3(0.4, 2.2, 28.0), wall)
	_solid(Vector3(0.0, 1.1, -76.0), Vector3(40.0, 2.2, 0.4), wall)
	# Clean private forecourt: clipped lawn and a dark, stone-free vehicle approach.
	_vis(Vector3(0.0, 0.02, -62.0), Vector3(39.0, 0.04, 27.0), Color(0.12, 0.17, 0.12))
	_vis(Vector3(0.0, 0.045, -51.5), Vector3(7.0, 0.02, 7.0), Color(0.19, 0.20, 0.19))
	# No boulders, cypress trees or ground-level pool inside the villa perimeter.
	for x in [-18.9, 18.9]:
		_vis(Vector3(x, 1.15, -62.0), Vector3(0.12, 2.3, 23.0), Color(0.12, 0.15, 0.14))
	for x in [-7.0, 7.0]:
		for z in [-51.0, -57.0, -64.0, -70.0]:
			_cyl_visual(Vector3(x, 0.42, z), 0.09, 0.84, steel)
			_blob(Vector3(x, 0.86, z), 0.07, Color(0.7, 0.78, 0.72), Color(0.25, 0.38, 0.3))


# Ground floor: stone walls with real window and door openings, a west living room, an east dining room,
# a central hall and the stair.
func _villa_ground_floor(stone: Color, inner: Color, trim: Color, floor_col: Color) -> void:
	var h := VILLA_H1
	var glass := _villa_glass()
	_vis(Vector3(0.0, 0.05, -63.0), Vector3(32.0, 0.02, 16.0), floor_col)

	# Outer walls. s is the outward side: +1 for the front (+z) and east (+x) faces, -1 for the rear and west faces.
	_villa_wall(true, -55.0, 1.0, -16.0, 16.0, 0.0, h, 0.4, stone, trim, glass, [
		[-13.7, -12.3, 1.0, 2.4, 0, true],
		[-9.7, -8.3, 1.0, 2.4, 0, true],
		[-1.4, 1.4, 0.0, 2.7, 1, false],
		[8.3, 9.7, 1.0, 2.4, 0, true],
		[12.3, 13.7, 1.0, 2.4, 0, true]])
	_villa_wall(true, -71.0, -1.0, -16.0, 16.0, 0.0, h, 0.4, stone, trim, glass, [
		[-12.7, -11.3, 1.0, 2.4, 0, true],
		[-9.7, -8.3, 1.0, 2.4, 0, true],
		[8.3, 9.7, 1.0, 2.4, 0, true],
		[11.3, 12.7, 1.0, 2.4, 0, true]])
	_villa_wall(false, -16.0, -1.0, -71.0, -55.0, 0.0, h, 0.4, stone, trim, glass, [
		[-68.7, -67.3, 1.0, 2.4, 0, true],
		[-60.7, -59.3, 1.0, 2.4, 0, true]])
	_villa_wall(false, 16.0, 1.0, -71.0, -55.0, 0.0, h, 0.4, stone, trim, glass, [
		[-68.7, -67.3, 1.0, 2.4, 0, true],
		[-60.7, -59.3, 1.0, 2.4, 0, true]])

	# Interior partitions with doorways. The open leaves swing into the rooms.
	_villa_wall(false, -6.0, 1.0, -71.0, -55.0, 0.0, h, 0.3, inner, trim, glass, [[-63.8, -61.8, 0.0, 2.3, 1, false]])
	_villa_wall(false, 6.0, -1.0, -71.0, -55.0, 0.0, h, 0.3, inner, trim, glass, [[-63.8, -61.8, 0.0, 2.3, 1, false]])

	# Ceiling slab of the ground floor, which is also the terrace floor. The hole is the stair opening.
	var slab := Color(0.6, 0.56, 0.5)
	_solid(Vector3(0.0, 3.45, -68.25), Vector3(32.0, 0.3, 5.5), slab)
	_solid(Vector3(0.0, 3.45, -57.25), Vector3(32.0, 0.3, 4.5), slab)
	_solid(Vector3(-10.25, 3.45, -62.5), Vector3(11.5, 0.3, 6.0), slab)
	_solid(Vector3(7.25, 3.45, -62.5), Vector3(17.5, 0.3, 6.0), slab)

	# Stair in the central hall: 20 solid treads, 0.18 m rise and 0.3 m run. Tagged for the climb check.
	var tread := Color(0.58, 0.55, 0.5)
	for k in range(20):
		var top: float = float(k + 1) * 0.18
		var zc: float = -59.5 - (float(k) + 0.5) * 0.3
		_solid(Vector3(-3.0, top * 0.5, zc), Vector3(3.0, top, 0.3), tread).add_to_group("stairs")

	# Cornice band around the ground floor, and lamps at the entrance.
	_vis(Vector3(0.0, 3.37, -54.7), Vector3(32.4, 0.14, 0.2), trim)
	_vis(Vector3(0.0, 3.37, -71.3), Vector3(32.4, 0.14, 0.2), trim)
	_vis(Vector3(-16.3, 3.37, -63.0), Vector3(0.2, 0.14, 16.4), trim)
	_vis(Vector3(16.3, 3.37, -63.0), Vector3(0.2, 0.14, 16.4), trim)
	_wall_lamp(Vector3(-2.2, 2.7, -54.7))
	_wall_lamp(Vector3(2.2, 2.7, -54.7))


# First floor: plaster walls, two bedrooms and a landing, with a balcony door onto the terrace.
func _villa_first_floor(plaster: Color, inner: Color, trim: Color) -> void:
	var y0 := VILLA_FLOOR2
	var y1 := VILLA_ROOF - 0.3
	var glass := _villa_glass()
	_villa_wall(true, -69.0, -1.0, -13.0, 13.0, y0, y1, 0.4, plaster, trim, glass, [
		[-10.3, -8.7, 4.5, 5.9, 0, false],
		[8.7, 10.3, 4.5, 5.9, 0, false]])
	_villa_wall(true, -57.0, 1.0, -13.0, 13.0, y0, y1, 0.4, plaster, trim, glass, [
		[-10.3, -8.7, 4.5, 5.9, 0, false],
		[-1.4, 1.4, y0, 6.1, 1, false],
		[8.7, 10.3, 4.5, 5.9, 0, false]])
	_villa_wall(false, -13.0, -1.0, -69.0, -57.0, y0, y1, 0.4, plaster, trim, glass, [
		[-66.8, -65.2, 4.5, 5.9, 0, false],
		[-60.8, -59.2, 4.5, 5.9, 0, false]])
	_villa_wall(false, 13.0, 1.0, -69.0, -57.0, y0, y1, 0.4, plaster, trim, glass, [
		[-66.8, -65.2, 4.5, 5.9, 0, false],
		[-60.8, -59.2, 4.5, 5.9, 0, false]])
	_villa_wall(false, -6.0, 1.0, -69.0, -57.0, y0, y1, 0.3, inner, trim, glass, [[-63.8, -61.8, y0, y0 + 2.3, 1, false]])
	_villa_wall(false, 6.0, -1.0, -69.0, -57.0, y0, y1, 0.3, inner, trim, glass, [[-63.8, -61.8, y0, y0 + 2.3, 1, false]])

	# Cornice under the roof.
	_vis(Vector3(0.0, 6.92, -69.2), Vector3(26.6, 0.16, 0.2), trim)
	_vis(Vector3(0.0, 6.92, -56.8), Vector3(26.6, 0.16, 0.2), trim)
	_vis(Vector3(-13.2, 6.92, -63.0), Vector3(0.2, 0.16, 12.4), trim)
	_vis(Vector3(13.2, 6.92, -63.0), Vector3(0.2, 0.16, 12.4), trim)

# Roof slab with parapet and rooftop plant, plus the terrace rails on the ground-floor roof.
func _villa_roof_and_terrace(plaster: Color, iron: Color) -> void:
	var roof := Color(0.42, 0.41, 0.38)
	_solid(Vector3(0.0, VILLA_ROOF - 0.15, -63.0), Vector3(26.0, 0.3, 12.0), roof)
	var pc := VILLA_ROOF + 0.4
	_solid(Vector3(0.0, pc, -68.9), Vector3(26.0, 0.8, 0.3), plaster)
	_solid(Vector3(0.0, pc, -57.1), Vector3(26.0, 0.8, 0.3), plaster)
	_solid(Vector3(-12.9, pc, -63.0), Vector3(0.3, 0.8, 12.0), plaster)
	_solid(Vector3(12.9, pc, -63.0), Vector3(0.3, 0.8, 12.0), plaster)

	_villa_rooftop_pool()
	_roof_unit(Vector3(-4.5, VILLA_ROOF + 0.3, -65.5), Vector3(2.2, 0.6, 1.4))
	_roof_unit(Vector3(4.5, VILLA_ROOF + 0.25, -65.5), Vector3(1.8, 0.5, 1.2))
	_cyl_visual(Vector3(9.5, VILLA_ROOF + 0.9, -65.5), 0.9, 1.8, Color(0.3, 0.32, 0.32))

	# Terrace rails around the ground-roof ring. They are solid so nobody walks off the edge.
	_balcony_rail(Vector3(-15.9, 0.0, -63.0), Vector3(0.2, 0.0, 16.0), iron)
	_balcony_rail(Vector3(15.9, 0.0, -63.0), Vector3(0.2, 0.0, 16.0), iron)
	_balcony_rail(Vector3(0.0, 0.0, -70.9), Vector3(32.0, 0.0, 0.2), iron)
	_balcony_rail(Vector3(-10.5, 0.0, -55.1), Vector3(11.0, 0.0, 0.2), iron)
	_balcony_rail(Vector3(10.5, 0.0, -55.1), Vector3(11.0, 0.0, 0.2), iron)


# Private rooftop pool with coping, dark tile rim and reflective water.
func _villa_rooftop_pool() -> void:
	var y := VILLA_ROOF + 0.08
	var coping := Color(0.72, 0.73, 0.70)
	var tile := Color(0.035, 0.075, 0.085)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.035, 0.30, 0.38, 0.88)
	water.metallic = 0.28
	water.roughness = 0.12
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.clearcoat_enabled = true
	water.clearcoat = 0.9
	_box(Vector3(0.0, y + 0.12, -63.0), Vector3(8.4, 0.22, 3.8), tile)
	_box(Vector3(0.0, y + 0.25, -65.0), Vector3(8.6, 0.28, 0.18), coping)
	_box(Vector3(0.0, y + 0.25, -61.0), Vector3(8.6, 0.28, 0.18), coping)
	_box(Vector3(-4.2, y + 0.25, -63.0), Vector3(0.18, 0.28, 3.8), coping)
	_box(Vector3(4.2, y + 0.25, -63.0), Vector3(0.18, 0.28, 3.8), coping)
	var water_mesh := MeshInstance3D.new()
	var water_box := BoxMesh.new()
	water_box.size = Vector3(8.0, 0.025, 3.4)
	water_mesh.mesh = water_box
	water_mesh.material_override = water
	water_mesh.position = Vector3(0.0, y + 0.18, -63.0)
	add_child(water_mesh)
	_box(Vector3(-2.5, y + 0.17, -63.0), Vector3(0.035, 0.02, 3.0), Color(0.12, 0.65, 0.72), Vector3.ZERO, Color(0.04, 0.28, 0.34))
	_box(Vector3(2.5, y + 0.17, -63.0), Vector3(0.035, 0.02, 3.0), Color(0.12, 0.65, 0.72), Vector3.ZERO, Color(0.04, 0.28, 0.34))


# Entrance porch: a slab on two columns. The terrace floor above it is part of the same roof.
func _villa_porch(stone: Color, trim: Color, iron: Color) -> void:
	_vis(Vector3(0.0, 0.06, -53.75), Vector3(10.0, 0.02, 2.5), stone)
	_solid(Vector3(0.0, 3.45, -53.75), Vector3(10.0, 0.3, 2.5), trim)
	for x in [-4.4, 4.4]:
		_cyl_visual(Vector3(x, VILLA_H1 * 0.5, -52.8), 0.22, VILLA_H1, trim)
		_arch_visual(Vector3(x, VILLA_H1 - 0.05, -52.8), Vector3(0.52, 0.12, 0.52), trim)
		_arch_visual(Vector3(x, 0.07, -52.8), Vector3(0.5, 0.14, 0.5), trim)
	_balcony_rail(Vector3(0.0, 0.0, -52.4), Vector3(10.0, 0.0, 0.2), iron)
	_balcony_rail(Vector3(-4.9, 0.0, -53.75), Vector3(0.2, 0.0, 2.5), iron)
	_balcony_rail(Vector3(4.9, 0.0, -53.75), Vector3(0.2, 0.0, 2.5), iron)


# Solid furniture and rugs. Rooms are the living room (west), dining room (east) and two bedrooms upstairs.
func _villa_furniture(wood: Color) -> void:
	var fabric := Color(0.3, 0.3, 0.28)
	var rug := Color(0.42, 0.22, 0.18)
	var linen := Color(0.88, 0.86, 0.8)
	# Ground floor, west: living room.
	_vis(Vector3(-11.0, 0.065, -63.0), Vector3(6.0, 0.01, 4.5), rug)
	_solid(Vector3(-11.0, 0.35, -58.8), Vector3(3.0, 0.7, 1.0), fabric)
	_solid(Vector3(-11.0, 0.22, -63.5), Vector3(1.6, 0.44, 0.9), wood)
	_solid(Vector3(-8.0, 0.35, -59.6), Vector3(0.9, 0.7, 1.0), fabric)
	_solid(Vector3(-15.5, 1.1, -64.0), Vector3(0.6, 2.2, 3.0), wood)
	# Ground floor, east: dining room.
	_solid(Vector3(11.0, 0.38, -63.0), Vector3(3.2, 0.76, 1.2), wood)
	_solid(Vector3(8.6, 0.25, -63.0), Vector3(0.5, 0.5, 0.5), wood)
	_solid(Vector3(11.0, 0.25, -61.0), Vector3(0.5, 0.5, 0.5), wood)
	_solid(Vector3(11.0, 0.25, -65.0), Vector3(0.5, 0.5, 0.5), wood)
	_solid(Vector3(15.1, 0.5, -63.0), Vector3(0.6, 1.0, 3.0), wood)
	# First floor: bedrooms. Beds stand against the outer walls.
	var bed_y := VILLA_FLOOR2
	_solid(Vector3(-11.0, bed_y + 0.25, -67.6), Vector3(2.0, 0.5, 2.4), wood)
	_vis(Vector3(-11.0, bed_y + 0.56, -67.6), Vector3(1.9, 0.12, 2.3), linen)
	_solid(Vector3(-12.4, bed_y + 1.1, -58.0), Vector3(0.7, 2.2, 2.4), wood)
	_solid(Vector3(11.0, bed_y + 0.25, -67.6), Vector3(2.0, 0.5, 2.4), wood)
	_vis(Vector3(11.0, bed_y + 0.56, -67.6), Vector3(1.9, 0.12, 2.3), linen)
	_solid(Vector3(12.4, bed_y + 1.1, -58.0), Vector3(0.7, 2.2, 2.4), wood)



func _villa_glass() -> StandardMaterial3D:
	var m := _mat(Color(0.14, 0.24, 0.3, 0.38))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4
	m.roughness = 0.1
	return m


# Solid wall with real openings. along_x: the wall runs along x at z = f; otherwise along z at x = f.
# s is the outward side (+1 or -1). openings is ascending: [c0, c1, sill, head, kind, shutters],
# where kind 0 = window and 1 = door. Walls are split into pieces around each opening, so the holes are real.
func _villa_wall(along_x: bool, f: float, s: float, c0: float, c1: float, y0: float, y1: float, t: float, col: Color, trim: Color, glass: Material, openings: Array) -> void:
	var cur := c0
	for o in openings:
		var op: Array = o
		var a := float(op[0])
		var b := float(op[1])
		var sill := float(op[2])
		var head := float(op[3])
		if a > cur:
			_wall_box(along_x, f, (cur + a) * 0.5, a - cur, y0, y1, t, col)
		if sill > y0 + 0.01:
			_wall_box(along_x, f, (a + b) * 0.5, b - a, y0, sill, t, col)
		if head < y1 - 0.01:
			_wall_box(along_x, f, (a + b) * 0.5, b - a, head, y1, t, col)
		cur = b
	if c1 > cur:
		_wall_box(along_x, f, (cur + c1) * 0.5, c1 - cur, y0, y1, t, col)
	for o in openings:
		_villa_opening(along_x, f, s, o, t, trim, glass)


# One solid piece of wall between two heights, centred on the wall plane.
func _wall_box(along_x: bool, f: float, c: float, cw: float, ya: float, yb: float, t: float, col: Color) -> void:
	var yc := (ya + yb) * 0.5
	var yh := yb - ya
	if along_x:
		_solid(Vector3(c, yc, f), Vector3(cw, yh, t), col)
	else:
		_solid(Vector3(f, yc, c), Vector3(t, yh, cw), col)


# Frame, sill, glass or open door leaf, and shutters for one opening.
func _villa_opening(along_x: bool, f: float, s: float, o: Array, t: float, trim: Color, glass: Material) -> void:
	var a := float(o[0])
	var b := float(o[1])
	var sill := float(o[2])
	var head := float(o[3])
	var is_door := int(o[4]) == 1
	var shutters := bool(o[5])
	var w := b - a
	var hgt := head - sill
	var cc := (a + b) * 0.5
	var yc := (sill + head) * 0.5
	var face := t * 0.5 - 0.02

	# Head and jambs, proud of the wall face.
	_panel(along_x, f, s, cc, w + 0.24, head + 0.06, 0.12, face, 0.1, trim)
	_panel(along_x, f, s, a - 0.06, 0.12, yc, hgt, face, 0.1, trim)
	_panel(along_x, f, s, b + 0.06, 0.12, yc, hgt, face, 0.1, trim)

	if is_door:
		# Door leaf swung fully open against the room side, hinged on the a edge.
		var leaf := Color(0.34, 0.22, 0.13)
		if along_x:
			_vis(Vector3(a + 0.03, yc, f - s * w * 0.5), Vector3(0.05, hgt, w), leaf)
		else:
			_vis(Vector3(f - s * w * 0.5, yc, a + 0.03), Vector3(w, hgt, 0.05), leaf)
		return

	# Window: sill, glazing set in the middle of the wall, and optional shutters.
	_panel(along_x, f, s, cc, w + 0.3, sill - 0.04, 0.1, face, 0.2, trim)
	var pane := _panel(along_x, f, s, cc, w, yc, hgt, -0.02, 0.04, Color(0.14, 0.24, 0.3))
	pane.material_override = glass
	if shutters:
		for sd in [-1.0, 1.0]:
			var sg: float = sd
			var c_sh := a - 0.22 if sg < 0.0 else b + 0.22
			_panel(along_x, f, s, c_sh, 0.36, yc, hgt + 0.12, face, 0.05, Color(0.2, 0.3, 0.26))


# Box on a wall face. face is the distance from the wall centre to the box's inner side, depth is its thickness.
func _panel(along_x: bool, f: float, s: float, c: float, cw: float, y: float, yh: float, face: float, depth: float, col: Color) -> MeshInstance3D:
	var across := f + s * (face + depth * 0.5)
	if along_x:
		return _vis(Vector3(c, y, across), Vector3(cw, yh, depth), col)
	return _vis(Vector3(across, y, c), Vector3(depth, yh, cw), col)


# Cypress tree, visual only, with a tapered cylinder.

func _cypress(p: Vector3) -> void:
	_solid(p + Vector3(0.0, 0.4, 0.0), Vector3(1.4, 0.8, 1.4), Color(0.6, 0.58, 0.52))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.6
	cm.height = 5.4
	cm.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(Color(0.1, 0.2, 0.1))
	mi.position = p + Vector3(0.0, 3.5, 0.0)
	add_child(mi)


# ================= Bandages =================

# Applies one bandage: heals 40 HP over four ticks, capped at full health.
func _use_bandage() -> void:
	if heal_ticks > 0 or bandages <= 0 or health >= MAX_HEALTH:
		return
	bandages -= 1
	heal_ticks = BANDAGE_TICKS
	heal_tick_t = BANDAGE_TICK
	ammo_changed.emit()


func _build_bandage_pickups() -> void:
	var spots: Array = [Vector3(-20.0, 0.0, 20.0), Vector3(14.0, 0.0, -6.0)]
	if mission_no == 2:
		spots = [Vector3(-3.0, 0.0, 84.0), Vector3(-35.0, 0.0, -50.0)]
	for spot in spots:
		var sp: Vector3 = spot
		var pickup := _area(sp + Vector3(0.0, 0.5, 0.0), Vector3(2.0, 2.0, 2.0))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.14, 0.26)
		mi.mesh = bm
		mi.material_override = _mat(Color(0.92, 0.92, 0.9), Color(0.6, 0.08, 0.08))
		mi.position = Vector3(0.0, -0.35, 0.0)
		pickup.add_child(mi)
		pickup.body_entered.connect(_on_bandage_entered.bind(pickup))


func _on_bandage_entered(body: Node3D, pickup: Area3D) -> void:
	if body != player or not is_instance_valid(pickup):
		return
	if player.bandages >= BANDAGE_MAX:
		_status("Bandage pouch full  (%d / %d)" % [BANDAGE_MAX, BANDAGE_MAX], 2.0)
		return
	player.bandages += 1
	pickup.queue_free()
	_status("Bandage collected  (%d / %d)" % [player.bandages, BANDAGE_MAX], 2.0)


# ================= Villa: balcony, fall damage and decoration =================

# Balcony edge: a low solid curb (about 0.55 m) that the operator can jump over, with a thin rail on top.
func _balcony_rail(center: Vector3, size: Vector3, col: Color) -> void:
	_solid(Vector3(center.x, 3.6 + 0.275, center.z), Vector3(size.x, 0.55, size.z), col)
	_box(Vector3(center.x, 3.6 + 1.0, center.z), Vector3(size.x, 0.05, size.z), col)


# Health loss on landing. Falls within FALL_SAFE_HEIGHT are free, so the balcony drop costs nothing.
func _on_land(drop: float) -> void:
	if not alive or drop <= FALL_SAFE_HEIGHT:
		return
	take_damage(int(round((drop - FALL_SAFE_HEIGHT) * FALL_DAMAGE_PER_M)))


# ---- Small visual helpers ----

# Box with optional rotation and glow. Visual only.
func _box(pos: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, glow: Color = Color.BLACK) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, glow)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


# Sphere, used for leaves, flowers and light bulbs. Visual only.
func _blob(pos: Vector3, r: float, col: Color, glow: Color = Color.BLACK) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(col, glow)
	mi.position = pos
	add_child(mi)
	return mi


# Cone or tapered cylinder, placed by its centre. Visual only.
func _cone(pos: Vector3, r_bottom: float, r_top: float, h: float, col: Color, rot: Vector3 = Vector3.ZERO, glow: Color = Color.BLACK) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _mat(col, glow)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


# A piece placed on a wall plane. along_x: the wall runs along x at z = f, otherwise along z at x = f.
# across is the coordinate across the wall, so the piece can sit inside or outside the wall.
func _wall_piece(along_x: bool, c: float, y: float, across: float, cw: float, yh: float, depth: float, col: Color) -> void:
	if along_x:
		_box(Vector3(c, y, across), Vector3(cw, yh, depth), col)
	else:
		_box(Vector3(across, y, c), Vector3(depth, yh, cw), col)


# Framed picture or mirror on a wall. rot_y turns it to face into the room. Canvas sits on the room side (local +z).
func _painting(center: Vector3, w: float, h: float, rot_y: float, canvas: Color) -> void:
	var frame := Color(0.28, 0.2, 0.13)
	var rot := Vector3(0.0, rot_y, 0.0)
	_box(center, Vector3(w + 0.1, h + 0.1, 0.05), frame, rot)
	_box(center + Vector3(0.0, 0.0, 0.035).rotated(Vector3.UP, rot_y), Vector3(w, h, 0.03), canvas, rot)
	_box(center + Vector3(0.0, -h * 0.18, 0.055).rotated(Vector3.UP, rot_y), Vector3(w * 0.55, h * 0.3, 0.02), canvas.darkened(0.25), rot)


# Curtains beside one window opening, hung just inside the room, with a rod across the top.
# a and b are the window edges along the wall. head is the top of the window. floor_y is the floor height.
func _curtains(along_x: bool, f: float, s: float, a: float, b: float, head: float, floor_y: float, col: Color) -> void:
	var across := f - s * 0.26
	var cy_bot := floor_y + 0.1
	var cy_top := head + 0.5
	var yh := cy_top - cy_bot
	var yc := (cy_top + cy_bot) * 0.5
	for c in [a - 0.35, b + 0.35]:
		var cc: float = c
		_wall_piece(along_x, cc, yc, across, 0.5, yh, 0.08, col)
	_wall_piece(along_x, (a + b) * 0.5, cy_top + 0.03, across, b - a + 1.2, 0.04, 0.04, Color(0.2, 0.18, 0.16))


# Potted plant. pos is on the floor.
func _potted(pos: Vector3, pot_r: float, pot_h: float, leaf_r: float, leaf: Color) -> void:
	_cone(pos + Vector3(0.0, pot_h * 0.5, 0.0), pot_r, pot_r * 0.8, pot_h, Color(0.45, 0.32, 0.22))
	_blob(pos + Vector3(0.0, pot_h + leaf_r * 0.8, 0.0), leaf_r, leaf)
	_blob(pos + Vector3(leaf_r * 0.5, pot_h + leaf_r * 0.2, leaf_r * 0.3), leaf_r * 0.7, leaf.darkened(0.15))


# Flower bed: soil box with a grid of coloured blooms.
func _flowers(center: Vector3, size_x: float, size_z: float) -> void:
	_box(center + Vector3(0.0, 0.08, 0.0), Vector3(size_x, 0.16, size_z), Color(0.22, 0.15, 0.1))
	var cols := [Color(0.85, 0.35, 0.5), Color(0.95, 0.8, 0.3), Color(0.6, 0.4, 0.85), Color(0.92, 0.92, 0.9)]
	var nx := int(size_x / 0.4)
	var nz := int(size_z / 0.4)
	for i in range(nx):
		for j in range(nz):
			var px := center.x - size_x * 0.5 + 0.2 + float(i) * 0.4
			var pz := center.z - size_z * 0.5 + 0.2 + float(j) * 0.4
			var cc: Color = cols[(i + j) % cols.size()]
			_blob(Vector3(px, 0.28, pz), 0.14, cc)


# A row of blooms along x, for window boxes.
func _flowers_row(center: Vector3, length: float, col: Color) -> void:
	var n := int(length / 0.22)
	for i in range(n):
		var px := center.x - length * 0.5 + 0.11 + float(i) * 0.22
		_blob(Vector3(px, center.y, center.z), 0.1, col)
		_blob(Vector3(px + 0.05, center.y + 0.1, center.z), 0.07, Color(0.3, 0.55, 0.25))


# Round stone fountain. The basin is solid, so nobody walks into it.
func _fountain(center: Vector3) -> void:
	var stone := Color(0.7, 0.68, 0.62)
	_cyl_solid(center, 1.4, 0.5, stone)
	_cyl_visual(center + Vector3(0.0, 0.5, 0.0), 1.25, 0.04, Color(0.2, 0.45, 0.55))
	_cyl_visual(center + Vector3(0.0, 0.55, 0.0), 0.12, 0.7, stone)
	_blob(center + Vector3(0.0, 0.95, 0.0), 0.25, Color(0.4, 0.6, 0.7))


func _bench(center: Vector3) -> void:
	var wood := Color(0.4, 0.3, 0.2)
	var iron := Color(0.16, 0.17, 0.17)
	_box(center + Vector3(0.0, 0.45, 0.0), Vector3(1.8, 0.08, 0.5), wood)
	_box(center + Vector3(0.0, 0.75, -0.22), Vector3(1.8, 0.4, 0.06), wood)
	for x in [-0.7, 0.7]:
		var lx: float = x
		_box(center + Vector3(lx, 0.22, 0.0), Vector3(0.08, 0.44, 0.5), iron)


func _lantern(pos: Vector3) -> void:
	var iron := Color(0.16, 0.17, 0.17)
	_cyl_visual(pos + Vector3(0.0, 1.1, 0.0), 0.06, 2.2, iron)
	_box(pos + Vector3(0.0, 2.3, 0.0), Vector3(0.3, 0.05, 0.3), iron)
	_blob(pos + Vector3(0.0, 2.45, 0.0), 0.16, Color(0.95, 0.8, 0.5), Color(1.0, 0.7, 0.3))


func _floor_lamp(pos: Vector3) -> void:
	var black := Color(0.08, 0.08, 0.08)
	_cyl_visual(pos + Vector3(0.0, 0.02, 0.0), 0.2, 0.04, black)
	_cyl_visual(pos + Vector3(0.0, 0.8, 0.0), 0.03, 1.6, black)
	_cone(pos + Vector3(0.0, 1.75, 0.0), 0.22, 0.16, 0.3, Color(0.92, 0.88, 0.78), Vector3.ZERO, Color(0.5, 0.4, 0.2))


# ---- Decoration groups ----

func _villa_decor() -> void:
	_decor_exterior()
	_decor_ground()
	_decor_upper()
	_decor_roof()
	_stair_rail()


func _decor_exterior() -> void:
	var stone := Color(0.12, 0.14, 0.15)
	var wood := Color(0.36, 0.25, 0.15)
	# Keep the entire villa forecourt clear: no trees, hedges, rocks or garden clutter.
	for p in [Vector3(-5.6, 0.0, -49.0), Vector3(5.6, 0.0, -49.0), Vector3(-5.6, 0.0, -54.0), Vector3(5.6, 0.0, -54.0)]:
		_lantern(p)
	# Porch remains clear for security patrols.
	# Pilasters on the front facade, between the windows and at the corners.
	for x in [-15.5, -5.5, 5.5, 15.5]:
		var px: float = x
		_box(Vector3(px, 1.65, -54.92), Vector3(0.5, 3.3, 0.24), stone)
	# Dark metal window trim replaces decorative flower boxes.
	# Parasol on the south side of the roof terrace.
	_cyl_visual(Vector3(-13.0, 3.6 + 1.1, -56.0), 0.04, 2.2, wood)
	_cone(Vector3(-13.0, 5.6, -56.0), 1.3, 0.12, 0.35, Color(0.72, 0.22, 0.18))
	# Lounge set on the east side of the terrace.
	_box(Vector3(14.5, 3.6 + 0.225, -62.0), Vector3(0.9, 0.45, 2.4), Color(0.32, 0.3, 0.27))
	_box(Vector3(14.92, 4.1, -62.0), Vector3(0.25, 0.6, 2.4), Color(0.32, 0.3, 0.27))
	_box(Vector3(13.6, 3.6 + 0.2, -60.0), Vector3(0.6, 0.4, 0.9), wood)
	# Open terrace edge leaves clear sightlines around the rooftop pool.


func _decor_ground() -> void:
	var fabric := Color(0.32, 0.3, 0.27)
	var ceramic := Color(0.82, 0.8, 0.74)
	var brass := Color(0.6, 0.5, 0.25)
	var warm := Color(1.0, 0.85, 0.55)
	var curtain := Color(0.5, 0.38, 0.26)
	var black := Color(0.08, 0.08, 0.08)
	var wood := Color(0.36, 0.25, 0.15)
	var green := Color(0.16, 0.36, 0.14)

	# Curtains on every ground-floor window.
	_curtains(true, -55.0, 1.0, -13.7, -12.3, 2.4, 0.0, curtain)
	_curtains(true, -55.0, 1.0, -9.7, -8.3, 2.4, 0.0, curtain)
	_curtains(true, -55.0, 1.0, 8.3, 9.7, 2.4, 0.0, curtain)
	_curtains(true, -55.0, 1.0, 12.3, 13.7, 2.4, 0.0, curtain)
	_curtains(true, -71.0, -1.0, -12.7, -11.3, 2.4, 0.0, curtain)
	_curtains(true, -71.0, -1.0, -9.7, -8.3, 2.4, 0.0, curtain)
	_curtains(true, -71.0, -1.0, 8.3, 9.7, 2.4, 0.0, curtain)
	_curtains(true, -71.0, -1.0, 11.3, 12.7, 2.4, 0.0, curtain)
	_curtains(false, -16.0, -1.0, -68.7, -67.3, 2.4, 0.0, curtain)
	_curtains(false, -16.0, -1.0, -60.7, -59.3, 2.4, 0.0, curtain)
	_curtains(false, 16.0, 1.0, -68.7, -67.3, 2.4, 0.0, curtain)
	_curtains(false, 16.0, 1.0, -60.7, -59.3, 2.4, 0.0, curtain)

	# Living room (west): pictures, floor lamp, plant, sideboard with vases, pendant lamp, bookshelf books.
	_painting(Vector3(-15.72, 2.0, -57.6), 1.2, 1.0, PI * 0.5, Color(0.35, 0.45, 0.4))
	_floor_lamp(Vector3(-14.6, 0.0, -57.9))
	_potted(Vector3(-15.0, 0.0, -56.2), 0.32, 0.55, 0.5, green)
	_box(Vector3(-14.8, 0.4, -70.5), Vector3(2.0, 0.8, 0.5), wood)
	_cone(Vector3(-15.3, 1.0, -70.5), 0.1, 0.07, 0.4, ceramic)
	_cone(Vector3(-14.4, 0.96, -70.5), 0.08, 0.06, 0.32, Color(0.6, 0.3, 0.25))
	_box(Vector3(-11.0, 3.1, -63.5), Vector3(0.02, 0.4, 0.02), black)
	_cone(Vector3(-11.0, 2.85, -63.5), 0.4, 0.18, 0.3, Color(0.85, 0.8, 0.7), Vector3.ZERO, Color(0.45, 0.35, 0.2))
	_blob(Vector3(-11.0, 2.7, -63.5), 0.08, warm, warm)
	var book_cols := [Color(0.5, 0.15, 0.12), Color(0.2, 0.3, 0.45), Color(0.6, 0.5, 0.2), Color(0.25, 0.35, 0.2)]
	for shelf in range(4):
		var by: float = 0.35 + float(shelf) * 0.55
		for j in range(8):
			var bz: float = -65.1 + float(j) * 0.28
			_box(Vector3(-15.12, by, bz), Vector3(0.1, 0.36, 0.2), book_cols[(j + shelf) % book_cols.size()])

	# Dining room (east): chandelier, painting, sideboard display, rug, plant.
	_box(Vector3(11.0, 3.15, -63.0), Vector3(0.02, 0.5, 0.02), black)
	_cyl_visual(Vector3(11.0, 2.9, -63.0), 0.5, 0.05, brass)
	for i in range(6):
		var ang: float = float(i) * TAU / 6.0
		_blob(Vector3(11.0 + cos(ang) * 0.4, 2.85, -63.0 + sin(ang) * 0.4), 0.07, warm, warm)
	_painting(Vector3(15.72, 2.0, -65.5), 1.2, 1.0, -PI * 0.5, Color(0.6, 0.45, 0.3))
	_cone(Vector3(15.1, 1.2, -62.2), 0.12, 0.08, 0.4, ceramic)
	_cyl_visual(Vector3(15.1, 1.05, -63.6), 0.22, 0.08, ceramic)
	_blob(Vector3(15.0, 1.15, -63.6), 0.07, Color(0.95, 0.5, 0.15))
	_blob(Vector3(15.2, 1.15, -63.5), 0.07, Color(0.95, 0.5, 0.15))
	_vis(Vector3(11.0, 0.065, -63.0), Vector3(3.8, 0.01, 3.0), Color(0.5, 0.25, 0.2))
	_potted(Vector3(15.1, 0.0, -56.6), 0.35, 0.6, 0.55, green)

	# Hall: console with flowers and mirror, runner rug, pendant light, and a picture on the partition.
	_box(Vector3(0.0, 0.42, -70.45), Vector3(2.2, 0.84, 0.45), wood)
	_mirror_and_flowers()
	_vis(Vector3(0.0, 0.065, -62.0), Vector3(2.4, 0.01, 6.0), Color(0.45, 0.2, 0.18))
	_box(Vector3(0.0, 3.15, -68.0), Vector3(0.02, 0.3, 0.02), black)
	_cone(Vector3(0.0, 2.85, -68.0), 0.25, 0.12, 0.25, Color(0.85, 0.8, 0.7), Vector3.ZERO, Color(0.45, 0.35, 0.2))
	_blob(Vector3(0.0, 2.72, -68.0), 0.08, warm, warm)
	_painting(Vector3(5.82, 1.9, -58.6), 1.0, 0.8, -PI * 0.5, Color(0.42, 0.5, 0.36))


func _mirror_and_flowers() -> void:
	_painting(Vector3(0.0, 2.0, -70.72), 1.5, 1.7, 0.0, Color(0.55, 0.62, 0.66))
	_cone(Vector3(0.7, 1.0, -70.45), 0.12, 0.08, 0.3, Color(0.82, 0.8, 0.74))
	_blob(Vector3(0.7, 1.25, -70.45), 0.16, Color(0.9, 0.5, 0.6))
	_blob(Vector3(0.55, 1.35, -70.45), 0.12, Color(0.95, 0.85, 0.3))


func _decor_upper() -> void:
	var wood := Color(0.36, 0.25, 0.15)
	var fabric := Color(0.42, 0.46, 0.5)
	var curtain := Color(0.3, 0.35, 0.42)
	var black := Color(0.08, 0.08, 0.08)
	var shade := Color(0.9, 0.86, 0.75)
	var warm := Color(0.5, 0.4, 0.2)
	var green := Color(0.16, 0.36, 0.14)
	var y0 := VILLA_FLOOR2

	# Curtains on the windows that face the terrace.
	_curtains(true, -57.0, 1.0, -10.3, -8.7, 5.9, y0, curtain)
	_curtains(true, -57.0, 1.0, 8.7, 10.3, 5.9, y0, curtain)

	# West bedroom: nightstand with lamp, desk and chair, rug, picture above the bed, plant.
	_box(Vector3(-12.6, y0 + 0.3, -66.0), Vector3(0.5, 0.6, 0.5), wood)
	_cyl_visual(Vector3(-12.6, y0 + 0.75, -66.0), 0.02, 0.3, black)
	_cone(Vector3(-12.6, y0 + 1.0, -66.0), 0.14, 0.1, 0.2, shade, Vector3.ZERO, warm)
	_box(Vector3(-12.4, y0 + 0.375, -62.4), Vector3(0.7, 0.75, 1.4), wood)
	_box(Vector3(-11.0, y0 + 0.42, -62.4), Vector3(0.5, 0.08, 0.5), wood)
	_box(Vector3(-10.75, y0 + 0.75, -62.4), Vector3(0.06, 0.6, 0.5), wood)
	_vis(Vector3(-10.0, y0 + 0.05, -62.0), Vector3(3.0, 0.01, 3.0), Color(0.3, 0.3, 0.38))
	_painting(Vector3(-11.8, y0 + 1.4, -68.72), 1.2, 0.9, 0.0, Color(0.3, 0.38, 0.45))
	_potted(Vector3(-7.4, y0, -68.2), 0.3, 0.55, 0.5, green)

	# East bedroom: matching nightstand and lamp, armchair, picture, plant.
	_box(Vector3(12.3, y0 + 0.3, -66.0), Vector3(0.5, 0.6, 0.5), wood)
	_cyl_visual(Vector3(12.3, y0 + 0.75, -66.0), 0.02, 0.3, black)
	_cone(Vector3(12.3, y0 + 1.0, -66.0), 0.14, 0.1, 0.2, shade, Vector3.ZERO, warm)
	_box(Vector3(9.3, y0 + 0.25, -61.0), Vector3(1.0, 0.5, 1.0), fabric)
	_box(Vector3(9.85, y0 + 0.65, -61.0), Vector3(0.3, 0.8, 1.0), fabric)
	_painting(Vector3(11.2, y0 + 1.4, -68.72), 1.2, 0.9, 0.0, Color(0.5, 0.35, 0.3))
	_potted(Vector3(12.3, y0, -60.5), 0.3, 0.55, 0.5, green)

	# Landing: pictures on both partitions, plant, runner rug.
	_painting(Vector3(5.82, y0 + 1.3, -59.0), 1.2, 1.0, -PI * 0.5, Color(0.45, 0.4, 0.3))
	_painting(Vector3(-5.82, y0 + 1.3, -59.0), 1.2, 1.0, PI * 0.5, Color(0.3, 0.42, 0.42))
	_potted(Vector3(4.8, y0, -58.5), 0.32, 0.6, 0.55, green)
	_vis(Vector3(0.0, y0 + 0.05, -61.0), Vector3(2.4, 0.01, 6.0), Color(0.45, 0.2, 0.18))


func _decor_roof() -> void:
	var panel := Color(0.07, 0.1, 0.2)
	var metal := Color(0.5, 0.52, 0.52)
	var red := Color(1.0, 0.1, 0.1)
	var roof_y := VILLA_ROOF
	# Solar panels, tilted toward the south.
	for x in [-10.0, -7.0, -4.0]:
		for z in [-60.2, -62.2]:
			var px: float = x
			var pz: float = z
			_box(Vector3(px, roof_y + 0.35, pz), Vector3(2.0, 0.05, 1.2), panel, Vector3(-0.3, 0.0, 0.0))
	# Satellite dish and antenna mast with a warning light.
	_cyl_visual(Vector3(-11.0, roof_y + 0.7, -66.0), 0.05, 1.4, metal)
	_cone(Vector3(-11.0, roof_y + 1.5, -66.0), 0.45, 0.05, 0.25, metal, Vector3(-0.8, 0.0, 0.0))
	_cyl_visual(Vector3(11.5, roof_y + 1.5, -59.0), 0.03, 3.0, metal)
	_blob(Vector3(11.5, roof_y + 3.05, -59.0), 0.07, red, red)
	# Roof hatch housing.
	_box(Vector3(-2.0, roof_y + 0.5, -62.0), Vector3(1.2, 1.0, 1.2), metal)


# Handrail on the open side of the stair (x = -1.5). It follows the 0.18 m rise per 0.3 m tread.
func _stair_rail() -> void:
	var wood := Color(0.3, 0.2, 0.12)
	var angle := atan2(3.6, 6.0)
	_box(Vector3(-1.45, 2.7, -62.5), Vector3(0.07, 0.07, 7.0), wood, Vector3(angle, 0.0, 0.0))
	for k in [0, 9, 18]:
		var kk: int = k
		var zc: float = -59.5 - (float(kk) + 0.5) * 0.3
		var top: float = float(kk + 1) * 0.18
		_box(Vector3(-1.45, top + 0.405, zc), Vector3(0.07, 0.81, 0.07), wood)




# ================= Environment and immersion upgrade =================
# Visual-only pass: keeps the existing mission collision, navigation and controls.

func _build_environment_upgrade() -> void:
	if mission_no == 2:
		_build_forest_detail_pass()
		_build_compound_architecture_pass()
	else:
		_build_mountain_detail_pass()


func _build_forest_detail_pass() -> void:
	# Layered understory, boulders and fallen timber use MultiMesh to stay light.
	var shrub_xf: Array = []
	var shrub_col: Array = []
	var rock_xf: Array = []
	var rock_col: Array = []
	var log_xf: Array = []
	var log_col: Array = []
	for i in range(155):
		var a := randf() * TAU
		var r := randf_range(24.0, 112.0)
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		if (absf(x) < 7.0 and z > -12.0 and z < 120.0) or _inside_villa_perimeter(x, z):
			continue
		var s := randf_range(0.65, 1.35)
		shrub_xf.append(Transform3D(Basis.from_scale(Vector3(s * 1.5, s * 0.72, s * 1.2)), Vector3(x, s * 0.48, z)))
		shrub_col.append(Color(0.12, 0.19, 0.12).lerp(Color(0.30, 0.34, 0.20), randf_range(0.0, 0.45)))
	for i in range(72):
		var a2 := randf() * TAU
		var r2 := randf_range(18.0, 112.0)
		var x2: float = cos(a2) * r2
		var z2: float = sin(a2) * r2
		if _inside_villa_perimeter(x2, z2):
			continue
		var sx := randf_range(0.8, 2.8)
		var sy := randf_range(0.35, 1.2)
		rock_xf.append(Transform3D(Basis.from_scale(Vector3(sx, sy, sx * randf_range(0.7, 1.3))), Vector3(x2, sy * 0.65, z2)))
		rock_col.append(Color(0.25, 0.28, 0.27).lerp(Color(0.62, 0.65, 0.65), randf_range(0.0, 0.32)))
	for i in range(18):
		var lx := randf_range(-105.0, 105.0)
		var lz := randf_range(-105.0, 105.0)
		if _inside_villa_perimeter(lx, lz):
			continue
		var length := randf_range(2.2, 4.8)
		var log := Transform3D(Basis(Vector3.UP, randf_range(0.0, TAU)) * Basis.from_scale(Vector3(0.22, 0.22, length)), Vector3(lx, 0.22, lz))
		log_xf.append(log)
		log_col.append(Color(0.19, 0.14, 0.10))
	_far_multimesh(_sphere_mesh(), shrub_xf, shrub_col)
	_far_multimesh(_sphere_mesh(), rock_xf, rock_col)
	_far_multimesh(_environment_log_mesh(), log_xf, log_col)

	# Snow banks and drainage shoulders beside the approach road.
	for side in [-1.0, 1.0]:
		for i in range(13):
			var z3 := -8.0 + float(i) * 9.5
			var drift := _vis(Vector3(side * randf_range(5.0, 6.4), randf_range(0.18, 0.34), z3), Vector3(randf_range(1.2, 2.0), randf_range(0.35, 0.65), randf_range(5.0, 9.0)), Color(0.72, 0.79, 0.84))
			drift.material_override = _mat(Color(0.72, 0.79, 0.84))
	# Roadside reflector posts, placed outside the drivable road.
	for side2 in [-1.0, 1.0]:
		for i in range(12):
			var pz := -4.0 + float(i) * 10.0
			_vis(Vector3(side2 * 5.7, 0.48, pz), Vector3(0.10, 0.95, 0.10), Color(0.20, 0.22, 0.22))
			_vis(Vector3(side2 * 5.7, 0.78, pz), Vector3(0.14, 0.12, 0.12), Color(0.78, 0.82, 0.78))


func _inside_villa_perimeter(x: float, z: float) -> bool:
	# Full walled estate footprint: never place procedural trees, shrubs or rocks here.
	return absf(x) <= 22.0 and z >= -78.0 and z <= -46.0


func _build_compound_architecture_pass() -> void:
	# Barracks: recessed dark glazing, concrete lintels and wall-mounted lights.
	for bx in [-22.0, 22.0]:
		for wx in [-4.0, 0.0, 4.0]:
			_vis(Vector3(bx + wx, 2.15, -26.42), Vector3(1.35, 1.05, 0.055), Color(0.10, 0.15, 0.17))
			_vis(Vector3(bx + wx, 2.72, -26.36), Vector3(1.55, 0.12, 0.18), Color(0.48, 0.49, 0.45))
			_vis(Vector3(bx + wx, 1.58, -26.36), Vector3(1.55, 0.12, 0.18), Color(0.48, 0.49, 0.45))
		_vis(Vector3(bx, 3.25, -30.0), Vector3(12.4, 0.18, 7.4), Color(0.27, 0.29, 0.28))
		for lx in [-5.0, 5.0]:
			_vis(Vector3(bx + lx, 2.95, -26.1), Vector3(0.35, 0.18, 0.18), Color(0.72, 0.68, 0.52), 0.0)
	# Vehicle depot: segmented roller shutter and loading-bay safety markings.
	for i in range(12):
		_vis(Vector3(28.0 - 3.0 + float(i) * 0.55, 1.45, -69.35), Vector3(0.025, 2.7, 0.035), Color(0.18, 0.20, 0.21))
	for side3 in [-1.0, 1.0]:
		_vis(Vector3(28.0 + side3 * 6.7, 2.3, -68.8), Vector3(0.22, 4.6, 0.24), Color(0.23, 0.25, 0.25))
		_vis(Vector3(28.0 + side3 * 6.72, 0.12, -68.6), Vector3(0.7, 0.24, 1.0), Color(0.72, 0.55, 0.20))
	# Utility poles and sagging cable along the road edge.
	for side4 in [-1.0, 1.0]:
		for i in range(4):
			var pz2 := 8.0 + float(i) * 30.0
			_vis(Vector3(side4 * 10.0, 4.0, pz2), Vector3(0.22, 8.0, 0.22), Color(0.22, 0.19, 0.14))
			_vis(Vector3(side4 * 10.0, 7.8, pz2), Vector3(2.6, 0.16, 0.16), Color(0.22, 0.19, 0.14))
	# Perimeter floodlights.
	for fp in [Vector3(-39.0, 5.4, -45.0), Vector3(39.0, 5.4, -45.0), Vector3(-39.0, 5.4, -78.0), Vector3(39.0, 5.4, -78.0)]:
		_vis(fp, Vector3(0.72, 0.34, 0.30), Color(0.16, 0.18, 0.18))


func _build_mountain_detail_pass() -> void:
	var mountain_xf: Array = []
	var mountain_col: Array = []
	for i in range(55):
		var a := randf() * TAU
		var r := randf_range(55.0, 112.0)
		var h := randf_range(3.0, 12.0)
		var w := randf_range(2.0, 7.0)
		mountain_xf.append(Transform3D(Basis.from_scale(Vector3(w, h, w)), Vector3(cos(a) * r, h * 0.5, sin(a) * r)))
		mountain_col.append(Color(0.22, 0.25, 0.26).lerp(Color(0.68, 0.72, 0.74), randf_range(0.0, 0.35)))
	_far_multimesh(_cone_mesh(), mountain_xf, mountain_col)


func _build_ambient_audio() -> void:
	# Procedural low-level wind and distant forest calls; no external audio files required.
	var rate := 22050
	var seconds := 8.0
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var filtered := 0.0
	for i in range(count):
		var t := float(i) / float(rate)
		var raw := randf() * 2.0 - 1.0
		filtered += (raw - filtered) * 0.018
		var gust := 0.65 + 0.22 * sin(TAU * 0.11 * t) + 0.10 * sin(TAU * 0.27 * t)
		var sample := filtered * gust * 0.20
		sample += sin(TAU * 54.0 * t) * 0.025
		for bird_start in [1.25, 3.8, 6.15]:
			var bt: float = t - float(bird_start)
			if bt >= 0.0 and bt < 0.42:
				var sweep := 1850.0 + 700.0 * sin(PI * bt / 0.42)
				sample += sin(TAU * sweep * bt) * sin(PI * bt / 0.42) * 0.035
		var fade := minf(minf(t / 0.25, (seconds - t) / 0.25), 1.0)
		sample *= fade
		data.encode_s16(i * 2, int(clampf(sample, -0.8, 0.8) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	var ambience := AudioStreamPlayer.new()
	ambience.name = "ForestAmbience"
	ambience.stream = stream
	ambience.volume_db = -18.0
	add_child(ambience)
	ambience.play()



func _environment_log_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 1.0
	mesh.radial_segments = 7
	return mesh
