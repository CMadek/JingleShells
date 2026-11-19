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

The development Steam app ID is 480. Both players need the same protocol version (`jingle-bells-28`). Connecting can be canceled and times out after 20 seconds. Steam lobby requests cannot be canceled at the API level: a new attempt waits for the previous request's callback so a late result cannot start the wrong session. If Steam never returns that callback, restart the game/Steam before retrying.

For a solo flight trial, open `tests/flight_practice.tscn` and press **F6**. You start at the runway helm with a present in each launcher and the flight chart pinned next to the delivery terminal. This scene runs the lobby flight model offline.

## Frostmere contract

Read the six named orders on the flight chart. Elsie, Ada, Milo and Otto receive eight gifts between them. Pip and Nell receive four coal bombs. The numbered roofs and their lamps match the list. Navigate by the boats at Lantern Quay, the clock tower at Bell Square and the stacks at the Saw Works. Fly them in any order. Cruise hold lets a two-person crew share navigation, loading and release.

Frostmere is 4.6–5.0 km north of the parked aircraft. East Fold Farm marks departure. The western freight line crosses a frozen river at Trestle Crossing, two pine forests flank Stillwater Lake halfway out, and North Tank marks the eastern approach to town. The flight chart shows these landmarks in their generated positions. At 40 m/s, allow about two minutes each way. Snow falls at the depot and through the flight. Liftoff starts an 18-minute weather window, with driving snow and fog thickening before the runway closes. Each correct item earns 10 pending vouchers, or 15 for a chimney hit. Complete the manifest and stop on the home runway to bank the flight. An incomplete return, lost address, aircraft recall or weather closure forfeits its pay.

After the first completed stop, releasing in a bank of 22 degrees or more can jam that chute. The operator sees a bank warning. Press Interact at its loading end to free the parcel. The opposite chute stays available.

## Airfield preparation and takeoff

Each lobby starts at The Last Stop, a fixed departure lounge beside the runway. Sit on a couch cushion, pick up the flight chart, or toss mugs, cushions and practice parcels. A parcel through the practice chimney rings the bell, rolls back down the chute and records the crew’s longest basket. Talk to the quartermaster to hear a story or see what’s for sale. The clerk can hand you a wrapped present for delivery or issue the whole crew a throwing mitt or quick sling. The mitt increases throw speed and the sling shortens charge time. The crew starts with 12 shared vouchers and banks flight earnings after completing a contract and returning to the runway. Upgrades and records last for the lobby.

The host chooses a fresh seed for the first delivery district. Roads, house locations, nice/naughty assignments, Frostmere and the relay light all derive from it. Late joiners reconstruct that district before receiving its delivery history. Resetting the aircraft keeps the district. The chart on the coffee table renders from the placed world objects, including live aircraft heading, crew, loose cargo and delivered or destroyed houses. Read it with your primary action, mark it with the chart-mark action, offer it for handoff or set it down. All shortcuts appear in Settings → Controls.

Follow the exit signs and board the North Star. A wide passage through the former rear bulkhead leads to a windowless cargo room. Facing aft, bombs sit on the left pallet and wrapped presents on the right. A marked aisle runs between them.

Aim at the boarding door or its brass switch and press E from either side. The curved boarding door closes flush with the outside fuselage and swings outward, clear of the stairs. Mk II replaces the open delivery hatch with guarded dual chutes and a continuous cabin floor. Boarding stairs stay at the airfield when the aircraft departs; there is no attached ramp. Occupancy checks refuse or reverse closure when players/cargo block the opening; collision gates stay stationary during the visual sweep. Flight, cargo, and panel targets are host-controlled, including late-join snapshots. Fitted shell and floor collision lets crew walk up to the visible interior walls and remain aboard near them.

**Flight assist is on at the start of each sortie.** Use **W/S** to set the throttle and hold **Space** at 18 m/s to lift off. **A/D** commands a coordinated turn. Release steering and pitch to level the wings and nose. In level flight, half throttle gives about 22 m/s for deliveries and full throttle gives about 53 m/s.

Hold **F** in the air to ignite the afterburner in either flight mode. The engines roar and the aircraft accelerates toward 82 m/s. Release **F** to coast back to the speed set by the throttle lever. Boosting disengages cruise hold. The burner cuts when the pilot leaves the helm.

The cockpit’s **BURNER HEAT** gauge warns **EASE OFF** at 75% heat, six seconds into a continuous burst from cold. Release early and you can boost again immediately with the remaining headroom. At eight seconds the burner trips and the dash reads **COOLING**. It takes 5.2 seconds to cool to the **RESET** mark at 35%. If you are still holding boost, the dash asks you to **RELEASE**. Once it reads **READY**, press boost again. Chase view repeats the heat percentage and status.

Press **R** for aerobatics. **A/D** rolls the wings and **Space/Shift** pitches through a loop. Bank and pull to turn, or hold roll and pitch together for a barrel roll. Release both to hold the current attitude. Holding **S** while pulling tightens a turn and costs speed. **R** toggles assist back on. **V** switches between cockpit and chase view. **E** leaves the helm and restores assist.

In flight at **14 m/s or faster**, release the flight controls and press **C** to capture heading and altitude. The HUD shows the held compass course and height. Press **E** to leave the helm and load or operate a launcher. The next pilot can take the helm and inspect the course before steering, changing pitch or moving the throttle. Any of those inputs, or pressing **C** again at the helm, disengages hold. Cruise uses the current throttle and flies straight ahead. Pick a clear course and keep enough power for the pass. Below 14 m/s the hold drops out and the HUD warns of low airspeed. Add throttle to recover lift.

The runway is 1,200 m long and 52 m wide, clear of the village, with threshold markings and edge lights. Approach speed and throttle affect stopping distance.

If everyone leaves a moving aircraft for three seconds, the host cancels cruise hold, gradually reduces throttle, glides down and brakes after touchdown. A walking crew member or an occupied belly station keeps an engaged hold flying. Reboarding ends the unattended recovery. The cargo sight forecasts the same bank, pitch and cruise corrections as the host.

World.begin_level() is the host hook for future mission progression: it clears cargo and resets the aircraft and crew to preparation. It is not connected to an automatic next-mission trigger. Joining players start in the depot.

Run tests/airfield_smoke.tscn with Godot for onboard present/bomb pickup, actual walking/boarding, cargo unloading, ground/aboard movement, received flight poses, split-hatch motion, cargo passing through the opening, occupancy/snapshots, E-operated door closure while taxiing, helm interaction, takeoff with the door open, stationary boarding stairs and walkable cockpit steps, original cabin aisle clearance, supply pile pickup and cargo support, landing, braking, instruments, and level reset. With --rendering-method gl_compatibility it saves airfield, boarding, and shop previews under .test-data; --headless runs assertions only. Existing menu and elf smoke scenes cover camera/menu integration, belly-station access, crouching, and models. Two-account Steam testing remains required, particularly late joining during a hatch animation and loading/flying/landing together.

The editable North Star build now runs art/aircraft/access.py before export to cut the actual boarding doorway. Regenerate with Blender --background --python art/aircraft/build.py.

## Flight and mechanical sounds

The aircraft has throttle-responsive engine pitch and volume, speed-dependent wind, runner rumble while taxiing, a touchdown thump, door/hatch motors and endpoint latches, and distinct bomb/present impacts. Engine, wind, runner and touchdown levels use a quieter mix, with further attenuation inside the cabin. The departure bell has been removed. Sounds are positional and use the existing master volume/mute setting. Engines start quiet while parked. Cabin wind scales with airspeed and the boarding door opening, and stops when the door closes.

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

Settings save to `user://settings.cfg`. Graphics offers a 30–360 FPS target (120 by default). Check **Unlock FPS** to remove the game’s cap. Unchecking it restores your last target. VSync can still limit the frame rate to your display’s refresh rate. Windowed mode lets you choose a resolution. Borderless and fullscreen use the desktop resolution.

Apply saves changes to graphics, volume, menu animation and mouse look. Cancel discards edits, and Restore Defaults takes effect on Apply. Window changes revert unless confirmed within 15 seconds. Key bindings save immediately. The settings menu supports scrolling and keyboard navigation.

## Controls

Settings → Controls lets you select an action and press a physical key or mouse button to rebind it. Esc cancels capture. Bindings save immediately to `user://settings.cfg`, independently of Apply and Cancel. Use **Reset key bindings** to restore the defaults below. A button can serve different actions in separate crew roles. Settings tab shortcuts use the keyboard.

| Key | Walking | At the helm |
|---|---|---|
| WASD | walk | W/S throttle, A/D roll (steer in assist) |
| Space | jump | climb |
| Shift | - | dive |
| R | offer chart | toggle aerobatics / flight assist |
| F (hold) | - | afterburner |
| C | - | toggle cruise hold |
| E | look at a nearby supply pile to pick up one item, or stand by the console to take the helm | leave |
| Left mouse | hold to charge, release to throw along the crosshair | - |
| G | drop the held item | - |
| Left Ctrl (hold) | crouch; release to stand when clear | disabled |
| Esc | open/close the flight menu | open/close the flight menu |

## Cargo

The square aft storeroom has unlimited presents and bombs on separate marked pallets. Aim at stock within reach and press Interact to take one. The stockpiles support loose cargo, and the center aisle leads directly to the chute loaders.
Aim at dropped cargo and press E to pick it up again. Bombs burst on contact with the ground or a roof, and presents scatter confetti. Both disappear on impact outside the airfield; items dropped on the loading apron remain recoverable. Whole-house deliveries score; chimney hits earn a precision bonus.
Each elf can carry one item, visible to the crew. A quick click gives it a short toss. The charge
indicator reaches full strength after 1.2 seconds. Use G at the gold rim with your crosshair aimed
into the opening for a drop that keeps the plane’s motion. Loose presents slide and tumble, and
round bombs can roll when the pilot banks. Nice-house impacts score +10, nice chimney impacts +15, and naughty-house impacts -5. A coal bomb counts toward a listed naughty order and leaves its roof intact. Other houses can be destroyed.

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

Hit a nice house with a present to deliver it. Aim for the chimney for a bonus. Listed naughty roofs accept coal bombs. Other houses can be destroyed by a bomb. Manual throws and drops still inherit aircraft momentum; there is no targeting assistance or homing. Each present scores at most once, and intact houses remain eligible for repeated deliveries.


Tuning: `nice_points = 10`, `naughty_penalty = 5`, `chimney_bonus = 5` on World. Destruction leaves collidable ruins, disables the original house/roof/chimney colliders and hides the beacon. Only the struck house is destroyed; debris is cosmetic and expires after two seconds, with a 24-effect cap. Destruction persists for the current world, including aircraft recovery resets. Loading a new world restores the village.

House identity, recipient state and effects live in `house_delivery.gd`; shape sweeps live in `cargo_trajectory.gd`. The host resolves hits and sends reliable score/destruction events; late joiners receive destroyed-house snapshots without replaying explosions. Protocol `jingle-bells-7` requires matching builds.

Validation: run `godot --path . --rendering-method gl_compatibility res://tests/delivery_smoke.tscn`. It covers swept roof/wall/chimney/ground impacts, actual falling-body prediction agreement, scoring once, penalties/bonuses, bomb destruction, repeated events, ruined-house ineligibility, and silent snapshot application. It saves `user://delivery-destruction.png`. These are local automated checks, not proof of two-account Steam networking. Before release, test concurrent players, late joins after destruction, and prediction while flying/banking at several altitudes on two machines.

## North Star Mk II crew stations

Two roller tracks feed outboard chutes just forward of the rear stores. Throw a present or bomb through either yellow hopper facing the stores to load it. A miss stays loose, and a full, jammed or cycling hopper rejects the toss. You can also load held cargo at the forward trays with **Interact** (default **E**). With empty hands, aim at a queued item and use **Interact** to retrieve it. Each track holds five items. The first item is marked **1 • NEXT** beside the shutter.

Bring the flight chart from the lounge and use **Interact** on the corkboard beside the port-side terminal to pin it. The whole crew can follow the live chart. Use the primary action to read it, the chart-mark action to pencil in a waypoint, or **Interact** with empty hands to take it down.

The green CRT shows both cargo counts. Use **Interact** at the keyboard to operate it. By default **1/2** select a chute, **Space** releases one item, and **Q** leaves. The underside view shows both outlets and
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

The cabin has fitted spruce carpet with a cranberry aisle runner and brass passage trim. The aircraft uses a chunky cargo body with rounded corners and a tapered nose, thick curled-tip wings, two high-mounted rear turbofans and one broad tail fin. The raised cockpit has wraparound glazing, fitted side consoles, a deep dashboard and a continuous carpeted floor. Click the BELLY GUN hatch to the right of the stairs with empty hands to enter the glass pod beneath the cockpit; Ctrl returns beside the stairs. The hatch swings open during the entry animation and closes afterward. Mouse aims, click fires, and holding right mouse lets you look around independently of the guns. Sources: `art/aircraft/rounded.py`, `art/aircraft/cockpit_finish.py`, `art/aircraft/rear_engines.py` and `art/aircraft/ball_turret.py`; rebuild through `art/aircraft/build.py`.

The cargo console operates both launchers: **1** selects left, **2** selects right, **Space** releases, and **Q** exits. Its view follows the selected ballistic impact, showing a large green impact circle with a central crosshair. The rear aisle is continuous; load either rack from the inboard trays. The belly turret uses a smooth transparent glass sphere. Parked, taxi and landing height share the same clearance datum.

Targeting uses the actual chute release point (0.45 seconds into its 0.8-second cycle), forecasting the aircraft with the same flight integrator used by the host. A reserved release uses its remaining opening time. Pilot control changes during the delay can change the landing point. `tests/release_prediction_smoke.tscn` checks real delayed drops on both racks under level flight, steering, climb and descent.

## Christmas art polish

The North Star and flight crew share cranberry, spruce, warm cream and aged brass finishes. The cabin has a fitted wool headliner, padded wall panels, embroidered carpet, leather handrails and framed cockpit panels. The aft storeroom has fir decking, padded wall panels, caged lamps and brass cargo placards. Warm shadowed spotlights and soft fill lights complement the cold outdoor light; glass remains clear for targeting.

The elves have sculpted faces, inset eyes, curved ears, goggles, tailored coats, knitted accessories, stitched mittens and rounded boots. Their existing bones, 15 animation clips, carry socket, three coat colors and first-person hands remain supported. Export batches each body into 13 material meshes. Walking crew now receive the aircraft's translation and yaw without accumulating its pitch/roll. Turret operators retain their seat's gimbal orientation.

The menu artwork, window title, lobby name and player-facing text use **Jingle Shells**. Settings still load from the old title's data directory if the new directory has no settings yet; the internal multiplayer protocol identifier is unchanged.

See [art direction, build instructions and validation](art/CHRISTMAS_POLISH.md). Checked game previews are in `art/aircraft/mk2/previews/cozy/`.
