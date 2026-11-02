import bpy
import json
import os
import sys
import tempfile
import zipfile
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
root = Path(args[0]).resolve()
olivia_zip = root / "SourceArchives/olivia-free-fire.zip"
clocktower_zip = root / "SourceArchives/free-fire-clocktower-3d-model-by-rs-ratul.zip"
tmp = Path(tempfile.mkdtemp(prefix="ff3d_asset_audit_"))

def inspect_scene(label):
    objects = list(bpy.context.scene.objects)
    meshes = [o for o in objects if o.type == "MESH"]
    armatures = [o for o in objects if o.type == "ARMATURE"]
    print(f"\n=== BLENDER INSPECTION: {label} ===", flush=True)
    print(f"OBJECTS={len(objects)} MESHES={len(meshes)} ARMATURES={len(armatures)}", flush=True)
    total_verts = sum(len(o.data.vertices) for o in meshes)
    total_faces = sum(len(o.data.polygons) for o in meshes)
    print(f"TOTAL_VERTICES={total_verts} TOTAL_FACES={total_faces}", flush=True)
    for o in objects:
        dims = tuple(round(float(v), 3) for v in o.dimensions)
        print(f"OBJECT name={o.name!r} type={o.type} dims={dims} "
              f"materials={len(o.material_slots)}", flush=True)
    for arm in armatures:
        print(f"ARMATURE name={arm.name!r} bones={len(arm.data.bones)}", flush=True)
        for bone in arm.data.bones:
            print(f"  BONE {bone.name}", flush=True)
    image_paths = set()
    for material in bpy.data.materials:
        if not material.use_nodes or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                image_paths.add(bpy.path.abspath(node.image.filepath))
    print("TEXTURE_REFERENCES:", flush=True)
    for p in sorted(image_paths):
        print(f"  {p}", flush=True)
    print("MATERIALS:", flush=True)
    for m in bpy.data.materials:
        print(f"  {m.name}", flush=True)

# Olivia: one GLB only, textures are embedded in GLB and in source zip as copies.
with zipfile.ZipFile(olivia_zip) as outer:
    glb = next(n for n in outer.namelist() if n.lower().endswith(".glb"))
    olivia_path = tmp / "olivia.glb"
    olivia_path.write_bytes(outer.read(glb))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(olivia_path))
inspect_scene("OLIVIA GLB")

# Clocktower: unpack the nested ZIP and import only the FBX representation.
with zipfile.ZipFile(clocktower_zip) as outer:
    nested_name = next(n for n in outer.namelist() if n.lower().endswith(".zip"))
    nested_data = outer.read(nested_name)
with zipfile.ZipFile(__import__("io").BytesIO(nested_data)) as inner:
    fbx_name = next(n for n in inner.namelist() if n.lower().endswith(".fbx"))
    model_root = tmp / "clocktower"
    model_root.mkdir()
    for name in inner.namelist():
        if name.endswith("/"):
            continue
        target = model_root / Path(name)
        target.write_bytes(inner.read(name))
    fbx_path = model_root / Path(fbx_name)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(fbx_path), use_image_search=True)
inspect_scene("CLOCKTOWER FBX")
