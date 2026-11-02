# Unity content selection (single-source rule)

This branch is a standalone Unity project. Godot scenes, scripts, imported resources and project settings are not part of this branch's working tree and must never be copied into it.

## Canonical content

| Slot | One approved asset | Source archive in repository | Import destination |
|---|---|---|---|
| Player character | Olivia, one rigged humanoid | `SourceArchives/olivia-free-fire.zip` | `Assets/Game/Characters/Olivia/` |
| Match map | Clocktower, one environment | `SourceArchives/free-fire-clocktower-3d-model-by-rs-ratul.zip` | `Assets/Game/Maps/Clocktower/` |
| Humanoid animation source | Quaternius Universal Animation Library Standard, in-place FBX | `SourceArchives/quaternius-universal-animation-library-standard.zip` | `Assets/Game/Animations/Quaternius/` |

Olivia is the only playable character and Clocktower is the only selected map for the first vertical slice. The Quaternius FBX is an animation-donor rig only: its mesh is disabled during Unity import and must never be instantiated as a second player character.

## Import gate

Only the selected source exports are extracted from the archives:
- Olivia: one GLB, with generated skeleton and skin weights.
- Clocktower: one FBX source converted to one self-contained GLB.
- Quaternius: one Unity FBX with root motion disabled, imported as a Humanoid animation source.

Keep the archives in `SourceArchives/`, outside runtime content. Do not import alternate exports, root-motion variants, duplicate map versions or extra playable characters.

## Replacement policy

If an approved asset is replaced, remove the old asset from its canonical destination in the same change. Update the manifest and references in the same commit. Never keep two competing Olivia models or two competing Clocktower scenes in the playable project.

## Separation policy

- This branch's working tree: Unity project only, plus the three approved source archives and CI workflows.
- Legacy Godot project: preserved on branch `4v4-premium-prototype`.
- `SourceArchives/`: original source archives, not runtime content.
- Never reference a `res://` Godot path from Unity.
- Never place Godot scenes, scripts, `.import` files or `.godot` cache in this branch.

## Current status

Olivia and Clocktower source assets have been inspected and converted into their single canonical runtime files. The Quaternius Standard archive passed checksum and ZIP-integrity checks; its in-place FBX is selected as the only animation source. Unity Editor import and runtime validation remain pending.
