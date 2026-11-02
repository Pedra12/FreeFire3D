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
    raise SystemExit("Refusing to create a second Clocktower model: canonical GLB already exists.")
other_models = [p for p in OUT_DIR.rglob("*") if p.is_file()
                and p.suffix.lower() in {".glb", ".gltf", ".fbx", ".obj", ".blend", ".dae"}]
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

bpy.ops.export_scene.gltf(
    filepath=str(OUT_FILE),
    export_format="GLB",
    export_image_format="AUTO",
    export_materials="EXPORT",
    export_texcoords=True,
    export_normals=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)

data = OUT_FILE.read_bytes()
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
        gltf = json.loads(chunk.decode("utf-8").rstrip("\\x00 "))
        break
if gltf is None:
    raise SystemExit("Clocktower GLB JSON chunk is missing.")

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
    "glb_images": len(gltf.get("images", [])),
    "glb_nodes": len(gltf.get("nodes", [])),
    "file_size_bytes": len(data),
    "sha256": hashlib.sha256(data).hexdigest(),
}
REPORT_FILE.write_text(json.dumps(report, indent=2) + "\\n", encoding="utf-8")
print("CLOCKTOWER_EXPORT_OK")
print(json.dumps(report, indent=2))
