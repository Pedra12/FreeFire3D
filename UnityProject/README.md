# FreeFire3D Unity migration

This folder is the new Unity project. The existing Godot implementation remains untouched on the `4v4-premium-prototype` branch.

## Target

- Android-first third-person shooter.
- Offline 4v4 match: player + 3 allies versus 4 enemy bots.
- Olivia is the initial player character.
- Mobile touch controls: left movement stick, right look area, aim, fire, jump, sprint, crouch, reload and weapon switching.
- First milestone: prove stable TPS movement, camera orbit, animation parameters and Android performance before expanding combat and AI.

## Migration rules

1. Do not port Godot scripts line-for-line. Rebuild systems using Unity components and C#.
2. Preserve original source archives in the repository. Import only assets that have been inspected and converted.
3. Reuse compatible source models, textures, weapons, audio and map geometry where licensing permits. Re-rig or retarget animation clips where skeletons differ.
4. Build in vertical slices: character + camera; mobile input; weapon handling; map + collision; bots; match rules; polish.
5. Keep Android performance in mind. Use URP, baked lighting where appropriate, LODs, texture compression and sensible texture sizes. 4K textures are selective, not a blanket setting.
6. Do not call the migration complete until the Unity project imports cleanly, builds for Android, installs and is tested on a real device.

## Build environment

Unity Editor version is pinned in `ProjectSettings/ProjectVersion.txt`. An automated Android build also needs a valid Unity Personal/Plus/Pro license activation in the CI environment. No APK should be claimed until the licensed Unity build succeeds and the artifact is verified.

## Current status

- Migration branch created from the last Godot project commit.
- Unity project settings and initial TPS/mobile-input code are being established.
- No Unity APK exists yet.
