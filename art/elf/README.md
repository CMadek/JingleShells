# Flight crew elf assets

Original Blender-authored stylized Christmas flight crew, with pointed ears, folded cap and goggles, scarf, jacket, mittens, and boots. Character presentation is independent of gameplay authority.

## Build

Run Blender 5.2 in background mode with `--python art/elf/build.py`. This writes the editable `flight_elf.blend` and `first_person_arms.blend` sources and both GLB assets under `assets/elf`. Run `--python art/elf/render.py` to regenerate front, side, and back studio renders. Godot imports the GLBs; Blender sources are excluded from Godot's importer with `.gdignore`.

The body has a shared armature with 12 bones including CargoSocket, rigid garment weights, and 15 clips: idle, walk, jump, land, crouch idle/walk, crouched carry idle/walk, pickup, carry idle/walk, charge, throw, drop, and helm. Pose transitions blend through AnimationPlayer. The first-person sleeve/mitten mesh uses a separate lightweight procedural reach/charge/sway presentation. Three coat colors are chosen deterministically from peer ID and applied to body and sleeves. No per-frame bone replication is used.

## Controls and behavior

Hold Left Ctrl to crouch. Crouch uses a unique capsule per player, slows movement to 2.5 m/s, and interpolates camera height. Releasing Ctrl stands only when the standing capsule fits. Clearance uses the player's world orientation on the aircraft. Opening a menu releases crouch intent but still respects ceilings. Crouch is disabled at the helm; the existing flight simulation continues through menus.

Host-approved inventory results control held models. Charge/cancel/release poses are sent by the host. Remote held objects use a bone attachment; local objects and hands share one view attachment. Hands and cargo are hidden at the helm. Character bodies are hidden only for their own first-person camera. The crouch and grounded flags accompany existing player motion; late joiners receive reliable posture and current inventory/charge snapshots.

Protocol is `jingle-bells-4`: peers must use matching builds because player poses now use world coordinates and aircraft access state is replicated.

## Checks and limits

Run `godot --path . --rendering-method gl_compatibility res://tests/elf_smoke.tscn` with disposable user data. It tests crouch, overhead obstruction, releasing crouch through menus, independent capsules, and remote inventory/charge presentation, and writes in-game screenshots here. `tests/menu_smoke.tscn` checks menu/settings and mouse input integration.

The North Star sleigh, dorsal ladder, cockpit/chase cameras, and airfield preparation loop are integrated. Local smoke checks cover ladder travel, body/hand visibility across camera switches, crouch clearance, and boarding. Two-account Steam play remains required before release. Generated poses and mitten contact are stylized; there is no finger IK or wall avoidance for the first-person mesh.
