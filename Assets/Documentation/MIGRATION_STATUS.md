# Migration status

## Completed

- Standalone Unity project on branch `unity-project`; legacy Godot project remains on `4v4-premium-prototype`.
- Unity 6.0.23f1 baseline with URP 17.0.3, Input System 1.11.2, UGUI 2.0.0 and glTFast 6.20.0.
- Initial third-person motor, orbit camera and mobile input components.
- Mobile crouch changes CharacterController height and checks overhead clearance before standing.
- Initial 4v4 match configuration.
- Landscape runtime settings, static map collision authoring and an idempotent initial Match scene builder are prepared.
- Structural CI checks pass and confirm no Godot scene/script/cache files in the Unity branch.
- The three selected source archives pass integrity/checksum validation.
- **Canonical Clocktower GLB generated and committed** at `Assets/Game/Maps/Clocktower/Clocktower.glb`.
- Clocktower GLB contains 38 meshes, 38 materials and 10 embedded texture images. All 11 material texture references were resolved to 10 unique source images; missing references: 0.
- Clocktower source map is centered horizontally and its base top is aligned to ground level.
- **Canonical Olivia GLB generated and committed** at `Assets/Game/Characters/Olivia/Olivia.glb`.
- Olivia Blender rig pipeline passed pose-deformation and GLB round-trip tests: 7 skinned mesh nodes, 1 skin, 22 bones and 10 embedded textures. The final model is 2,687,664 bytes and its corrected height is 1.78 m.
- **Quaternius Universal Animation Library Standard downloaded and verified**. The source archive is CC0 1.0; its checksum is recorded in `AnimationImportReport.json`. The selected Unity FBX is 23,754,684 bytes and uses the in-place, no-root-motion variant. Its paired GLB manifest confirms 43 clips on a 65-joint humanoid rig.
- `QuaterniusAnimationImporter.cs` configures Unity's native FBX importer for Humanoid animations and strips the donor's renderer components so it cannot become a second visible or playable character.
- `QuaterniusAnimationImporter.cs` builds a generated Olivia Animator Controller with locomotion, crouch and jump states once Unity imports the clips.

## Source asset inspection findings

### Olivia
- Source: `source/olivia-free_fire.glb`; 7 meshes, 12,079 vertices and 17,719 faces.
- Original source had 0 armatures, 0 skins and 0 animation clips. It was not rigged.
- The one approved output has 7 skinned mesh nodes, 1 skin, 22 bones and 10 embedded textures.
- The Blender pipeline assigned normalized bone influences, tested pose deformation, exported the skinned GLB and re-imported it successfully.
- The final GLB is 2,687,664 bytes; target height 1.78 m. An extra 42-vertex `Icosphere` helper appears only during Blender re-import and is excluded from the seven validated character meshes.
- `OliviaAvatarAssetBuilder.cs` is prepared to build and validate `OliviaAvatar.asset` in Unity. This Unity Editor step has not yet been executed.
- Source appears to match Sketchfab “Olivia free fire” by Xman, listed CC BY; confirm the match and preserve attribution before distribution.

### Clocktower
- The nested source ZIP passed integrity checks.
- The nested ZIP contains BLEND, FBX and OBJ exports of the same map. Only the FBX was used; alternatives are excluded.
- Blender imported 38 mesh objects, 46,176 vertices and 26,307 faces.
- Approximate source bounds are 87.249 m × 113.65 m × 27.566 m.
- The FBX had stale absolute Windows texture paths. All 11 texture references were successfully matched to 10 unique source images.
- The playable Unity asset is one self-contained GLB; the source FBX is not imported as a second map model.
- Source credit: RS RATUL, Sketchfab, CC BY. Retain attribution.

### Quaternius animations
- Source: Quaternius Universal Animation Library [Standard], official itch.io distribution.
- License: CC0 1.0 Universal.
- The archive SHA-256 is `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724`.
- Selected file: `Unity/UAL1_Standard.fbx`, root motion disabled. The reference GLB confirms 43 animation clips and 65 humanoid joints.
- The FBX has not yet been imported by Unity, so its Avatar, imported clip names and retargeting are not yet editor-verified.

## Not yet completed

- Unity Editor C# compilation and import of the three canonical assets.
- Unity validation of Olivia's Humanoid Avatar.
- Unity validation of the Quaternius donor Humanoid Avatar, 43 FBX clips and generated Animator Controller.
- Automatic creation and inspection of `Assets/Scenes/Match.unity`.
- No Unity Editor Play Mode test, Android build or real-device test has been performed.
- Firing, aiming and weapon switching are not connected to a weapon system yet.
- Weapon models, combat, bots, enterable interiors, bot navigation and match scoring are not implemented.
- Clocktower collision, interiors, navigation and Redmi 12 performance still need gameplay validation.

## Next safe steps

1. Open the Unity project in the pinned Unity 6.0.23f1 Editor and validate all imports and Humanoid Avatars.
2. Confirm the 43 Quaternius clips import and the generated locomotion/crouch/jump controller retargets cleanly to Olivia.
3. Create and inspect one Match scene with one Clocktower instance and one Olivia player.
4. Test movement, camera, animations, map collision and building access.
5. Add weapon models, aiming, firing and reload animations before implementing full 4v4 combat and bots.
