# Migration status

## Completed in the isolated Unity project

- Standalone Unity project at repository root on branch `unity-project`.
- Unity 6.0.23f1 baseline with URP 17.0.3.
- Initial third-person motor and orbit camera scripts.
- Mobile movement joystick, camera-look area and reusable action-button bridge.
- Initial 4v4 match configuration.
- Single approved content slots: Olivia character and Clocktower map.
- Structural CI check added; the first run exposed a version-regex mistake, which was corrected and the next run passed.

## Not yet completed

- The two selected source ZIP files are stored in `SourceArchives/`, outside the Unity `Assets/` folder. The current GitHub file tools cannot decode their binary contents for safe extraction and inspection.
- No character model or map model has been copied into Unity.
- No Unity Editor import, C# compile, scene test, Android build or device test has been performed.
- The mobile HUD components are input building blocks; the actual HUD canvas and button layout are not yet assembled.
- Weapon/combat, bots, interiors and match scene are not yet implemented.

## Next safe operation

Inspect and extract only the canonical Olivia and Clocktower files from their original archives, then configure the one player prefab and one map scene. Do not import any alternate character or map.
