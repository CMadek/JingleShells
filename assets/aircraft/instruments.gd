extends Node3D

# The engraved end marks lie 126 degrees either side of twelve o'clock.
const SWEEP := PI * .7
@onready var power: Node3D = $PowerNeedle_rig
@onready var pitch: Node3D = $PitchNeedle_rig
@onready var speed: Node3D = $SpeedNeedle_rig
@onready var compass: Node3D = $HeadingNeedle_rig
@onready var altitude: Node3D = $AltitudeNeedle_rig
@onready var bank: Node3D = $BankNeedle_rig
@onready var climb: Node3D = $ClimbNeedle_rig
@onready var wheel: Node3D = $HelmWheel_rig
@onready var heat_pointer: Node3D = $BurnerHeatNeedle_rig
@onready var cold_x := heat_pointer.position.x
@onready var hot_x: float = $BurnerHeatLimit_rig.position.x
var annunciator := Label3D.new()
var plumes: Array[MeshInstance3D] = []
var flame_length := 0.0

func _ready() -> void:
	annunciator.font_size = 48
	annunciator.pixel_size = .00096
	annunciator.outline_size = 0
	annunciator.double_sided = false
	$BurnerStatus_rig.add_child(annunciator)
	var jet := CylinderMesh.new()
	jet.height = 1
	jet.bottom_radius = .49
	jet.top_radius = .06
	jet.rings = 0
	jet.cap_top = false
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://assets/aircraft/afterburner.gdshader")
	jet.material = glow
	for nozzle in [$AfterburnerL_rig, $AfterburnerR_rig]:
		var plume := MeshInstance3D.new()
		plume.mesh = jet
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plume.rotation.x = PI/2
		plume.hide()
		nozzle.add_child(plume)
		plumes.append(plume)

func update_readings(flight: Node3D, vertical_speed: float) -> void:
	heat_pointer.position.x = lerpf(cold_x, hot_x, flight.burner_heat)
	var status: String = flight.burner_status()
	if annunciator.text != status:
		annunciator.text = status
		match status:
			"COOLING": annunciator.modulate = Color("ff9070")
			"EASE OFF", "RELEASE": annunciator.modulate = Color("ffcc68")
			_: annunciator.modulate = Color("b6f1b2")
	power.rotation.z = lerpf(SWEEP, -SWEEP, flight.throttle)
	pitch.rotation.z = -SWEEP * clampf(flight.pitch / deg_to_rad(35), -1, 1)
	speed.rotation.z = lerpf(SWEEP, -SWEEP, flight.speed / flight.MAX_SPEED)
	compass.rotation.z = flight.heading
	altitude.rotation.z = lerpf(SWEEP, -SWEEP, flight.bomber.position.y / flight.MAX_ALTITUDE)
	bank.rotation.z = -SWEEP * clampf(flight.roll / deg_to_rad(45), -1, 1)
	climb.rotation.z = -SWEEP * clampf(vertical_speed / 30.0, -1.0, 1.0)
	wheel.rotation.z = -deg_to_rad(60.0) * (flight.in_steer if flight.aerobatics else clampf(flight.roll / flight.MAX_ROLL, -1, 1))

func _process(delta: float) -> void:
	var flight = get_parent().get_parent()
	var burning: bool = flight.afterburner_active()
	flame_length = move_toward(flame_length, 3.8 if burning else 0.0, delta * (20.0 if burning else 13.0))
	for plume in plumes:
		plume.visible = flame_length > .01
		if plume.visible:
			plume.scale.y = flame_length
			plume.position.z = flame_length * .5
	for child in get_children():
		if child.name.begins_with("EngineFan"):
			child.rotate_z(delta * (48.0 if burning else 2.0 + flight.throttle*35))
