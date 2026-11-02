# Olivia character asset

This is the only approved player-character slot in the Unity project.

The selected source archive contains exactly one model: `source/olivia-free_fire.glb`, with its textures embedded. Structural inspection of the GLB reports 7 meshes, 7 materials, 10 images, **zero skins and zero animation clips**. The model is therefore not rigged and cannot yet be driven by the TPS Animator.

Keep this exact Olivia as the sole canonical character. The next character-art task is to create a proper humanoid armature and skin weights for this model, then validate deformation before connecting locomotion, jump, aim and weapon animations. Do not add another Olivia model as a parallel version.

The GLB has not yet been imported into Unity. glTFast is pinned in the package manifest to import GLB files into Unity assets.
