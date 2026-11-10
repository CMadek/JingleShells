# Elf Bomber

Co-op first-person Godot 4 game: you and your friends are elves crewing a Christmas bomber.
One elf flies, another drops presents down chimneys. Green beams = nice kids (+10).
Red beams = naughty houses (-5).

Requires Godot 4.3 or newer.

## Run it

1. Open `project.godot` in Godot and press F5.
2. **Test multiplayer on one machine:** Debug > Customize Run Instances > Enable Multiple Instances (2),
   run, click "Host a game" in one window and "Join game" (127.0.0.1) in the other.
3. **Play with friends:** the host forwards **UDP port 7777** on their router, friends enter the host's
   public IP (or use a LAN IP / Tailscale / ZeroTier, which needs no port forwarding).

## Controls

| Key | Walking | At the helm |
|---|---|---|
| WASD | walk | W/S speed, A/D turn |
| Space | jump | climb |
| Shift | - | dive |
| E | look at a nearby supply pile to pick up one item, or stand by the console to take the helm | leave |
| Left mouse | hold to charge, release to throw along the crosshair | - |
| G | drop the held item | - |
| Esc | free the mouse | |

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

## Neighborhoods

Host with an empty **Host map seed** field for a new world, or enter a number from 1 to 2147483647 to replay one. Try **2412** for the example in the previews. Fly in any horizontal direction to reach new neighborhoods. Streets and sidewalks continue across district borders, and winter grass fills the space between homes. Returning to an address restores the same streets, houses, cars and delivery targets. Joining players start with the crew's current district.

The `[neighborhood]` section in `project.godot` controls **each district's** width and depth in junctions (2–7 each), plus its house and car limits (up to 160 and 80). Defaults are 4 × 5, up to 64 homes and 32 parked cars. Each street tile is 20 units across. The host shares its seed and dimensions, and Godot prints the starting district's counts and generation time. Nearby districts build over several frames. Distant districts unload once loose cargo has cleared them. Roads, sidewalks and garden trees are batched locally. Static cars and houses share imported meshes with simplified collision hulls.

Each lot has a coordinate ID, model, pose and world-space chimney opening imported from its Blender Delivery marker. The temporary `classify()` rule in `neighborhood.gd` gives each address a seeded 70% chance of being nice. Change that function to introduce level-design rules. Garden decoration and classification use their own random streams.

Original source models, previews and the Blender reproduction script are in `art/neighborhood/`. Game exports are in `assets/neighborhood/`. To rebuild, run Blender with `-b --factory-startup -P art/neighborhood/build.py` from the project folder, then let Godot reimport the GLBs.

## Files

- `main.gd` - lobby (host / join over ENet)
- `world.gd` - village, bomber, flight, presents, scoring, RPCs (host is authoritative)
- `player.gd` - first-person elf, rides on the bomber, syncs its own state
- `cargo.gd` - shared cargo models and collision shapes
- `game.gd` - autoload that registers input actions

## Good next steps

Snow particles, engine/jingle audio, limited present ammo with a refill, a timer and round
results, a gunner/lookout station, wind and turbulence, smoother network interpolation, Steam or
WebRTC relay so friends don't need port forwarding.
