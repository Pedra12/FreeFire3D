# Migration status

## Completed

- Standalone Unity project on branch `unity-project`; legacy Godot project remains on `4v4-premium-prototype`.
- Unity 6.0.23f1 baseline with URP 17.0.3 and glTFast 6.20.0.
- Initial third-person motor, orbit camera and mobile input components.
- Mobile crouch changes CharacterController height and checks overhead clearance before standing.
- Initial 4v4 match configuration.
- Structural CI checks pass and confirm no Godot scene/script/cache files in the Unity branch.
- Both original source archives pass ZIP integrity checks.
- Blender 5.0.1 inspection completed for the selected Olivia GLB and Clocktower FBX.
- **Canonical Clocktower GLB generated and committed** at `Assets/Game/Maps/Clocktower/Clocktower.glb`.
- Clocktower GLB contains 38 meshes, 38 materials and 10 embedded texture images. All 11 material texture references were resolved to 10 unique source images; missing references: 0.
- Clocktower source map is centered horizontally and its base top is aligned to ground level.

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
- The nested ZIP contains three exports of the same map: BLEND, FBX and OBJ. Only the FBX was used; the alternatives are excluded.
- Blender imported the FBX as 38 mesh objects, 46,176 vertices and 26,307 faces.
- Approximate source bounds are 87.249 m × 113.65 m × 27.566 m.
- The FBX had stale absolute Windows texture paths. All 11 texture references were successfully matched to 10 unique source images.
- The playable Unity asset is one self-contained GLB; the source FBX is not imported as a second map model.
- Source credit: RS RATUL, Sketchfab, CC BY. Retain attribution.

## Not yet completed

- Olivia humanoid rigging and FBX round-trip validation are still being tested. No playable Olivia model has been imported into Unity.
- No Unity Editor import, C# compile, scene test, Android build or real-device test has been performed.
- The actual mobile HUD canvas, weapon system, combat, bots, interiors and match scene are not implemented.
- Clocktower collision, enterable interiors, navigation and Android performance still need gameplay validation.

## Next safe steps

1. Complete and validate a single rigged Olivia FBX with correct scale, skin weights and a working deformation test.
2. Create one match scene with one Clocktower instance and one Olivia player.
3. Add collision and test camera, movement and entry into buildings.
4. Add the mobile HUD, weapons, bots and 4v4 combat only after the vertical slice is stable.
