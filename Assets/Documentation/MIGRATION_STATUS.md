# Migration status

## Completed

- Standalone Unity project on branch `unity-project`; legacy Godot project remains on `4v4-premium-prototype`.
- Unity 6.0.23f1 baseline with URP 17.0.3 and glTFast 6.20.0.
- Initial third-person motor, orbit camera and mobile input components.
- Mobile crouch now changes CharacterController height and checks overhead clearance before standing.
- Initial 4v4 match configuration.
- Structural CI checks pass and confirm no Godot scene/script/cache files in the Unity branch.
- Both original source archives pass ZIP integrity checks.
- Blender 5.0.1 inspection completed for the selected Olivia GLB and Clocktower FBX.
- All 11 Clocktower texture references were relinked successfully during Blender inspection; no missing textures remained.

## Source asset inspection findings

### Olivia
- Exactly one GLB model in the selected archive: `source/olivia-free_fire.glb`.
- 7 meshes, 12,079 vertices and 17,719 faces.
- World bounds are approximately 2.792 m wide, 0.883 m deep and 5.078 m tall. The source needs a deliberate scale correction before gameplay.
- 0 armatures, 0 skins and 0 animation clips. This source model is **not rigged**.
- It remains the one canonical Olivia. A humanoid armature, skin weights and deformation tests are required before connecting movement and weapon animations.
- Source appears to match Sketchfab “Olivia free fire” by Xman, listed CC BY; confirm the match and preserve attribution before distribution.

### Clocktower
- The outer archive contains a nested ZIP, which passes integrity checks.
- The nested ZIP contains three exports of the same map: BLEND, FBX and OBJ. Only the FBX is selected as the source; the alternatives are excluded.
- Blender imported the FBX as 38 mesh objects, 46,176 vertices and 26,307 faces.
- Approximate world bounds are 87.249 m × 113.65 m × 27.566 m.
- The FBX had stale absolute Windows texture paths. All 11 texture references were successfully matched to files in the nested archive during inspection.
- The map is being converted into one self-contained GLB with textures embedded. The source FBX will not be added as a second playable map model.
- Source credit: RS RATUL, Sketchfab, CC BY. Retain attribution.

## Not yet completed

- The canonical Clocktower GLB has not yet been generated and committed.
- Olivia has not yet been rigged, scaled or imported into Unity.
- No Unity Editor import, C# compile, scene test, Android build or real-device test has been performed.
- The actual mobile HUD canvas, weapon system, combat, bots, interiors and match scene are not implemented.

## Next safe steps

1. Convert the one approved Clocktower FBX to a single GLB, preserving all 11 linked textures, centering the map and aligning its base to the ground plane.
2. Rig the existing Olivia model without importing a second character version.
3. Create one match scene with one Clocktower instance and one Olivia player.
4. Validate camera, movement, collision and Android performance before expanding gameplay.
