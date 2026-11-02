from __future__ import annotations

import base64
import io
import json
import re
import struct
import sys
import tempfile
import zipfile
from pathlib import Path

sys.path.append('/usr/lib/python3/dist-packages')
from PIL import Image
import numpy as np

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "SourceArchives/olivia-free-fire.zip"
tmp = Path(tempfile.mkdtemp(prefix="ff3d_olivia_rig_test_"))
with zipfile.ZipFile(ARCHIVE) as zf:
    glb_name = next(n for n in zf.namelist() if n.lower().endswith(".glb"))
    source_glb = tmp / "olivia.glb"
    source_glb.write_bytes(zf.read(glb_name))

# Extract the GLB's embedded images so Blender can reload their actual pixel data.
raw_glb = source_glb.read_bytes()
if raw_glb[:4] != b"glTF":
    raise SystemExit("Olivia source is not a valid GLB.")
offset = 12
gltf_json = None
binary_chunk = b""
while offset + 8 <= len(raw_glb):
    chunk_size, chunk_type = struct.unpack_from("<II", raw_glb, offset)
    offset += 8
    chunk = raw_glb[offset:offset + chunk_size]
    offset += chunk_size
    if chunk_type == 0x4E4F534A:
        gltf_json = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
    elif chunk_type == 0x004E4942:
        binary_chunk = chunk
if gltf_json is None:
    raise SystemExit("Olivia GLB has no JSON chunk.")

image_dir = tmp / "textures"
image_dir.mkdir()
extracted_images = {}
for index, image in enumerate(gltf_json.get("images", [])):
    mime = image.get("mimeType", "image/png")
    ext = ".jpg" if "jpeg" in mime or "jpg" in mime else ".webp" if "webp" in mime else ".png"
    if "bufferView" in image:
        view = gltf_json["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        image_bytes = binary_chunk[start:start + view["byteLength"]]
    elif image.get("uri", "").startswith("data:"):
        image_bytes = base64.b64decode(image["uri"].split(",", 1)[1])
    else:
        raise SystemExit(f"Unsupported external Olivia image reference: {image}")
    source_path = image_dir / f"Image_{index}{ext}"
    source_path.write_bytes(image_bytes)
    normalized_path = image_dir / f"Image_{index}_normalized.png"
    try:
        with Image.open(source_path) as source_image:
            source_image.load()
            mode = "RGBA" if "A" in source_image.getbands() else "RGB"
            source_image.convert(mode).save(normalized_path, format="PNG", optimize=True)
    except Exception as exc:
        raise SystemExit(f"Could not decode embedded Olivia image {index} ({mime}): {exc}")
    extracted_images[index] = normalized_path

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source_glb))
print("OLIVIA_IMPORTED_IMAGES=" + ", ".join(img.name for img in bpy.data.images), flush=True)
loaded_image_indices = set()
loaded_images_by_index = {}
for image in list(bpy.data.images):
    match = re.search(r"Image[_ ]?(\d+)", image.name)
    if not match:
        continue
    index = int(match.group(1))
    if index not in extracted_images:
        continue
    path = extracted_images[index]
    try:
        with Image.open(path) as source_image:
            source_image.load()
            rgba = source_image.convert("RGBA").transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            width, height = rgba.size
            pixels = np.asarray(rgba, dtype=np.float32) / 255.0
    except Exception as exc:
        raise SystemExit(f"Could not decode extracted Olivia image {index}: {exc}")
    loaded = bpy.data.images.new(
        name=f"OliviaTexture_{index}", width=width, height=height, alpha=True, float_buffer=False
    )
    loaded.pixels.foreach_set(pixels.reshape(-1))
    loaded.update()
    loaded.filepath_raw = str(path)
    loaded.file_format = "PNG"
    loaded.save()
    loaded.pack()
    if not loaded.has_data or loaded.size[0] <= 0 or loaded.size[1] <= 0:
        raise SystemExit(f"Blender pixel datablock creation failed for Olivia image {index}")
    loaded_image_indices.add(index)
    loaded_images_by_index[index] = loaded

for material in bpy.data.materials:
    if material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            match = re.search(r"Image[_ ]?(\d+)", node.image.name)
            if match:
                index = int(match.group(1))
                if index in loaded_images_by_index:
                    node.image = loaded_images_by_index[index]

if loaded_image_indices != set(extracted_images.keys()):
    raise SystemExit(f"Not all embedded Olivia images were loaded: {sorted(loaded_image_indices)}")
used_source_images = set()
for material in bpy.data.materials:
    if material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                used_source_images.add(node.image)
for image in used_source_images:
    if not image.has_data or image.size[0] <= 0 or image.size[1] <= 0:
        raise SystemExit(f"Olivia source texture has no pixels: {image.name}")
    image.pack()
print(f"OLIVIA_SOURCE_TEXTURES={len(used_source_images)}", flush=True)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
reimport_armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
if len(reimport_meshes) != 7 or len(reimport_armatures) != 1:
    raise SystemExit(f"FBX round-trip mismatch: meshes={len(reimport_meshes)} armatures={len(reimport_armatures)}")
reimport_armature = reimport_armatures[0]
required_bones = {"Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"}
missing_bones = required_bones - {b.name for b in reimport_armature.data.bones}
if missing_bones:
    raise SystemExit("FBX lost humanoid bones: " + ", ".join(sorted(missing_bones)))
for obj in reimport_meshes:
    if not any(m.type == "ARMATURE" for m in obj.modifiers):
        raise SystemExit(f"FBX mesh lost armature modifier: {obj.name}")
    if weighted_vertex_count(obj) != len(obj.data.vertices):
        raise SystemExit(f"FBX mesh has unweighted vertices: {obj.name}")

reimport_points = [o.matrix_world @ Vector(corner) for o in reimport_meshes for corner in o.bound_box]
reimport_height = max(p.z for p in reimport_points) - min(p.z for p in reimport_points)
if not 1.55 <= reimport_height <= 2.0:
    raise SystemExit(f"Unexpected scaled Olivia height after FBX round-trip: {reimport_height}")

report = {
    "source_model": glb_name,
    "source_height_m": round(height, 3),
    "export_scale_factor": round(scale_factor, 6),
    "target_height_m": round(reimport_height, 3),
    "source_meshes": len(meshes),
    "reimport_meshes": len(reimport_meshes),
    "source_vertices": sum(len(o.data.vertices) for o in meshes),
    "armature_bones": len(reimport_armature.data.bones),
    "auto_weighted_meshes": auto_weighted,
    "manual_weighted_meshes": fallback_weighted,
    "bone_weight_counts": bone_weight_counts,
    "fallback_weighted_meshes": fallback_weighted,
    "pose_test_max_deformation_m": round(deformation, 6),
    "fbx_size_bytes": out_fbx.stat().st_size,
}
print("OLIVIA_RIG_TEST_OK")
print(json.dumps(report, indent=2))
