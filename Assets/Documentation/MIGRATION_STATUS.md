# Migration status

## Completed

- Standalone Unity project on branch `unity-project`; legacy Godot project remains on `4v4-premium-prototype`.
- Unity 6.0.23f1 baseline with URP 17.0.3 and glTFast 6.20.0.
- Initial third-person motor, orbit camera and mobile input components.
- Mobile crouch changes CharacterController height and checks overhead clearance before standing.
- Initial 4v4 match configuration.
- Landscape runtime settings, static map collision authoring and an idempotent initial Match scene builder are prepared.
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
- The one approved output is now `Olivia.glb`, with a generated humanoid skeleton and skin weights. The Blender pipeline passed its pose-deformation test, skinned-GLB export and round-trip re-import validation; the committed model contains 7 skinned mesh nodes, 1 skin, 22 bones and 10 embedded textures.
- The final GLB is 2,687,664 bytes, has a SHA-256 recorded in `OliviaRigReport.json`, and its corrected height is 1.78 m. An extra 42-vertex `Icosphere` helper appears on Blender re-import but is not present in the exported GLB mesh-node list and is excluded from the seven validated character meshes.
- `OliviaAvatarAssetBuilder.cs` is prepared to build a Unity Humanoid Avatar from the imported skeleton and save `OliviaAvatar.asset`. This Unity Editor step has not yet been executed or validated.
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

- Unity Editor validation of the Olivia Humanoid Avatar.
- Automatic creation and inspection of `Assets/Scenes/Match.unity`.
- No Unity Editor C# compile, scene play test, Android build or real-device test has been performed.
- The actual mobile HUD layout is prepared by the scene builder, but firing, aiming and weapon switching are not connected to a weapon system yet.
- Weapon models, combat, bots, enterable interiors, bot navigation and match scoring are not implemented.
- Clocktower collision, enterable interiors, navigation and Android performance still need gameplay validation.

## Next safe steps

1. Complete one skinned Olivia GLB and validate its deformation and round-trip.
2. Let Unity build and validate the single Humanoid Avatar.
3. Create one Match scene with one Clocktower instance and one Olivia player.
4. Test movement, camera, map collision and building access.
5. Add weapons, bots and 4v4 combat only after the vertical slice is stable.
