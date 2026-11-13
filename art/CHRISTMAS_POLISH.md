# Jingle Shells Christmas polish

The art direction is a handmade Christmas cargo aircraft: cranberry satin paint,
spruce cabinetry, cream wool lining, aged brass, oxblood leather and clear glacier
glass. The existing tapered rounded nose, raised cockpit, stairs, rear engines,
runners, cargo rooms and forward belly turret retain their layout and rig markers.

## Sources and rebuilding

- `material_library.py`: deterministic 128px periodic normal and packed roughness/
  metallic maps, shared palette and UV helpers. Maps are packed in Blender and GLB.
- `aircraft/build.py`: rebuilds `aircraft/north_star.blend`,
  `../assets/aircraft/north_star.glb` and the fitted collision resources.
- `aircraft/polish.py`: headliner, padded wall linings, sewn borders, panel hardware,
  handgrips, stores shelves, gunner fittings and material finishing.
- `elf/character.py`, `elf/refine.py`, `elf/meshcraft.py`, `elf/surface_paint.py` and `elf/build.py`: rounded
  crew and first-person arm sources, joined surfaces, curved ears, blended garment
  weights, animations, material batching and both generated GLBs.
- `../assets/aircraft/cabin_finish.gd`: three downward shadowed spots, five small
  fills and gameplay-friendly glass/cloth tuning.
- `../assets/materials/snow.gdshader`: stable world-space snow grain with distance
  filtering; no animated glitter or additional texture fetches.

From the repository root, use Blender 5.2:

```text
blender --background --factory-startup --python art/aircraft/build.py
blender --background --factory-startup --python art/elf/build.py
godot --headless --editor --path . --import
godot --path . res://tests/polish_previews.tscn
```

Godot extracts embedded GLB images beside the assets. Keep those PNGs and their
import files with the GLBs. Normal and ORM maps use distinct extension-free names.
The body export is 11 material meshes, with the existing gameplay bones plus an
anchored scarf bone, the carry attachment, three peer coat colors and 15 clips.
Costume linework is baked into UV atlases; the blush is a surface color attribute.
Editable Blender geometry remains unbatched.

The corrected transparent title was made with the built-in image-generation tool;
the exact prompts are in `../assets/ui/jingle-shells-logo.prompt.txt`. The existing
menu snow, navigation, transitions and original music are preserved. Settings fall
back to the old title's sibling user-data folder when necessary.

## Verified behavior

Local Godot 4.7.2 checks passed:

- `orientation_smoke`: 360 attitude changes, bank/climb/descent, heading wraps,
  world-up for local and simulated remote roots and visual models, position
  carrying, remote interpolation, crouch bones, occupied gimbal alignment,
  hatch exit, helm, delivery station and reset.
- `airfield_smoke`: wall walking, fitted floor/door collision, boarding switches,
  doorway closure guard, stair traversal, takeoff, braking and landing.
- `mk2_smoke`: both cargo racks, stable-ID retrieval, FIFO release, station
  ownership, actual hatch click/Ctrl handling, gun aim/fire and independent look.
- `release_prediction_smoke`: eight real delayed drops on both outlets; impact
  error stayed approximately 0.315–0.341m for the tested flight inputs.
- `elf_smoke`: imported animation set, crouch clearance, independent capsules,
  body/hands and remote inventory/charge presentation.
- `delivery_smoke`: collision/scoring, swept hits, duplicate protection and replay.
- `menu_smoke`, `audio_smoke`, `menu_music_smoke`: settings/navigation/input,
  door-dependent wind and original menu music lifecycle.
- A disposable legacy settings fixture verified volume, FOV and sensitivity load
  from the old branding folder and save under the new title.

The shader/materials were checked in the project's Forward+ renderer. Final game
previews are in `aircraft/mk2/previews/cozy/`: exterior, cockpit, cabin, stairs,
stores, turret, crew, crew-carry and hands. The menu preview is `menu.png` there.
Elf studio turnarounds remain in `elf/blender_front.png`, `blender_side.png` and
`blender_back.png`.

## Performance and multiplayer limits

The export batches materials, uses small shared maps and Godot-generated LODs.
Cabin shadow lights use three spot views instead of eighteen omni shadow views;
FXAA and low-quality SSAO replace the initially tested MSAA configuration. There
is no moving reflection probe or screen-space refraction. Reflection probes were
removed after profiling: [Godot recaptures even UPDATE_ONCE probes when they move](https://docs.godotengine.org/en/stable/classes/class_reflectionprobe.html#enum-reflectionprobe-updatemode).
Soft fill lights approximate cabin bounce without that cost.

The earlier eight-elf cabin baseline, before the rounded-model follow-up, at 1280×720 on the available
RTX 4070 SUPER averaged 59.97 FPS with normal game settings, following 100 warm-up
frames and 180 measurement frames without screenshot encoding. The probe version
had measured roughly 26 FPS. This is a local desktop stress sample, not a
multiplayer performance guarantee; profile actual two-player play on target hardware.

The rounded-model follow-up was tested with the GPU already fully utilized before
Godot launched. Those frame rates varied even with every crew model hidden and
cannot establish a reliable performance comparison. Repeat the sample without
competing GPU work before using it as a release benchmark.

The two-process ENet loopback attempt did not connect, so live replication has not
been certified here. With two Steam accounts and matching builds, check:

1. A walking/crouching/carrying passenger remains upright on both screens through
   banks, climbs, descents and landing, including after leaving the turret.
2. One player flies while the other boards the turret or operates either launcher;
   the seated gunner follows the gimbal and exits beside the stairs.
3. Cargo load/retrieve/release and both exterior door states agree across clients.
4. Late joining, disconnecting from a station, level reset and color/pose updates
   preserve the correct visible crew and inventory.

Headless/editor runs may report the pre-existing missing GitPlugin and Steam DLL
safe-save issues; importer scratch changes are excluded from this work. The earlier
probe version also reported renderer texture-RID warnings; the final preview run
exited cleanly. No runtime script or missing-material errors appeared in the final
gameplay checks.
