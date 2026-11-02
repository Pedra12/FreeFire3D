# Clocktower map asset

This is the only approved playable map slot for the first Unity vertical slice.

The original Clocktower archive contains a nested ZIP. Inside it are three alternative exports of the same map: `.blend`, `.fbx` and `.obj`. The Unity project will use **only the FBX export** as its canonical map source. The Blender and OBJ alternatives are inspection/source copies and must not be imported into the playable project.

The nested archive also contains the map textures. Preserve their relative folder structure so the FBX material references can resolve. Before using the map in the match, inspect scale, orientation, mesh complexity, material links and collision suitability. Do not assume that all buildings have walkable interiors or usable doors/windows.

No map model has been imported yet. This folder remains reserved until model inspection passes.
