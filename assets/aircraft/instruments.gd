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

func update_readings(flight: Node3D, vertical_speed: float) -> void:
	power.rotation.z = lerpf(SWEEP, -SWEEP, flight.throttle)
	pitch.rotation.z = -SWEEP * flight.pitch / flight.MAX_PITCH
	speed.rotation.z = lerpf(SWEEP, -SWEEP, flight.speed / flight.MAX_SPEED)
	compass.rotation.z = flight.heading
	altitude.rotation.z = lerpf(SWEEP, -SWEEP, flight.bomber.position.y / flight.MAX_ALTITUDE)
	bank.rotation.z = -SWEEP * flight.roll / flight.MAX_ROLL
	climb.rotation.z = -SWEEP * clampf(vertical_speed / 30.0, -1.0, 1.0)
	wheel.rotation.z = -deg_to_rad(60.0) * flight.roll / flight.MAX_ROLL
