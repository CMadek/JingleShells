# Jingle Bells

Co-op first-person Godot 4 game: you and your friends are elves crewing a Christmas bomber.
One elf flies, another drops presents down chimneys. Green beams = nice kids (+10).
Red beams = naughty houses (-5).

Developed with Godot 4.7.2. Multiplayer requires GodotSteam and SteamMultiplayerPeer support, plus a running Steam client. The menus also work when Steam is unavailable.

## Run it

1. Open `project.godot` in Godot and press F5.
2. Choose **Play → Host Game** to start an eight-player, friends-only Steam lobby and enter the plane.
3. Press Escape, then **Copy Lobby ID** to share it, or **Invite Friends** to open the Steam overlay (when available).
4. Friends choose **Play → Join Game**, paste the lobby ID, and select Join, or accept a Steam friend invite while at the menu.
5. Use separate Steam accounts on two machines for multiplayer testing. The former IP/UDP-port workflow is no longer used.

The development Steam app ID is 480. Both players need the same protocol version (`jingle-bells-1`). Connecting can be canceled and times out after 20 seconds. Steam lobby requests cannot be canceled at the API level: a new attempt waits for the previous request's callback so a late result cannot start the wrong session. If Steam never returns that callback, restart the game/Steam before retrying.

## Menus and preferences

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
| Esc | open/close the flight menu | open/close the flight menu |

## Cargo

The two labeled piles have unlimited supplies. Look down at a pile until the pickup prompt appears.
Aim at dropped cargo and press E to pick it up again. Bombs burst on contact with the ground or a roof, and presents scatter confetti. Both disappear on impact. Successful chimney deliveries still score normally.
Each elf can carry one item, visible to the crew. A quick click gives it a short toss. The charge
indicator reaches full strength after 1.2 seconds. Use G at the gold rim with your crosshair aimed
into the opening for a drop that keeps the plane’s motion. Loose presents slide and tumble, and
round bombs can roll when the pilot banks. Only presents score when they cross a chimney opening.

The host controls inventory, loose cargo, and deliveries. Joining players receive the current items.
A departing elf takes their held item with them. Loose items expire after 90 seconds or when far
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
