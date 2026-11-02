import bpy
import hashlib
import json
import os
import struct
from pathlib import Path

SOURCE_DIR = Path("build/weapons-source")
OUTPUT_DIR = Path("game/assets/weapons")
NAMES = ["assault_rifle", "smg", "shotgun", "pistol"]
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def read_glb_json(path):
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise RuntimeError(f"Invalid GLB header: {path}")
    offset = 12
    while offset + 8 <= len(raw):
        length, chunk_type = struct.unpack_from("<I4s", raw, offset)
        offset += 8
        chunk = raw[offset:offset + length]
        offset += length
        if chunk_type == b"JSON":
            return json.loads(chunk.decode("utf-8"))
    raise RuntimeError(f"GLB JSON chunk missing: {path}")

results = {}
for name in NAMES:
    source = SOURCE_DIR / f"{name}.glb"
    output = OUTPUT_DIR / f"{name}.glb"
    if not source.is_file() or source.stat().st_size < 100000:
        raise SystemExit(f"Source weapon GLB missing or too small: {source}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        raise SystemExit(f"Blender could not import mesh geometry from {name}")

    vertices = sum(len(obj.data.vertices) for obj in mesh_objects)
    triangles = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in mesh_objects)
    material_count = len(bpy.data.materials)
    image_count = len([image for image in bpy.data.images if image.source == "FILE"])

    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objects[0]

    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_yup=True,
        export_cameras=False,
        export_lights=False
    )

    document = read_glb_json(output)
    required = document.get("extensionsRequired", [])
    if "KHR_mesh_quantization" in required:
        raise SystemExit(f"Quantized extension remains required after Blender conversion: {name}")
    if not document.get("meshes"):
        raise SystemExit(f"Converted weapon has no mesh data: {name}")

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    results[name] = {
        "source_bytes": source.stat().st_size,
        "output_bytes": output.stat().st_size,
        "sha256": digest,
        "mesh_objects": len(mesh_objects),
        "vertices": vertices,
        "triangles": triangles,
        "materials": material_count,
        "images": image_count,
        "extensions_required": required
    }
    print("WEAPON_CONVERSION_OK", name, json.dumps(results[name]))

Path("build/weapon-models-converted.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
