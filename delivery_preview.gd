extends Node3D
## Estimate only: never steers or changes a released body.
var world: Node3D
var marker: MeshInstance3D
var caption: Label3D
var elapsed := 0.0
@export var interval := .10
@export var horizon := 20.0
@export var step := .08
func _ready() -> void:
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .50
	ring.outer_radius = .62
	marker.mesh = ring
	add_child(marker)
	caption = Label3D.new()
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size = 32
	caption.pixel_size = .015
	caption.position.y = 1.0
	add_child(caption)
	hide()

func predict(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	var pose: Transform3D = state.pose
	var velocity: Vector3 = state.velocity
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))
	for i in ceili(horizon / step):
		var motion := velocity*step + Vector3.DOWN*gravity*step*step*.5
		var hit: Dictionary = world.Trajectory.sweep(get_world_3d().direct_space_state, world.Cargo.shape(world.Cargo.Kind.PRESENT), pose, motion, 1|16)
		if not hit.is_empty(): return hit
		pose.origin += motion
		velocity += Vector3.DOWN*gravity*step
	return {}

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed < interval: return
	elapsed = 0
	var elf = world.players.get(multiplayer.get_unique_id())
	if not elf or Game.menu_open or elf.held_kind != world.Cargo.Kind.PRESENT or world.pilot_id == elf.peer_id or world.bomber.to_local(elf.global_position).distance_to(world.HATCH_POS) > 3.2:
		hide()
		return
	var impulse := 0.0
	var charging: bool = elf.charging_since >= 0
	if charging:
		impulse = lerpf(world.min_throw_speed,world.max_throw_speed,clampf((Time.get_ticks_msec()-elf.charging_since)/1000.0/world.charge_seconds,0,1))
	var state: Dictionary = world.release_state(elf.peer_id,world.Cargo.Kind.PRESENT,elf.head.global_transform,impulse)
	var hit := predict(state)
	if hit.is_empty():
		hide()
		return
	show()
	global_position = hit.point + hit.normal*.08
	marker.quaternion = Quaternion(Vector3.UP, hit.normal.normalized())
	var target: Dictionary = world.recipients.identify(hit.get("collider"))
	var is_house: bool = not target.is_empty() and not world.recipients.houses[target.id].destroyed
	var nice: bool = is_house and world.recipients.houses[target.id].nice
	marker.material_override = world._mat(Color.LIGHT_GREEN if nice else (Color.SALMON if is_house else Color.LIGHT_GRAY),true)
	caption.text = ("Throw" if charging else "G drop") + " estimate: " + (("Nice house" if nice else "Naughty house") if is_house else "Ground / obstacle")

