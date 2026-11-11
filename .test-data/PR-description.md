# Add Jingle Bells menus, snowy title screen, and Steam session controls

Base: master
Head: feature/menuing
Commit: a6ddc74

Replaces the minimal lobby screen with a complete Jingle Bells main menu and in-game flight menu. Players can host or join Steam sessions, change persisted settings, read controls, and leave or exit with confirmation.

- Add a transparent flat-style title logo, animated snowfall, shared midnight-blue/cream/gold styling, and credits for Synk Studios & Memceco.
- Wire Steam lobby-ID joining and friend invites, connection errors/timeouts, cancellation cleanup, session sharing, and host-disconnect recovery.
- Add persisted display, audio, FOV, and mouse preferences with timed display confirmation and rollback.
- Keep online simulation running while menus suppress local gameplay input. Make decorative HUD controls ignore mouse events so the crosshair no longer blocks camera look.
- Update Steam setup documentation and add a Godot menu smoke test.

Validation: Godot 4.7.2 smoke test passed for menu navigation, settings persistence/reversion, offline world startup/cleanup, mouse-look delivery through the HUD, menu input suppression, and resume. git diff --check passed.

Remaining verification: live Steam hosting/joining requires two accounts and has not been tested end to end. Manual acceptance steps are in README.md. A canceled Steam lobby request must finish its callback before another attempt; if Steam never responds, restarting is required.
