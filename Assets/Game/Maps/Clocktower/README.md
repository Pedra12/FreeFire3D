# Clocktower map asset

This is the only approved playable map for the first Unity vertical slice.

## Canonical Unity model

- Model: `Clocktower.glb`
- Import report: `AssetImportReport.json`
- One source export selected: FBX
- Alternative BLEND and OBJ exports were excluded from the playable project.
- The GLB contains 38 meshes, 38 materials and 10 embedded texture images.
- All 11 material texture references were resolved to 10 unique source images; no missing texture references remain.
- The source FBX had stale absolute Windows paths. These were repaired before export.
- The map was centered horizontally and its base top was aligned to ground level.

The source archive remains in `SourceArchives/`; it is not a second playable map.

## Attribution

Source credit: RS RATUL, “FREE FIRE CLOCKTOWER 3D MODEL BY RS RATUL”, Sketchfab, licensed under Creative Commons Attribution (CC BY). Retain this attribution in the game credits and distribution notes:
https://sketchfab.com/3d-models/free-fire-clocktower-3d-model-by-rs-ratul-70c66345c0b745f98972eaff255a494b

## Gameplay validation still required

The model is imported as a static environment asset. Walkable interiors, doors/windows, player collision, bot navigation and performance on the Redmi 12 have not yet been tested in Unity. Do not assume every building is enterable until those checks pass.
