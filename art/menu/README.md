# Off-duty North Star menu

The main menu is live Godot footage: the shipped North Star aircraft and a
menu-only version of the existing elf crew, lit on a snowy airfield. The right
elf sips hot cocoa from a cream-and-cranberry mug; the seated elf has a red-and-white
candy cane and swings their boots in an alternating four-second rhythm. The
third periodically checks a brass wristwatch. Both wooden crates are plain,
with no lettering. The existing logo retains its
transparency and aspect ratio. Menu buttons use evergreen serif text, red hover
and focus text, and a gold keyboard-focus outline. Host and Join now appear
directly on the main page; their existing Steam availability checks remain.

## Assets and motion

- `build_crew.py` opens the existing `art/elf/flight_elf.blend`, adds refreshments
  and the wristwatch, and bakes three 24-second menu actions using a two-link arm
  solve with a deliberate elbow plane. Resting arms hang close to the body;
  the cup hand follows its handle through the sip instead of flaring sideways.
  The right elf takes two sips and shifts their shoulders, the
  seated elf kicks their boots and looks around, and the third elf raises their
  watch and looks down at it twice per cycle.
- `tailoring.py` fits a continuous hair surface to the actual head sculpt, lowers
  the complete hat/goggle assembly, and replaces its disc-shaped brim with a
  fitted wool binding. The scarf has a smaller collar and a bowed tail that
  clears the coat throughout the acting clips. The menu coats disable glossy
  specular highlights, preventing the nearby lantern from washing sleeve folds
  into cream patches. Gameplay materials retain their existing default.
- `refreshments.py` builds the hooked striped candy cane and an open ceramic mug
  with a handle, cocoa and marshmallows. The `Mug` bone controls its lift and tilt;
  the right mitten follows the handle and the near rim meets the lips during
  each sip. Only the cup emits steam, from its `MugSteam` attachment. Cigarette
  geometry, embers, ash and mouth-smoke attachments are removed.
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
  boundary. Snow and cocoa steam emit continuously and fade out, with no scene reset.

## Rendering and lifecycle

`menu_backdrop.gd` uses an isolated SubViewport/World3D with input disabled. It
does not instantiate World, Player, networking, physics bodies or audio. It
survives front-end page changes and is stopped and freed before gameplay starts.
Returning creates one new stage. Pause menus never create it.

The render target preserves aspect ratio and is capped at 1600×900; the UI stays
at native resolution. The tree line uses two MultiMeshes; there are 398 particles
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
blender --background --python-exit-code 1 --python art/menu/check_refreshments.py
blender --background --python-exit-code 1 --python art/menu/check_tailoring.py
godot --headless --editor --path . --quit
godot --path . res://tests/menu_background_smoke.tscn
godot --path . res://tests/menu_smoke.tscn
godot --path . res://tests/menu_music_smoke.tscn
```

The background test checks exported loop poses and angular continuity, visible
boot/watch/mug movement, refreshment visibility and the steam attachment,
expression weights and corrective blinks, plain crates,
actual mouse/keyboard navigation, render-world isolation, animation preference
changes, and repeated offline gameplay/return cycles. It does not contact Steam.
The Blender refreshment check samples 145 poses to verify the hand stays on the
handle, the mug reaches the mouth during each sip, and the lift is clearly visible.
The tailoring check samples 435 poses across all three clips for hanging scarf
clearance and elbow placement.

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
