# Jingle Shells

Co-op first-person Godot 4 game: you and your friends are elves crewing a Christmas bomber.
One elf flies, another delivers presents by hitting houses. Green beams = nice kids (+10).
Red beams = naughty houses (-5).

Developed with Godot 4.7.2. Multiplayer requires GodotSteam and SteamMultiplayerPeer support, plus a running Steam client. The menus also work when Steam is unavailable.

## Run it

1. Open `project.godot` in Godot and press F5.
2. Choose **Play → Host Game** to start an eight-player, friends-only Steam lobby and enter the airfield depot.
3. Press Escape, then **Copy Lobby ID** to share it, or **Invite Friends** to open the Steam overlay (when available).
4. Friends choose **Play → Join Game**, paste the lobby ID, and select Join, or accept a Steam friend invite while at the menu.
5. Use separate Steam accounts on two machines for multiplayer testing. The former IP/UDP-port workflow is no longer used.

The development Steam app ID is 480. Both players need the same protocol version (`jingle-bells-16`). Connecting can be canceled and times out after 20 seconds. Steam lobby requests cannot be canceled at the API level: a new attempt waits for the previous request's callback so a late result cannot start the wrong session. If Steam never returns that callback, restart the game/Steam before retrying.

## Airfield preparation and takeoff

Each session starts inside The Naughty List supply depot. The evil quartermaster is decorative; purchasing is a future feature and the current supplies are free. Follow the flight-line signs and board the North Star. A wide passage through the former rear bulkhead leads to a separate windowless cargo room. Six bombs sit on a low rack on the left and six presents on a low rack on the right, leaving the centre clear; collect them with E and drop them with G. The shop remains a placeholder.

Aim at the boarding door or its brass switch and press E from either side. The curved boarding door closes flush with the outside fuselage and swings outward, clear of the stairs. Mk II replaces the open delivery hatch with guarded dual chutes and a continuous cabin floor. Boarding stairs stay at the airfield when the aircraft departs; there is no attached ramp. Occupancy checks refuse or reverse closure when players/cargo block the opening; collision gates stay stationary during the visual sweep. Flight, cargo, and panel targets are host-controlled, including late-join snapshots. Fitted shell and floor collision lets crew walk up to the visible interior walls and remain aboard near them.

At the helm: W raises throttle, S lowers it and applies ground brakes, A/D steers, Space raises the nose, and Shift lowers it. Reach 18 m/s and hold Space to take off. The boarding door stays under crew control: open, close, or reverse it with E at any speed, including in flight. Obstructions display a prompt. Touchdown levels the sleigh on its runners; hold S to stop. The original airborne flight model, animated instruments, V camera toggle, and chase orbit are retained. Flat-ground landing is arcade-style, without a crash/damage simulation. Low flight no longer causes the altitude clamp; out-of-world travel resets preparation.

The runway is 1,200 m long and 52 m wide, clear of the village, with threshold markings and edge lights. Local checks measured about 43 m to lift off starting with an open door (including automatic closure) and 67 m to stop from the 45 m/s maximum. Approach speed and throttle affect stopping distance.

If everyone leaves a moving aircraft for more than three seconds, the host gradually reduces throttle, levels into a descending glide, and brakes after touchdown. This clears a fallen pilot's helm claim and prevents an abandoned powered climb from continuing indefinitely. Any crew member still in the cabin or an occupied belly station keeps normal cruise active; reboarding cancels recovery. This uses the existing arcade stall/sink model and does not add a rigid-body aircraft simulation. Boarding stairs still stay at the depot, so an off-runway boarding aid would be a separate feature. `tests/flight_recovery_smoke.tscn` covers recovery, grace, crew/station occupancy, braking, and reset; delayed cargo prediction still shares the same flight step.

World.begin_level() is the host hook for future mission progression: it clears cargo and resets the aircraft and crew to preparation. It is not connected to an automatic next-mission trigger. Joining players start in the depot. Protocol 4 requires matching builds.

Run tests/airfield_smoke.tscn with Godot for onboard present/bomb pickup, actual walking/boarding, cargo unloading, ground/aboard movement, received flight poses, split-hatch motion, cargo passing through the opening, occupancy/snapshots, E-operated door closure while taxiing, helm interaction, takeoff with the door open, stationary boarding stairs and walkable cockpit steps, original cabin aisle clearance, individual shelf pickup and cargo support, landing, braking, instruments, and level reset. With --rendering-method gl_compatibility it saves airfield, boarding, and shop previews under .test-data; --headless runs assertions only. Existing menu and elf smoke scenes cover camera/menu integration, belly-station access, crouching, and models. Two-account Steam testing remains required, particularly late joining during a hatch animation and loading/flying/landing together.

The editable North Star build now runs art/aircraft/access.py before export to cut the actual boarding doorway. Regenerate with Blender --background --python art/aircraft/build.py.

## Flight and mechanical sounds

The aircraft has throttle-responsive engine pitch and volume, speed-dependent wind, runner rumble while taxiing, a touchdown thump, door/hatch motors and endpoint latches, and distinct bomb/present impacts. Engine, wind, runner and touchdown levels use a quieter mix, with further attenuation inside the cabin. The departure bell has been removed. Sounds are positional and use the existing master volume/mute setting. Engines start quiet while parked. Wind plays only while the boarding door or rear emergency exit is open, scales with airspeed and the opening, and stops when both exterior doors are closed.

Continuous sounds follow replicated flight and access state on each peer. Cargo sounds use the existing host-authorized impact RPC. One-shots use a bounded pool; resetting a level stops old effects, and leaving the world frees every audio source. Old landing/latch sounds are not replayed on initial join.

All effects are original synthesis. Rebuild with node art/audio/build_flight.cjs. tests/audio_smoke.tscn covers throttle response, mix ceilings, airborne/ground transitions, single touchdown events, door/hatch endpoints, cargo impacts, voice limits, volume routing, and reset/disconnect cleanup. Two-account Steam audio validation remains outstanding.

## Menus and preferences

The front-end plays **Snowbound Dispatch**, an original 51-second Christmas waltz
with celesta, soft chords, plucked bass and sleigh bells. It loops across menu pages,
fades out when a game starts, and fades back in after leaving or disconnecting.
In-game pause/options screens do not start the music. Master volume controls it.
The composition and recording use no third-party samples or downloaded music;
see assets/audio/PROVENANCE.md. Rebuild with `node art/audio/build_menu.cjs`.
`tests/menu_music_smoke.tscn` checks playback, looping, transitions, mute routing,
rapid reconnect/disconnect and cleanup.

The main menu contains Play, Options, How to Play, Credits, and Exit, with decorative snowfall and a transparent title logo. Escape opens a compact flight menu with Resume, session sharing, options, help, and confirmed leave/exit actions. The online world keeps running; local movement, look, cargo, and flight input are suppressed while the menu is open.

Options save to `user://settings.cfg`: window mode/resolution, VSync, frame limit, field of view, master volume, mouse sensitivity, and invert look. Apply commits changes; Cancel discards edits; Restore Defaults selects defaults that still need Apply. Display changes require confirmation within 15 seconds or revert. There are no separate music/SFX controls because the project does not currently define those buses. UI uses responsive containers and scrolling rather than a separate UI-scale setting.

## Controls

| Key | Walking | At the helm |
|---|---|---|
| WASD | walk | W/S speed, A/D turn |
| Space | jump | climb |
| Shift | - | dive |
| E | look at a nearby supply pile to pick up one item, or stand by the console to take the helm | leave |
| Left mouse | hold to charge, release to throw along the crosshair | - |
| G | drop the held item | - |
| Left Ctrl (hold) | crouch; release to stand when clear | disabled |
| Esc | open/close the flight menu | open/close the flight menu |

## Cargo

The two labeled shelving units aboard the aircraft have unlimited supplies. Aim at an individual present or bomb on any shelf until the pickup prompt appears. Shelf boards and dividers have player and cargo collision.
Aim at dropped cargo and press E to pick it up again. Bombs burst on contact with the ground or a roof, and presents scatter confetti. Both disappear on impact outside the airfield; items dropped on the loading apron remain recoverable. Whole-house deliveries score; chimney hits earn a precision bonus.
Each elf can carry one item, visible to the crew. A quick click gives it a short toss. The charge
indicator reaches full strength after 1.2 seconds. Use G at the gold rim with your crosshair aimed
into the opening for a drop that keeps the plane’s motion. Loose presents slide and tumble, and
round bombs can roll when the pilot banks. Nice-house impacts score +10, nice chimney impacts +15, and naughty-house impacts -5. Bombs destroy the house directly hit without changing the score.

The host controls inventory, loose cargo, and deliveries. Joining players receive the current items.
A departing elf takes their held item with them. Loose items outside the cabin and airfield expire after 90 seconds or when far
from the plane. Releasing item 49 retires the oldest loose item. Tune these limits, pickup range,
charge duration, throw speeds, and friction at the top of `world.gd`.

## Files

- `main.gd` - Steam session lifecycle and world startup
- `world.gd` - village, bomber, flight, presents, scoring, RPCs (host is authoritative)
- `player.gd` - first-person elf, rides on the bomber, syncs its own state
- `cargo.gd` - shared cargo models and collision shapes
- `game.gd` - Steam initialization, preferences, and input actions
- `menu.gd` - Control-based menu screens and confirmation dialogs
- `ui_theme.gd` - shared colors, buttons, and focus styling
- `menu_snow.gd` - lightweight decorative snowfall

## Good next steps

In-world snow, engine/jingle audio, limited present ammo with a refill, a timer and round
results, a gunner/lookout station, wind and turbulence, and smoother network interpolation.

## Validation

A Godot smoke scene at `tests/menu_smoke.tscn` checks menu navigation, persisted preferences, display reversion, offline world startup/cleanup, and local input suppression/resume. Run it with `godot --path . --rendering-method gl_compatibility res://tests/menu_smoke.tscn`. Use a disposable user-data directory for tests; the test writes settings and saves a screenshot under `user://main-menu.png`.

Manual multiplayer acceptance checks (require two Steam accounts; not yet verified end to end):

1. Host on A; join from B by lobby ID. Repeat using a Steam invite. Check both elves, flight, scoring, and cargo replication.
2. Join after A has picked up and dropped cargo and changed the score. Confirm B receives those states.
3. While piloting or charging a throw, open Escape. Check input stops, menu clicks cannot throw, and the other client continues normally. Resume and verify controls recover.
4. Leave B, rejoin, then end the host session. B should return to the main menu with an explanation. Host and join again without restarting.
5. Try an invalid ID, unavailable/full/incompatible lobby, cancel during connection, and simulate a failed connection. Wait for late Steam callbacks and retry.
6. Open Options in game. Test Apply, Cancel, Restore Defaults, display confirmation, and timeout reversion. Relaunch and confirm saved preferences load.

The generated title artwork has a simpler flat print treatment. The original artwork is retained at `assets/ui/jingle-bells-logo-original.png`; generation prompts sit beside the assets.

## Elf characters

Blender sources, asset scripts, pose details, and validation instructions are in [art/elf/README.md](art/elf/README.md). Hold Left Ctrl to crouch. The new player protocol requires matching builds on all peers.

Numeric options use sliders with editable number fields on the right. Either input updates the other; Apply saves, while Cancel discards the draft.

## House deliveries and destruction

Hit a nice house with a present to deliver it. Aim for the chimney for a bonus. Bombs destroy the houses they hit. Manual throws and drops still inherit aircraft momentum; there is no targeting assistance or homing. Each present scores at most once, and intact houses remain eligible for repeated deliveries.

Near the hatch (3.2 m), holding a present shows a landing estimate: G drop by default, or charged throw while holding the mouse button. The estimate uses the same initial cargo release state and sweeps the present shape through gravity in 0.08-second steps, up to 20 seconds ahead, refreshed every 0.10 seconds. It distinguishes nice houses, naughty houses, and ground/obstacles. It does not model subsequent bouncing, moving-aircraft collisions after release, or all rotational contact differences. A blocked release or trajectory beyond the prediction horizon produces no marker.

Tuning: `nice_points = 10`, `naughty_penalty = 5`, `chimney_bonus = 5` on World. Preview interval, step, and horizon are exposed on `delivery_preview.gd`. Destruction leaves collidable ruins, disables the original house/roof/chimney colliders and hides the beacon. Only the struck house is destroyed; debris is cosmetic and expires after two seconds, with a 24-effect cap. Destruction persists for the current world, including aircraft recovery resets. Loading a new world restores the village.

House identity, recipient state and effects live in `house_delivery.gd`; shape sweeps live in `cargo_trajectory.gd`. The host resolves hits and sends reliable score/destruction events; late joiners receive destroyed-house snapshots without replaying explosions. Protocol `jingle-bells-7` requires matching builds.

Validation: run `godot --path . --rendering-method gl_compatibility res://tests/delivery_smoke.tscn`. It covers swept roof/wall/chimney/ground impacts, actual falling-body prediction agreement, scoring once, penalties/bonuses, bomb destruction, repeated events, ruined-house ineligibility, and silent snapshot application. It saves `user://delivery-destruction.png`. These are local automated checks, not proof of two-account Steam networking. Before release, test concurrent players, late joins after destruction, and prediction while flying/banking at several altitudes on two machines.

The aft room has a side emergency exit behind the bomb rack. Press E at its handle to tear the door off and fling it outside. It stays open for the level, restores on level reset, and late joiners receive its current state without replaying debris. The front boarding door and delivery hatch retain their normal controls.

## North Star Mk II crew stations

The cabin now has two five-item return tracks feeding independent enclosed underside
chutes. Load held cargo with E at a track's loading end; with empty hands, aim at any
queued item and E retrieves that item. Reloading moves it to the tail. Numbers 1–5,
NEXT, and arrows show FIFO order. A busy or full rack never consumes held cargo.

At the delivery console (port side, forward of the racks), E enters; 1/2 select a
chute, Space releases one item, Q leaves. The underside view shows both outlets and
labeled circular first-impact estimates: L/single ring, R/double ring. Empty chutes
hide their estimate. Blocked outlets preserve the queue. Cargo remains ballistic.

Click the BELLY GUN hatch to the right of the cockpit stairs to enter with empty hands. Mouse aims,
left click fires a cosmetic snowball, Ctrl returns to the cabin. The 360° turret has a bounded vertical
arc, host-validated ownership and fire rate, and aircraft obstruction checks. A
second player can independently operate delivery. Escape opens the normal menu;
station input is suppressed until resuming.

Blender model: art/aircraft/north_star.blend. Rebuild with
`blender --background --python art/aircraft/build.py`; Mk II fittings live in
art/aircraft/mk2.py and export to assets/aircraft/north_star.glb.
See [the annotated layout](art/aircraft/mk2/layout.svg) and
[the implementation handoff](art/aircraft/mk2/HANDOFF.md) for authority rules,
asset pivots, checks and exact two-account test steps.

## Rounded North Star

The cabin has fitted spruce carpet with a cranberry aisle runner and brass passage trim. The aircraft uses a chunky cargo body with rounded corners and a tapered nose, thick curled-tip wings, two high-mounted rear turbofans and one broad tail fin. The raised cockpit has wraparound glazing, fitted side consoles, a deep dashboard and a continuous carpeted floor. Click the BELLY GUN hatch to the right of the stairs with empty hands to enter the glass pod beneath the cockpit; Ctrl returns beside the stairs. The hatch swings open during the entry animation and closes afterward. Mouse aims, click fires, and holding right mouse lets you look around independently of the guns. The old upstairs well, courier bench and map are removed. Sources: `art/aircraft/rounded.py`, `art/aircraft/cockpit_finish.py`, `art/aircraft/rear_engines.py` and `art/aircraft/ball_turret.py`; rebuild through `art/aircraft/build.py`.

The cargo console operates both launchers: **1** selects left, **2** selects right, **Space** releases, and **Q** exits. Its view follows the selected ballistic impact, showing a large green impact circle with a central crosshair. The rear aisle is continuous; load either rack from the inboard trays. The belly turret uses a smooth transparent glass sphere. Parked, taxi and landing height share the same clearance datum.

Targeting uses the actual chute release point (0.45 seconds into its 0.8-second cycle), forecasting the aircraft with the same flight integrator used by the host. A reserved release uses its remaining opening time. Pilot control changes during the delay can change the landing point. `tests/release_prediction_smoke.tscn` checks real delayed drops on both racks under level flight, steering, climb and descent.

## Christmas art polish

The North Star and flight crew share cranberry, spruce, warm cream and aged brass finishes. The cabin has a fitted wool headliner, padded wall panels, embroidered carpet, leather handrails and framed cockpit panels. Cargo shelves are authored in Blender at their existing pickup coordinates. Warm shadowed spotlights and soft fill lights complement the cold outdoor light; glass remains clear for targeting.

The elves have sculpted faces, inset eyes, curved ears, goggles, tailored coats, knitted accessories, stitched mittens and rounded boots. Their existing bones, 15 animation clips, carry socket, three coat colors and first-person hands remain supported. Export batches each body into 13 material meshes. Walking crew now receive the aircraft's translation and yaw without accumulating its pitch/roll. Turret operators retain their seat's gimbal orientation.

The menu artwork, window title, lobby name and player-facing text use **Jingle Shells**. Settings still load from the old title's data directory if the new directory has no settings yet; the internal multiplayer protocol identifier is unchanged.

See [art direction, build instructions and validation](art/CHRISTMAS_POLISH.md). Checked game previews are in `art/aircraft/mk2/previews/cozy/`.
