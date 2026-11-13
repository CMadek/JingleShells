# Off-duty North Star menu

The main menu is live Godot footage: the shipped North Star aircraft and a
menu-only version of the existing elf crew, lit on a snowy airfield. Two elves
smoke; the third periodically checks a brass wristwatch. The seated elf swings
their boots in an alternating four-second rhythm. Both wooden crates are plain,
with no lettering. The existing logo retains its
transparency and aspect ratio. Menu buttons use evergreen serif text, red hover
and focus text, and a gold keyboard-focus outline. Host and Join now appear
directly on the main page; their existing Steam availability checks remain.

## Assets and motion

- `build_crew.py` opens the existing `art/elf/flight_elf.blend`, adds the cigarette
  and smoke attachment and wristwatch, and bakes three 24-second menu actions
  using Blender IK. The smoker takes two drags and shifts their shoulders, the
  seated elf kicks their boots and looks around, and the third elf raises their
  watch and looks down at it twice per cycle.
- `off_duty_crew.blend` is the editable source, with the three actions retained
  in muted NLA tracks. Select an action on `ElfRig` to inspect it.
- The exported `assets/menu/off_duty_crew.glb` batches meshes by material. Gameplay
  models, rigs and animations are unchanged.
- `faces.py` authors three facial blend shapes: Veteran (green coat, stern
  narrowed eyes), Smirk (red coat, asymmetrical mouth/brows), and Skeptic (blue
  coat, raised brow). Select one expression at weight 1 on a facial mesh in
  Blender to inspect it. Each has its own corrective `...Blink` shape, used
  together with that expression; all other expressions remain at zero. Godot
  applies different blink timings per actor, tied to their animation clocks.
- The seated actor sits on the front of a .46m crate. Hip rotation separates the
  boots, and the hands have clearance above the thighs. `check_seated.py` checks
  deformed leg vertices against that crate across 145 samples of the full loop.
- `menu_stage.gd` stages the real assets, lights, props and bounded particles.
  Crew animation phases are staggered; their poses and motion match at the loop
  boundary. Snow and smoke emit continuously and fade out, with no scene reset.

## Rendering and lifecycle

`menu_backdrop.gd` uses an isolated SubViewport/World3D with input disabled. It
does not instantiate World, Player, networking, physics bodies or audio. It
survives front-end page changes and is stopped and freed before gameplay starts.
Returning creates one new stage. Pause menus never create it.

The render target preserves aspect ratio and is capped at 1600×900; the UI stays
at native resolution. The tree line uses two MultiMeshes; there are 428 particles
total and two shadow-casting lights. The existing menu music remains independent.

Settings → Animated main menu background switches to the shipped in-engine
`assets/menu/airfield_still.jpg`. This preference is saved with existing settings.
`-- --static-menu` is also available as a launch override. The camera/layout has
been visually checked at 1280×720, 1024×768, 1920×1080 and 1920×820.

## Rebuilding and checking

From the repository root, using the installed Blender and Godot executables:

```text
blender --background --python-exit-code 1 --python art/menu/build_crew.py
blender --background --python-exit-code 1 --python art/menu/check_seated.py
godot --headless --editor --path . --quit
godot --path . res://tests/menu_background_smoke.tscn
godot --path . res://tests/menu_smoke.tscn
godot --path . res://tests/menu_music_smoke.tscn
```

The background test checks exported loop poses and angular continuity, visible
boot/watch movement, expression weights and corrective blinks, plain crates,
actual mouse/keyboard navigation, render-world isolation, animation preference
changes, and repeated offline gameplay/return cycles. It does not contact Steam.

Capture the main menu or regenerate the still with:

```text
godot --path . res://tests/menu_background_preview.tscn -- --still
godot --path . res://tests/menu_background_preview.tscn -- --4-3
godot --path . res://tests/menu_background_preview.tscn -- --1080
godot --path . res://tests/menu_background_preview.tscn -- --ultrawide
godot --path . res://tests/menu_background_preview.tscn -- --seated --poses
godot --path . --fixed-fps 30 --write-movie .test-data/menu-background.avi res://tests/menu_background_preview.tscn -- --movie
```

Preview captures go into the ignored `.test-data` directory. The movie includes
two seconds of lead-in followed by a full acting cycle. The game itself uses the
live scene, not a GIF or video. The `art/menu` folder is excluded from Godot import.
