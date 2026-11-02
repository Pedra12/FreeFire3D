# Unity content selection (single-source rule)

The Unity game is a clean project under `UnityProject/`. Godot scenes, scripts, imported resources and project settings are not part of this project and must never be copied into it.

## Canonical content

| Slot | One approved asset | Source archive in repository | Import destination |
|---|---|---|---|
| Player character | Olivia, rigged humanoid | `olivia-free-fire.zip` | `Assets/Game/Characters/Olivia/` |
| Match map | Clocktower | `free-fire-clocktower-3d-model-by-rs-ratul.zip` | `Assets/Game/Maps/Clocktower/` |

These are the only selected character and map for the first playable vertical slice. Do not import the other character bundles or map archives as alternate versions.

## Import gate

The source archives are stored outside `UnityProject/`. They must be inspected before extraction. Confirm:
- exact model file and texture dependencies;
- skeleton hierarchy, mesh weights and animation clips for Olivia;
- map coordinate orientation, scale, material references and collision suitability;
- asset license and attribution requirements.

After inspection, extract only the approved files into the destinations above. Do not copy the entire archive if it contains duplicate exports, previews, alternate LODs with unclear naming, or unrelated assets.

## Replacement policy

If an approved asset is replaced, remove the old asset from its canonical destination in the same change. Update the manifest and references in the same commit. Never keep two competing Olivia models or two competing Clocktower scenes in the playable project.

## Separation policy

- `UnityProject/`: Unity project only.
- `game/`: legacy Godot project, untouched.
- Root-level ZIP archives: original source archives, not runtime content.
- Never reference a `res://` Godot path from Unity.
- Never place Godot scenes, scripts, .import files or .godot cache inside `UnityProject/`.

## Current status

The selected source archives have been identified by filename and repository blob metadata. Their binary contents have not yet been extracted or inspected in this environment, so no character or map has been imported into Unity yet. Do not mark the asset-import milestone complete until the checks above pass.
