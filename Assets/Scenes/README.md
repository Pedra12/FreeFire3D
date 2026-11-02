# Unity scenes

The first playable scene is intended to be `Match.unity`. The idempotent Editor builder creates it only after the canonical Clocktower map, Olivia GLB, valid Olivia Humanoid Avatar and generated animation controller are all available.

The initial scene contains one Clocktower map instance, one Olivia player instance, third-person camera, mobile movement HUD and the initial 4v4 match configuration. It does not yet contain weapon logic, bots, loot, enterable building interactions or a complete match loop.

Do not add legacy Godot scenes or alternate map/player test scenes to the release path. Unity Editor scene creation and Play Mode validation are still pending.
