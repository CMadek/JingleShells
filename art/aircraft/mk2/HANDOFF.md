# North Star Mk II

The aircraft uses a 9.6 m wide, 7.4 m deep cargo shell with rounded rectangular sections, thick curled-tip wings and one oversized fin. A continuous
carpeted deck replaces the old drop hole; the gunner enters through a hatch beside the stairs (x 1.9, y 0.78, z −5.48), below the sealed pilot deck. Two enclosed return tracks occupy the cabin
sides, leaving a 3.39 m aisle between their collision volumes. Rear stores and the
windowless emergency-exit room remain accessible through the aft passage.

## Editable assets

- `art/aircraft/north_star.blend`: editable complete aircraft and named mechanisms.
- `art/aircraft/build.py`: deterministic Blender entry point.
- `art/aircraft/mk2.py`: tracks, rollers, guards, console furniture, ventral turret,
  ivory accents and leather grips.
- `art/aircraft/mk2/layout.svg`: annotated cabin blockout in Godot coordinates.
- `assets/aircraft/north_star.glb`: batched Godot aircraft, with named pivot nodes.
- `art/aircraft/rounded.py`: rounded fuselage, wings, nacelles, oversized central fin and extended runner supports.
- `art/aircraft/ball_turret.py`: cabin hatch, enclosed access passage and occupied gimballed pod. The dorsal assembly is removed.
- `art/aircraft/cockpit_finish.py`: fitted side consoles, instrument panels, dashboard and pilot carpet.

Rebuild with `blender --background --python art/aircraft/build.py`, then import in
Godot. Blender +Y is forward/+Z up; Godot −Z is forward/+Y up. Scale is metres.
Named empty pivots survive export with `_rig` suffixes: BoardingDoor, EmergencyDoor, EngineFanL/R,
Rack0/1Slot1–5, Rack0/1LoadingPoint, ChuteShutter0/1, ChuteOutlet0/1,
DeliveryControls, VentralControls, GunnerHatch, VentralYaw, VentralPitch, SnowballMuzzle, GunnerEye, GunnerSeat.
Static meshes batch by material; runtime collision uses simplified boxes.

Checked screenshots are saved in `art/aircraft/mk2/previews/`, including exterior
three-quarter views, the cabin, mixed queues, retrieval, delivery targeting,
chute opening, and several turret orientations.

## Crew workflow

1. Take cargo from rear stores using E. Aim at either track's loading end and E
   appends it. Both tracks accept five mixed presents/bombs.
2. Empty-handed players aim at a queued item and E retrieves its stable ID.
   Remaining items close the gap. Reloading appends to the tail.
3. At the delivery console, E enters; 1/2 select L/R, Space releases once, Q exits.
   The physical and displayed lists share authoritative order. The selected launcher uses a large green impact circle with a center crosshair, with an explicit LEFT/RIGHT heading.
4. Click the BELLY GUN hatch to the right of the cockpit stairs with empty hands; mouse aims, click fires, Ctrl exits beside the stairs.
   Yaw wraps continuously, elevation is −80° to +20°, maximum fire rate is 5/s.
   Sphere sweeps block barrel/projectile paths into aircraft/scenery. Snowballs
   have no damage, score or recipient logic.
5. Escape opens the existing menu and suppresses station controls. Closing it
   restores the station view. Q leaves delivery; Ctrl leaves the turret.

## Authority and release transaction

`cargo_queues.gd` owns two ordered `{id, kind}` arrays on the host. Item kind is the
only stored cargo gameplay property currently used by the game. Loading/retrieval
validate range, aim, hands, capacity and busy state. Each rack reserves its head ID
for a 0.8-second cycle; all inventory requests on that rack are rejected until it
finishes. At the commit point, an external shape sweep checks the duct exit path
and spawn clearance. A blocked path or full world cargo budget restores the head.
Only after a physical body exists does the host remove the queued item once.
The other rack remains available. Queue changes and reservations replicate reliably;
client models interpolate cosmetically. Revision numbers reject stale state.

`crew_stations.gd` owns independent station occupancy, camera contexts and turret
aim. Host ownership gates release and firing. `snowball_projectiles.gd` owns the
bounded cosmetic projectile pool and first-contact sweeps. Disconnects release
ownership; level resets clear both queues, station ownership and snowballs.
Late-join snapshots include queues/IDs, reservations/timing, occupants and turret
orientation alongside existing aircraft/house state. Old snowballs are transient
and are not replayed to late joiners.

Prediction and actual discharge use the same outlet pose, aircraft point velocity
(including rotation) and downward release impulse. Shape sweeps include scenery,
roofs and aircraft; the ballistic path assumes current motion and normal gravity.
Subsequent aircraft maneuvers and moving cargo can change actual outcomes. Existing
whole-house delivery, chimney bonus, direct-hit destruction and one-time impact
resolution remain in the world/recipient systems.

## Validation and remaining manual checks

`tests/mk2_smoke.tscn` covers mixed/full racks, stable-ID retrieval, reloading,
reservation conflicts, blocked-outlet conservation, single FIFO commit, ownership,
independent operators, prediction versus rigid-body falls at multiple speeds,
altitudes and banks, yaw wrap, fire rate, self-obstruction, menu suppression,
camera restoration, disconnect cleanup and reset. It also walks both sides of the
central aisle. Run with `-- --capture-only` for inspection images under `.test-data`.
The existing airfield, delivery, menu, character and audio scenes are regression
checks. Automated ownership tests use simulated peer IDs on the offline host.

The two-process ENet harness is `tests/mk2_network.tscn`, with `-- --host` and
`-- --client` on localhost port 28764. Connection did not complete in this execution
environment; no successful live network validation is claimed.

Before release, test with two Steam accounts on the same build (protocol 15):

1. Host and join; load both racks with alternating types. Have both players load
   the fifth position together: only one succeeds and the loser keeps their item.
2. Retrieve NEXT while the console operator releases. Exactly one succeeds; count
   held + queued + discharged items before and after.
3. Operate turret and delivery together; open menus at each station and check that
   clicks/Space/Q do nothing until resuming. Leave with Q and verify walking view.
4. Join during a discharge cycle and after a destroyed house; verify queue IDs/order,
   busy state, occupants, turret angle and destroyed-house visuals.
5. Place an actual obstacle against a chute, then move clear and release. The obstructed attempt must
   preserve inventory; the clear attempt must create one matching cargo body.
6. Disconnect each operator during a cycle, rejoin, and start a new level. Stations
   must be available and no reserved inventory or projectile may survive reset.

Steam latency, loss and multi-account behavior remain unverified. Final art approval,
mix balance and aiming feel should be assessed in normal crew play; these checks
establish implementation behavior rather than release certification.

## Rounded redesign verification

The occupied pod pivots at Godot (1.75, -1.55, -7.3). Access is through the cabin hatch beside the stairs, below a continuous pilot floor. The camera crouches through the hatch and descends to a seat-relative eye point over 0.95 seconds; Ctrl returns the operator to (1.9, 0.05, -4.25). The operator follows GunnerSeat after applying turret rotation. The complete dorsal model, ladder, collision and interaction are removed.

Runner supports extend 1.1 m farther down, so parked/landing height is 2.92 m. Stationary airfield steps replace the aircraft-mounted boarding ramp. The material exporter now preserves every material on welded meshes. The build retains editable geometry, shared shell normals and named mechanism pivots.

For manual two-player testing, additionally watch the other elf enter the pod, rotate through all headings, leave with Q while banked, and disconnect during entry. Verify the observer sees the operator in the pod and the exiting player returns to the aisle. Check boarding, takeoff and landing with both stations occupied. Live Steam behavior remains unverified.

Local redesign checks passed: Mk II transactions/seat/exit/firing/prediction, airfield boarding/walking/takeoff/landing, delivery/destruction, elf crouch/presentation, and graphical menu/settings/camera regression scenes. Final Blender export/import and graphical capture completed without script errors. Final images are in `previews/`.

The final exterior refinement uses a dense longitudinal loft, continuous welded normals, smaller cargo windows, blended wing roots and nacelle saddles, and curved runners. Interior bulkheads and lamps fit inside the oval shell. `rounded-studio.png` is a Blender render of the editable model; other previews are captured in Godot. Reproduce the studio view with `blender --background art/aircraft/north_star.blend --python art/aircraft/render_preview.py`. Dynamic Godot door leaves and cargo are supplied at runtime and are absent from the Blender studio view.

## Chunky cartoon proportions

The fuselage is approximately 29.6 m long, with a 9.6 m maximum width and 7.4 m depth. The swept wings span about 29 m. Two rounded turbofans mount high on the rear shoulders, centered at Godot (±5.45, 4.35, 9.1). The nose tapers forward from the raised cockpit while the main body retains rounded rectangular sections. One rounded fin replaces the twin tail, and the wingtips curl upward. Three large oval windows per side use actual smooth apertures and fitted glazing; the aft stores remain windowless.

Cargo rack coordinates and the 2.92 m parked height are retained. The pilot and glass gun have moved to the raised nose, with longer forward runners. Cabin decking, partitions, lighting and door reveals fit the larger shell. Door cutters explicitly preserve the fitted carpet floor. Roof and engine collision proxies match the new geometry. Mixed-queue transactions, turret seating/exit/firing/prediction, boarding/walking/takeoff/landing and character checks were rerun for this version; live two-player testing remains outstanding.

## Rear turbofan reference revision

`art/aircraft/rear_engines.py` builds the two shoulder pylons, rounded pod shells, rolled intake lips, recessed twelve-blade fans and tapered exhaust centerbodies. Fans animate with throttle using EngineFanL/R pivots. All four wing propellers and their nacelles are removed. Engine collision and the positional sound source follow the new rear installation. The same flight controls and cargo/crew mechanisms remain in use.

The pointed nose uses a longer downward taper; the wraparound windshield follows exact horizontal boundaries with three internal mullions. Shell strips share those boundaries so normals remain continuous. The cabin arrangement and windowless rear room are unchanged.

Rear-engine revision validation: local Mk II cargo/crew/turret/prediction tests, airfield boarding/walking/takeoff/landing tests, and audio checks passed. Final Blender build, Godot import and graphical captures completed without script errors. Studio previews: `rearjet-studio.png` and `rearjet-side.png`; render the side view by appending `-- --side` to the Blender preview command. Live multiplayer remains unverified.

## Interior finish and middle fullness

The earlier localized middle swell and crown lift have been replaced by broad cargo shoulders and a continuous roof. Windows, structural formers and both aft partitions follow the rounded rectangular shell.

A deep spruce wool carpet replaces the timber planks, with a cranberry aisle runner, champagne woven borders and a rounded brass passage casing. Packed weave textures use planar UVs and ship inside the GLB. The deck is intersected with an inset of the actual fuselage before export; build assertions check that it remains inside the shell. Nose trim follows the taper instead of protruding through it. The guarded turret opening, cargo layout and gameplay coordinates remain intact.

Validation: Blender build and floor containment assertions passed; Godot import and interior/exterior captures completed; `MK II CHECKS: PASS` and `AIRFIELD CHECKS: PASS`. Updated previews: `previews/fuller-studio.png`, `previews/rearjet-side.png`, and `previews/carpet-cabin.png`. Live two-player testing remains for the user.

## Cabin usability and targeting revision

Wing roots are boolean-trimmed against the fuselage envelope, and obsolete coach text/trim has been removed. Inboard loading trays at (±1.6, 1.0, 5.65) can be used from the clear rear aisle; carrying cargo prioritizes loading over item retrieval. A padded courier bench, route chart, festoon lights and fixed plaques add cabin detail outside walking routes. The smooth 96×48 glass sphere replaces the faceted half-metal pod. Barrels are shortened for ground clearance.

`MIN_ALTITUDE` and `START_ALTITUDE` both derive from `Airfield.PARK.y`; the flight loop no longer sinks the plane from 2.92 m to 1.82 m. Stationary boarding stairs derive their rise from that height. Protocol 14 is required for the revised station positions.

The console camera follows the selected physical impact. `predict()` retains its shape sweep and returns the delayed-release impact used by the center crosshair; the circle is a sight aid, not an area-of-effect indicator or guided targeting. Both launchers remain host-authoritative with existing inventory and release transactions.

Validation: `MK II CHECKS: PASS` and `AIRFIELD CHECKS: PASS`. Checks include 120 parked flight steps without sinking, glass-to-runway clearance, the straight rear route, loading both racks with E from the aisle, KEY_2 + Space for the right launcher, path/impact agreement, and turret ownership/fire obstruction. The obstruction test now waits for the physics server after changing the aircraft transform. Godot captures checked: cabin, rear passage, entry, parked turret, console and targeting-flight. Blender glass detail: `previews/turret-glass-studio.png`. Live two-account testing remains outstanding.

## Raised cockpit and delayed-release targeting

The pilot deck is 1.55 m above the cargo floor, reached by nine visible steps over smooth walking collision. The helm is (0, 1.55, -7.0); the cabin hatch controls are (1.9, .78, -5.48), the glass gun center is (1.75, -1.55, -7.3), and its safe exit is (1.9, .05, -4.25). Boarding stairs belong to `Airfield/BoardingSteps`, not the aircraft. Guns, seat and muzzle remain on VentralPitch; the first-person camera is attached to VentralYaw with independent right-mouse free look.

Release timing is shared: CYCLE_TIME = 0.8 s, CLOSE_TIME = 0.35 s, RELEASE_DELAY = 0.45 s. The selected sight refreshes each physics tick. `world.advance_flight` is the shared live/forecast integrator; current pilot inputs are included in flight snapshots (protocol 14). Forecast release velocity includes translation and rotation at the future outlet. During opening, the forecast uses the remaining delay; while closing, it does not advertise another release. Cargo prediction uses physics-sized gravity steps. The dashed overlay has been removed.

Validation for this revision: RELEASE PREDICTION CHECKS, MK II CHECKS, and AIRFIELD CHECKS all passed. Eight actual delayed present drops (both racks, level/turn/climb/descent) had horizontal impact errors 0.315–0.341 m, including contact-point offset. Real opening tick, future spawn, inherited velocity and remaining-cycle forecasts agree. Walking up the pilot stairs, stationary boarding steps, turret rig ownership and independent free look are asserted. Final Blender/Godot previews were inspected. Two-process ENet loopback did not connect in this session; network synchronization and two-account Steam play remain unverified.

## Cargo silhouette refinement

The shell uses rounded rectangular sections, broad shoulders, flatter sidewalls and a continuous roof instead of the swollen center and separate nose crown. The subsequent nose taper retains those cargo proportions and level livery bands. The raised pilot deck, stairs, rear engines, runners, separate cargo stores and glass belly gun retain their gameplay locations.

The carpet, wing-root trims, bulkheads, window apertures and door reveals follow the new section profile. The stationary airfield stairs meet the wider body; a level collision bridge connects the threshold to the recessed door. Manifold booleans preserve the shell while cutting windows and doors, and build-time rays check that both doorways remain visually open.

Validation: Blender export and floor/aperture assertions, Godot import, MK II CHECKS and AIRFIELD CHECKS passed. Interior, cockpit and exterior renders were inspected. Current previews: `previews/cargo-shape-studio.png`, `previews/cargo-shape-side.png`, `previews/cargo-shape-cabin.png` and `previews/cargo-shape-cockpit.png`. Live multiplayer remains unverified.

## Tapered nose and cabin gun hatch

The nose now narrows and slopes forward from the raised cockpit, blending to oval sections while preserving the chunky cargo body. Its final tip uses a rounded cap with a smooth tangent instead of a pointed cone; see previews/rounded-tip-side.png. Runner braces follow the narrower nose. The courier bench, map and their collision are removed. Fitted cockpit cabinets, systems panels, padded coaming and a deep dashboard close the gaps around the helm; the upper floor is continuous, fitted inside the shell, with a clear central approach.

The gunner hatch is in the vertical panel to the right of the stairs, at (1.9, .78, -5.48). Click enters with empty hands; Ctrl returns to (1.9, .05, -4.25). GunnerHatch swings inward during occupancy transitions. The local camera crouches through the enclosed passage before descending into the existing glass sphere, and cancels its transition cleanly on exit. Station state remains host-authoritative. Protocol 15 prevents older station layouts from joining.

Validation includes actual click/Ctrl handling, carried-cargo refusal, menu suppression, hatch motion, safe cabin exit, blocked interaction through the cockpit floor, cargo queues, turret firing/free look, boarding, cockpit stair traversal, takeoff and landing. Current previews: `previews/tapered-nose-side.png`, `previews/tapered-nose-studio.png`, `previews/fitted-cockpit.png` and `previews/stair-gun-hatch.png`. Live two-account multiplayer testing remains outstanding.
