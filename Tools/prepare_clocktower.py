from __future__ import annotations

import hashlib
import io
import json
import struct
import tempfile
import zipfile
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Assets/Game/Maps/Clocktower"
OUT_FILE = OUT_DIR / "Clocktower.glb"
REPORT_FILE = OUT_DIR / "AssetImportReport.json"
OUT_DIR.mkdir(parents=True, exist_ok=True)

if OUT_FILE.exists():
    old_report = {}
    if REPORT_FILE.exists():
        try:
            old_report = json.loads(REPORT_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    if old_report.get("asset") == "Clocktower" and old_report.get("source", "").startswith("RS RATUL"):
        OUT_FILE.unlink()
        REPORT_FILE.unlink(missing_ok=True)
    else:
        raise SystemExit("Refusing to overwrite an unrecognized Clocktower model.")
other_models = [p for p in OUT_DIR.rglob("*") if p.is_file()
                and p.suffix.lower() in {".glb", ".gltf", ".fbx", ".obj", ".blend", ".dae"}
                and p != OUT_FILE]
if other_models:
    raise SystemExit("Refusing to mix map versions: " + ", ".join(str(p) for p in other_models))

archive_path = ROOT / "SourceArchives/free-fire-clocktower-3d-model-by-rs-ratul.zip"
temp_root = Path(tempfile.mkdtemp(prefix="ff3d_clocktower_prepare_"))
with zipfile.ZipFile(archive_path) as outer:
    nested_name = next(n for n in outer.namelist() if n.lower().endswith(".zip"))
    nested_data = outer.read(nested_name)

with zipfile.ZipFile(io.BytesIO(nested_data)) as inner:
    fbx_name = next(n for n in inner.namelist() if n.lower().endswith(".fbx"))
    for name in inner.namelist():
        if name.endswith("/"):
            continue
        suffix = Path(name).suffix.lower()
        if suffix != ".fbx" and suffix not in {".png", ".jpg", ".jpeg", ".tga", ".webp"}:
            continue
        target = temp_root / Path(name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(inner.read(name))
    fbx_path = temp_root / Path(fbx_name)

bpy.ops.wm.read_factory_settings(use_empty=True)
if hasattr(bpy.ops.wm, "fbx_import"):
    bpy.ops.wm.fbx_import(filepath=str(fbx_path), use_anim=False)
else:
    bpy.ops.import_scene.fbx(filepath=str(fbx_path), use_image_search=True, use_anim=False)

texture_root = fbx_path.parent.parent / "textures"
relinked = []
missing = []
for image in bpy.data.images:
    if image.source != "FILE":
        continue
    requested = Path(image.filepath.replace(chr(92), "/")).name
    exact = texture_root / requested
    candidate = exact if exact.is_file() else None
    if candidate is None:
        stem = Path(requested).stem.lower()
        matches = [p for p in texture_root.iterdir() if p.is_file()
                   and (p.stem.lower().startswith(stem) or stem.startswith(p.stem.lower()))]
        if len(matches) == 1:
            candidate = matches[0]
        elif len(matches) > 1:
            hashes = {hashlib.sha256(p.read_bytes()).hexdigest() for p in matches}
            if len(hashes) == 1:
                candidate = sorted(matches)[0]
    if candidate is None:
        missing.append(requested)
        continue
    image.filepath = str(candidate)
    image.reload()
    relinked.append(candidate.name)

if missing:
    raise SystemExit("Clocktower has unresolved textures: " + ", ".join(sorted(set(missing))))

# FBX import creates image datablocks with stale Windows paths but no loaded pixels.
# Load each verified archive texture into a fresh Blender image datablock.
loaded_images_by_hash = {}
for material in bpy.data.materials:
    if not material.use_nodes or material.node_tree is None:
        continue
    for node in material.node_tree.nodes:
        if node.type != "TEX_IMAGE" or node.image is None:
            continue
        old_image = node.image
        candidate = Path(old_image.filepath)
        if not candidate.is_file():
            requested = candidate.name
            stem = Path(requested).stem.lower()
            matches = [p for p in texture_root.iterdir() if p.is_file()
                       and (p.stem.lower().startswith(stem) or stem.startswith(p.stem.lower()))]
            if len(matches) == 1:
                candidate = matches[0]
            elif len(matches) > 1:
                hashes = {hashlib.sha256(p.read_bytes()).hexdigest() for p in matches}
                if len(hashes) == 1:
                    candidate = sorted(matches)[0]
        if not candidate.is_file():
            raise SystemExit(f"Texture file not found for material {material.name}: {old_image.filepath}")
        digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if digest not in loaded_images_by_hash:
            loaded_image = bpy.data.images.load(str(candidate), check_existing=False)
            if not loaded_image.has_data:
                loaded_image.reload()
            if not loaded_image.has_data or loaded_image.size[0] <= 0 or loaded_image.size[1] <= 0:
                raise SystemExit(f"Blender could not decode texture pixels: {candidate}")
            loaded_image.pack()
            loaded_images_by_hash[digest] = loaded_image
        node.image = loaded_images_by_hash[digest]

used_images = set()
for material in bpy.data.materials:
    if not material.use_nodes or material.node_tree is None:
        continue
    for node in material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image and any(
            link.from_node == node for link in material.node_tree.links
        ):
            used_images.add(node.image)
for image in used_images:
    if not image.has_data or image.size[0] <= 0 or image.size[1] <= 0:
        raise SystemExit(f"Texture image has no decoded pixels: {image.name}")
    if image.source == "FILE":
        image.pack()
print(f"UNIQUE_USED_TEXTURE_IMAGES={len(used_images)}", flush=True)
for image in sorted(used_images, key=lambda x: x.name):
    print(f"  PACKED_TEXTURE={image.name} size={tuple(image.size)} has_data={image.has_data}", flush=True)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if len(meshes) != 38:
    raise SystemExit(f"Unexpected Clocktower mesh count: {len(meshes)} (expected 38)")

points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
mins = [min(p[i] for p in points) for i in range(3)]
maxs = [max(p[i] for p in points) for i in range(3)]
base_objects = [o for o in meshes if o.name.startswith("Base_02")]
if not base_objects:
    raise SystemExit("Clocktower base mesh Base_02 was not found.")
base_points = [o.matrix_world @ Vector(corner) for o in base_objects for corner in o.bound_box]
base_top_z = max(p.z for p in base_points)
center_x = (mins[0] + maxs[0]) * 0.5
center_y = (mins[1] + maxs[1]) * 0.5
offset = Vector((-center_x, -center_y, -base_top_z))

for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        matrix = obj.matrix_world.copy()
        matrix.translation += offset
        obj.matrix_world = matrix

temp_glb = Path(tempfile.gettempdir()) / "Clocktower_validated.glb"
if temp_glb.exists():
    temp_glb.unlink()
bpy.ops.export_scene.gltf(
    filepath=str(temp_glb),
    export_format="GLB",
    export_image_format="AUTO",
    export_materials="EXPORT",
    export_texcoords=True,
    export_normals=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)

data = temp_glb.read_bytes()
if data[:4] != b"glTF":
    raise SystemExit("Blender did not produce a valid GLB file.")
version, declared_length = struct.unpack_from("<II", data, 4)
if version != 2 or declared_length != len(data):
    raise SystemExit("Clocktower GLB header/length validation failed.")
offset = 12
gltf = None
while offset + 8 <= len(data):
    chunk_size, chunk_type = struct.unpack_from("<II", data, offset)
    offset += 8
    chunk = data[offset:offset + chunk_size]
    offset += chunk_size
    if chunk_type == 0x4E4F534A:
        gltf = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        break
if gltf is None:
    raise SystemExit("Clocktower GLB JSON chunk is missing.")
exported_images = len(gltf.get("images", []))
if exported_images != len(used_images):
    raise SystemExit(
        f"Texture export mismatch: {len(used_images)} used source images, "
        f"but GLB contains {exported_images} images."
    )
temp_glb.replace(OUT_FILE)

report = {
    "asset": "Clocktower",
    "source": "RS RATUL, Free Fire Clocktower 3D Model By Rs Ratul",
    "license": "CC BY (attribution required)",
    "source_url": "https://sketchfab.com/3d-models/free-fire-clocktower-3d-model-by-rs-ratul-70c66345c0b745f98972eaff255a494b",
    "canonical_model": "Clocktower.glb",
    "source_format_selected": "FBX only",
    "excluded_alternates": ["BLEND", "OBJ"],
    "source_mesh_objects": len(meshes),
    "source_vertices": sum(len(o.data.vertices) for o in meshes),
    "source_faces": sum(len(o.data.polygons) for o in meshes),
    "source_bounds_size_m": [round(maxs[i] - mins[i], 3) for i in range(3)],
    "base_top_z_before_centering": round(base_top_z, 3),
    "texture_references_relinked": len(relinked),
    "texture_names": sorted(set(relinked)),
    "texture_references_missing": 0,
    "glb_meshes": len(gltf.get("meshes", [])),
    "glb_materials": len(gltf.get("materials", [])),
    "glb_images": exported_images,
    "used_source_texture_images": len(used_images),
    "glb_nodes": len(gltf.get("nodes", [])),
    "file_size_bytes": len(data),
    "sha256": hashlib.sha256(data).hexdigest(),
}
REPORT_FILE.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("CLOCKTOWER_EXPORT_OK")
print(json.dumps(report, indent=2))
