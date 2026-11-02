# Olivia character asset

This is the only approved player-character slot in the Unity project.

## Canonical model

- Model: `Olivia.glb`
- Rig report: `OliviaRigReport.json`
- Humanoid Avatar asset: `OliviaAvatar.asset` (created by the Unity Editor after the GLB imports)
- Source archive: `SourceArchives/olivia-free-fire.zip`

The source GLB contains seven meshes but no armature, skin or animation clips. The preparation pipeline creates one humanoid skeleton, assigns four normalized bone influences per vertex, tests pose deformation, exports one skinned GLB and re-imports it to verify that the skin survives.

The original source model is not retained as a second playable model. It remains only inside the source archive.

## Unity import

`OliviaAvatarAssetBuilder.cs` uses Unity's `AvatarBuilder.BuildHumanAvatar` to construct and validate the Humanoid Avatar from the imported skeleton. The editor must confirm `Avatar.isValid` and `Avatar.isHuman` before the Match scene builder creates the player.

## Current limitation

A Blender deformation test does not replace Unity animation testing. The final Avatar mapping, retargeted locomotion, weapon-hold pose, jump, crouch and Android performance still require validation in Unity.
