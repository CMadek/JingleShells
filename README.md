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
| E | take / leave the helm (stand by the console) | leave |
| Left click | drop a present (stand on the gold hatch) | - |
| Esc | free the mouse | |

## Files

- `main.gd` - lobby (host / join over ENet)
- `world.gd` - village, bomber, flight, presents, scoring, RPCs (host is authoritative)
- `player.gd` - first-person elf, rides on the bomber, syncs its own state
- `game.gd` - autoload that registers input actions

## Good next steps

Snow particles, engine/jingle audio, limited present ammo with a refill, a timer and round
results, a gunner/lookout station, wind and turbulence, smoother network interpolation, Steam or
WebRTC relay so friends don't need port forwarding.
