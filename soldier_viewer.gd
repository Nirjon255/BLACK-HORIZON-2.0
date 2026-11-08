# BLACK HORIZON - single-file prototype (Godot 4.7, Compatibility renderer)
# Attach this script to ONE Node3D in a new scene and press F5.
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
	_setup_input()
	_build_environment()
	_build_hud()
	_build_level()
	_build_objectives()
	_spawn_player(START_POS)
	_spawn_enemies()
	level.navigation_mesh = _make_nav_mesh()
	level.bake_navigation_mesh(false)
	_set_captured(false)
	_build_menu()
	_show_menu()


func _briefing_text() -> String:
	var t := "MISSION 01 - DEAD SIGNAL\n\n"
	t += "Location: Mountain border region\n\n"
	t += "Locate a missing reconnaissance team and recover its encrypted field drive. "
	t += "Scout patrol routes, bypass observation posts and extract before the search teams close in.\n\n"
	t += "CONTROLS\n"
	t += "WASD move  |  Mouse look  |  Shift sprint  |  Ctrl crouch  |  Space jump\n"
	t += "Right mouse aim  |  Left mouse fire  |  R reload  |  E pick up  |  Esc pause\n\n"
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
	env.background_color = Color(0.45, 0.5, 0.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.56)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.6, 0.66)
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
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
	lbl_health = _hud_label("", Vector2(24, screen.y - 60.0), 20)
	lbl_ammo = _hud_label("", Vector2(screen.x - 260.0, screen.y - 60.0), 20)


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

	# Bunker with a south doorway. The field drive is inside.
	var concrete := Color(0.42, 0.41, 0.38)
	_solid(Vector3(-12, 1.5, -20), Vector3(8, 3, 0.5), concrete)
	_solid(Vector3(-16, 1.5, -16), Vector3(0.5, 3, 8), concrete)
	_solid(Vector3(-8, 1.5, -16), Vector3(0.5, 3, 8), concrete)
	_solid(Vector3(-14.5, 1.5, -12), Vector3(3, 3, 0.5), concrete)
	_solid(Vector3(-9.5, 1.5, -12), Vector3(3, 3, 0.5), concrete)
	_solid(DRIVE_POS + Vector3(0, 0.4, 0), Vector3(1, 0.8, 1), Color(0.3, 0.25, 0.18))

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
	drive_area = _area(DRIVE_POS + Vector3(0, 1.0, 0), Vector3(3, 3, 3))
	drive_mesh = MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.5, 0.12, 0.35)
	drive_mesh.mesh = dm
	drive_mesh.material_override = _mat(Color(0.05, 0.05, 0.06), Color(0.9, 0.1, 0.1))
	drive_mesh.position = DRIVE_POS + Vector3(0, 0.86, 0)
	add_child(drive_mesh)

	cp_area = _area(CHECKPOINT_POS + Vector3(0, 1.5, 0), Vector3(4, 3, 2))

	ext_area = _area(EXTRACT_POS + Vector3(0, 1.5, 0), Vector3(8, 3, 8))
	var pad := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(8, 0.05, 8)
	pad.mesh = pm
	pad.material_override = _mat(Color(0.12, 0.18, 0.12), Color(0.1, 0.5, 0.2))
	pad.position = EXTRACT_POS + Vector3(0, 0.03, 0)
	add_child(pad)

	drive_area.body_entered.connect(_on_drive_entered)
	drive_area.body_exited.connect(_on_drive_exited)
	cp_area.body_entered.connect(_on_checkpoint_entered)
	ext_area.body_entered.connect(_on_extraction_entered)


func _spawn_player(pos: Vector3) -> void:
	var p = CharacterBody3D.new()
	p.set_script(get_script())
	p.role = "player"
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
	for spec in specs:
		var en = CharacterBody3D.new()
		en.set_script(get_script())
		en.role = "enemy"
		en.position = spec["pos"]
		en.pts = spec["patrol"]
		add_child(en)
		enemies.append(en)


func _make_nav_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.45
	nm.agent_height = 1.8
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	return nm


func _solid(pos: Vector3, size: Vector3, color: Color) -> void:
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
	if event.is_action_pressed("ui_cancel"):
		_set_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("interact") and near_drive and not has_drive:
		_pick_drive()
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
		_status("Press E to recover the encrypted field drive.", 3.0)


func _on_drive_exited(body: Node3D) -> void:
	if body == player:
		near_drive = false


func _pick_drive() -> void:
	has_drive = true
	near_drive = false
	_apply_drive_state()
	_status("Encrypted field drive recovered. Head for extraction.", 4.0)


func _apply_drive_state() -> void:
	drive_mesh.visible = not has_drive
	drive_area.monitoring = not has_drive


func _on_checkpoint_entered(body: Node3D) -> void:
	if body != player or phase != PHASE_ACTIVE:
		return
	cp_pos = CHECKPOINT_RESPAWN
	cp_has_drive = has_drive
	_status("Checkpoint saved.", 2.5)


func _on_extraction_entered(body: Node3D) -> void:
	if body != player or phase != PHASE_ACTIVE:
		return
	if not has_drive:
		_status("Recover the encrypted drive before extracting.", 3.0)
		return
	phase = PHASE_COMPLETE
	_set_captured(false)
	_show_panel("MISSION COMPLETE\n\nExtraction successful. The field drive is secured.\n\nPress ENTER to replay.")


func _on_player_died() -> void:
	phase = PHASE_FAILED
	_set_captured(false)
	_show_panel("MISSION FAILED\n\nPress ENTER to restart from the last checkpoint.")


func _restart_from_checkpoint() -> void:
	has_drive = cp_has_drive
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
	if status_t > 0.0:
		status_t -= delta
		if status_t <= 0.0:
			lbl_status.text = ""
	hit_t = maxf(hit_t - delta, 0.0)
	lbl_cross.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if hit_t > 0.0 else Color(0.9, 0.92, 0.88))
	var lines := PackedStringArray([
		"OBJECTIVES",
		("[X]  " if has_drive else "[ ]  ") + "Recover the encrypted field drive",
		"[ ]  Reach the extraction point",
	])
	lbl_obj.text = "\n".join(lines)
	if player:
		lbl_health.text = "HEALTH  %d" % player.health
		if player.reloading:
			lbl_ammo.text = "RELOADING"
		else:
			lbl_ammo.text = "%d / %d" % [player.mag, player.reserve]


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
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	weapon = Node3D.new()
	weapon.position = HIP_WEAPON_POS
	cam.add_child(weapon)
	_build_rifle()
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
	weapon.position = pos


func _player_physics(delta: float) -> void:
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
	var t := clampf((ACCEL if moving else DECEL) * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, wish.x, t)
	velocity.z = lerpf(velocity.z, wish.z, t)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif active and Input.is_action_just_pressed("jump") and not crouching:
		velocity.y = JUMP_VEL

	move_and_slide()

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

	if not active:
		return
	if Input.is_action_just_pressed("reload"):
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
	fire_cd = FIRE_INTERVAL
	_play_player("shot")
	recoil = minf(recoil + RECOIL_STEP * (0.6 if aiming else 1.0), RECOIL_MAX)
	rotate_y(randf_range(-0.006, 0.006) * (0.4 if aiming else 1.0))
	sway += Vector2(randf_range(-0.012, 0.012), 0.025)
	ammo_changed.emit()
	get_tree().call_group("enemies", "hear_noise", cam.global_position, 45.0)
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
	if hit.has_method("take_damage"):
		var killed: bool = hit.take_damage(BULLET_DAMAGE, result["position"])
		hit_confirmed.emit(killed)


func _start_reload() -> void:
	if reloading or mag >= MAG_SIZE or reserve <= 0:
		return
	reloading = true
	reload_t = RELOAD_TIME
	_play_player("reload")


func _finish_reload() -> void:
	var take := mini(MAG_SIZE - mag, reserve)
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

	var x := screen.x * 0.5 - 160.0
	var y := screen.y * 0.45
	_menu_button("START MISSION", Vector2(x, y), _open_briefing)
	sens_btn = _menu_button("MOUSE SENSITIVITY: " + SENS_NAMES[sens_index], Vector2(x, y + 62.0), _cycle_sens)
	_menu_button("QUIT", Vector2(x, y + 124.0), _quit_game)

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
	var s := target / box.size.y
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
func _import_anims() -> void:
	var lib: AnimationLibrary = anim.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library("", lib)
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
				lib.add_animation(key, clip)
				break
		inst.queue_free()


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
