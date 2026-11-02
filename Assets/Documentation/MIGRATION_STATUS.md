# Migration status

## Completed

- Standalone Unity project on branch `unity-project`; legacy Godot project remains on `4v4-premium-prototype`.
- Unity 6.0.23f1 baseline with URP 17.0.3.
- glTFast 6.20.0 added for the selected GLB character source.
- Initial third-person motor, orbit camera and mobile input components.
- Initial 4v4 match configuration.
- Structural CI checks pass and confirm no Godot scene/script/cache files in the Unity branch.
- Both original source archives pass ZIP integrity checks.

## Source asset inspection findings

### Olivia
- Exactly one GLB model in the selected archive: `source/olivia-free_fire.glb`.
- 7 meshes, 7 materials, 10 embedded images.
- 0 skins and 0 animation clips. This source model is **not rigged**.
- It remains the one canonical Olivia. Rigging and skin-weight validation are required before playable character integration.

### Clocktower
- The outer archive contains a nested ZIP, which passes integrity checks.
- The nested ZIP contains three exports of the same map: BLEND, FBX and OBJ.
- The Unity project will use only the FBX export; the BLEND and OBJ alternatives will remain outside the Unity playable asset tree.
- The nested ZIP includes texture files. Relative texture paths must be preserved and materials checked before map integration.

## Not yet completed

- Blender scene-level inspection is running in CI; the first attempt exposed a missing NumPy dependency, which has been added to the inspection environment.
- No character or map source model has been imported into `Assets/` yet.
- Olivia still needs a humanoid rig and skin weights; no locomotion/weapon animations can be claimed as integrated.
- No Unity Editor import, C# compile, scene test, Android build or real-device test has been performed.
- The actual mobile HUD canvas, weapons, combat, bots, interiors and match scene are not implemented.

## Next safe steps

1. Complete Blender inspection of the GLB and the single chosen FBX.
2. Extract one Olivia GLB and one Clocktower FBX plus only required texture dependencies.
3. Rig the existing Olivia model without adding a second character version.
4. Create and validate the single match scene before adding combat and bots.
