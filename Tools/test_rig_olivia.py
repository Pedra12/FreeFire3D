from __future__ import annotations

import base64
import hashlib
import json
import re
import struct
import sys
import tempfile
import zipfile
from pathlib import Path

sys.path.append("/usr/lib/python3/dist-packages")
from PIL import Image
import numpy as np

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "SourceArchives/olivia-free-fire.zip"
OUT_DIR = ROOT / "Assets/Game/Characters/Olivia"
OUT_FBX = OUT_DIR / "Olivia.fbx"
REPORT_FILE = OUT_DIR / "OliviaRigReport.json"
OUT_DIR.mkdir(parents=True, exist_ok=True)

if OUT_FBX.exists():
    old_report = {}
    if REPORT_FILE.exists():
        try:
            old_report = json.loads(REPORT_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    if old_report.get("rigging_method") == "manual_segment_distance_weights_v1":
        OUT_FBX.unlink()
        REPORT_FILE.unlink(missing_ok=True)
    else:
        raise SystemExit("Refusing to overwrite an unrecognized Olivia model.")
other_models = [p for p in OUT_DIR.rglob("*") if p.is_file()
                and p.suffix.lower() in {".glb", ".gltf", ".fbx", ".obj", ".blend", ".dae"}
                and p != OUT_FBX]
if other_models:
    raise SystemExit("Refusing to mix Olivia model versions: " + ", ".join(str(p) for p in other_models))

tmp = Path(tempfile.mkdtemp(prefix="ff3d_olivia_rig_"))
with zipfile.ZipFile(ARCHIVE) as zf:
    glb_name = next(n for n in zf.namelist() if n.lower().endswith(".glb"))
    source_glb = tmp / "olivia.glb"
    source_glb.write_bytes(zf.read(glb_name))

# Extract embedded GLB image payloads so the final FBX can carry the same textures.
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
    try:
        with Image.open(source_path) as source_image:
            source_image.load()
            rgba = source_image.convert("RGBA")
            width, height = rgba.size
            normalized_path = image_dir / f"Image_{index}_normalized.png"
            rgba.save(normalized_path, format="PNG", optimize=True)
    except Exception as exc:
        raise SystemExit(f"Could not decode embedded Olivia image {index} ({mime}): {exc}")
    extracted_images[index] = normalized_path

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source_glb))
print("OLIVIA_IMPORTED_IMAGES=" + ", ".join(img.name for img in bpy.data.images), flush=True)

# Recreate image datablocks from the decoded embedded images and remap material nodes by GLB image index.
loaded_images_by_index = {}
for index, path in extracted_images.items():
    with Image.open(path) as source_image:
        source_image.load()
        rgba = source_image.convert("RGBA").transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        width, height = rgba.size
        pixels = np.asarray(rgba, dtype=np.float32) / 255.0
    loaded = bpy.data.images.new(
        name=f"OliviaTexture_{index}", width=width,
        height=height, alpha=True, float_buffer=False
    )
    loaded.pixels.foreach_set(pixels.reshape(-1))
    loaded.update()
    loaded.filepath_raw = str(path)
    loaded.file_format = "PNG"
    loaded.save()
    loaded.pack()
    if not loaded.has_data:
        raise SystemExit(f"Could not create Blender texture data for Olivia image {index}")
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

used_source_images = set()
for material in bpy.data.materials:
    if material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                used_source_images.add(node.image)
if not used_source_images:
    raise SystemExit("Olivia has no material texture images after remapping.")
for image in used_source_images:
    if not image.has_data or image.size[0] <= 0 or image.size[1] <= 0:
        raise SystemExit(f"Olivia texture has no decoded pixels: {image.name}")
    image.pack()
print(f"OLIVIA_SOURCE_TEXTURES={len(used_source_images)}", flush=True)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if len(meshes) != 7:
    raise SystemExit(f"Unexpected Olivia mesh count: {len(meshes)}")
source_mesh_count = len(meshes)
source_vertex_count = sum(len(o.data.vertices) for o in meshes)
source_face_count = sum(len(o.data.polygons) for o in meshes)

points = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
mins = [min(p[i] for p in points) for i in range(3)]
maxs = [max(p[i] for p in points) for i in range(3)]
height = maxs[2] - mins[2]
if not 4.5 <= height <= 5.6:
    raise SystemExit(f"Unexpected Olivia source height: {height}")
center_x = (mins[0] + maxs[0]) * 0.5
center_y = (mins[1] + maxs[1]) * 0.5
z0 = mins[2]

def z(ratio):
    return z0 + height * ratio

# Humanoid A-pose guide, fitted to the measured source proportions.
z_hips, z_knee, z_ankle = z(0.49), z(0.25), z(0.06)
z_spine, z_chest, z_neck, z_head = z(0.64), z(0.78), z(0.84), z(0.99)
z_elbow, z_wrist, z_hand = z(0.68), z(0.57), z(0.52)
shoulder_x, elbow_x, wrist_x, hand_x = 0.36, 0.84, 1.22, 1.36
hip_x, knee_x, ankle_x = 0.22, 0.22, 0.20

arm_data = bpy.data.armatures.new("Olivia_Humanoid_Armature")
armature = bpy.data.objects.new("Olivia_Humanoid_Armature", arm_data)
bpy.context.scene.collection.objects.link(armature)
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bones = {}

def make_bone(name, head, tail, parent=None, deform=True):
    bone = arm_data.edit_bones.new(name)
    bone.head = Vector(head)
    bone.tail = Vector(tail)
    bone.use_deform = deform
    if parent:
        bone.parent = bones[parent]
        bone.use_connect = (bone.head - bones[parent].tail).length < 0.0001
    bones[name] = bone
    return bone

make_bone("Root", (center_x, center_y, z0), (center_x, center_y, z_hips), deform=False)
make_bone("Hips", (center_x, center_y, z_hips), (center_x, center_y, z_hips + 0.22), "Root")
make_bone("Spine", (center_x, center_y, z_hips + 0.22), (center_x, center_y, z_spine), "Hips")
make_bone("Chest", (center_x, center_y, z_spine), (center_x, center_y, z_chest), "Spine")
make_bone("Neck", (center_x, center_y, z_chest), (center_x, center_y, z_neck), "Chest")
make_bone("Head", (center_x, center_y, z_neck), (center_x, center_y, z_head), "Neck")

for side, label in ((-1, "Left"), (1, "Right")):
    make_bone(f"{label}Shoulder", (center_x, center_y, z_chest),
              (center_x + side * shoulder_x, center_y, z_chest), "Chest")
    make_bone(f"{label}UpperArm", (center_x + side * shoulder_x, center_y, z_chest),
              (center_x + side * elbow_x, center_y, z_elbow), f"{label}Shoulder")
    make_bone(f"{label}LowerArm", (center_x + side * elbow_x, center_y, z_elbow),
              (center_x + side * wrist_x, center_y, z_wrist), f"{label}UpperArm")
    make_bone(f"{label}Hand", (center_x + side * wrist_x, center_y, z_wrist),
              (center_x + side * hand_x, center_y, z_hand), f"{label}LowerArm")

    make_bone(f"{label}UpperLeg", (center_x + side * hip_x, center_y, z_hips),
              (center_x + side * knee_x, center_y, z_knee), "Hips")
    make_bone(f"{label}LowerLeg", (center_x + side * knee_x, center_y, z_knee),
              (center_x + side * ankle_x, center_y, z_ankle), f"{label}UpperLeg")
    make_bone(f"{label}Foot", (center_x + side * ankle_x, center_y, z_ankle),
              (center_x + side * ankle_x, center_y - 0.28, z0 + 0.025), f"{label}LowerLeg")
    make_bone(f"{label}Toes", (center_x + side * ankle_x, center_y - 0.28, z0 + 0.025),
              (center_x + side * ankle_x, center_y - 0.42, z0 + 0.025), f"{label}Foot")

bpy.ops.object.mode_set(mode="OBJECT")
armature.show_in_front = True
armature.data.display_type = "STICK"

bone_segments = {}
for bone in arm_data.bones:
    if bone.name == "Root":
        continue
    bone_segments[bone.name] = (
        armature.matrix_world @ bone.head_local,
        armature.matrix_world @ bone.tail_local
    )

def segment_distance(point, a, b):
    ab = b - a
    length_sq = ab.length_squared
    if length_sq < 1e-10:
        return (point - a).length
    t = max(0.0, min(1.0, (point - a).dot(ab) / length_sq))
    return (point - (a + t * ab)).length

def manual_weights(obj):
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    groups = {name: obj.vertex_groups.new(name=name) for name in bone_segments}
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        nearest = sorted(
            ((segment_distance(world, a, b), name) for name, (a, b) in bone_segments.items()),
            key=lambda item: item[0]
        )[:4]
        raw = [1.0 / ((distance + 0.12) ** 2) for distance, _ in nearest]
        total = sum(raw)
        for (_, name), weight in zip(nearest, raw):
            groups[name].add([vertex.index], weight / total, "REPLACE")

def weighted_vertex_count(obj):
    return sum(1 for vertex in obj.data.vertices if any(g.weight > 0.0001 for g in vertex.groups))

for obj in meshes:
    world = obj.matrix_world.copy()
    obj.parent = armature
    obj.matrix_world = world
    modifier = obj.modifiers.new("Olivia_Armature", "ARMATURE")
    modifier.object = armature
    manual_weights(obj)
    if weighted_vertex_count(obj) != len(obj.data.vertices):
        raise SystemExit(f"Unweighted vertices remain in {obj.name}")

bone_weight_counts = {name: 0 for name in bone_segments}
for obj in meshes:
    group_names = {g.index: g.name for g in obj.vertex_groups}
    for vertex in obj.data.vertices:
        for assignment in vertex.groups:
            name = group_names.get(assignment.group)
            if name in bone_weight_counts and assignment.weight > 0.0001:
                bone_weight_counts[name] += 1
required_weight_bones = {
    "Hips", "Spine", "Chest", "Neck", "Head",
    "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
    "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"
}
missing_weight_bones = [name for name in required_weight_bones if bone_weight_counts.get(name, 0) == 0]
if missing_weight_bones:
    raise SystemExit("Humanoid bones without weighted vertices: " + ", ".join(sorted(missing_weight_bones)))

def all_deformed_positions():
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    positions = []
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        evaluated_mesh = evaluated.to_mesh()
        positions.extend(evaluated.matrix_world @ vertex.co for vertex in evaluated_mesh.vertices)
        evaluated.to_mesh_clear()
    return positions

before = all_deformed_positions()
deformation = 0.0
for bone_name in ("LeftUpperArm", "LeftLowerArm", "RightUpperArm"):
    pose_bone = armature.pose.bones[bone_name]
    pose_bone.rotation_mode = "XYZ"
    for axis in range(3):
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        rotation = [0.0, 0.0, 0.0]
        rotation[axis] = 0.18
        pose_bone.rotation_euler = rotation
        after = all_deformed_positions()
        deformation = max(deformation, max(((a-b).length for a, b in zip(before, after)), default=0.0))
for pose_bone in armature.pose.bones:
    pose_bone.rotation_euler = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()
if deformation < 0.0001:
    raise SystemExit("Rig pose test produced no measurable mesh deformation.")

out_fbx = tmp / "Olivia.fbx"
scale_factor = 1.78 / height
bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.fbx(
    filepath=str(out_fbx),
    use_selection=True,
    object_types={"ARMATURE", "MESH"},
    global_scale=scale_factor,
    apply_unit_scale=True,
    use_mesh_modifiers=True,
    add_leaf_bones=False,
    use_armature_deform_only=True,
    bake_anim=False,
    path_mode="COPY",
    embed_textures=True,
    axis_forward="-Z",
    axis_up="Y",
)

# Round-trip the FBX to verify that the rig and skin weights survive export.
bpy.ops.wm.read_factory_settings(use_empty=True)
if hasattr(bpy.ops.wm, "fbx_import"):
    bpy.ops.wm.fbx_import(filepath=str(out_fbx), use_anim=False)
else:
    bpy.ops.import_scene.fbx(filepath=str(out_fbx), use_anim=False)
reimport_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
reimport_armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
if len(reimport_meshes) != source_mesh_count or len(reimport_armatures) != 1:
    raise SystemExit(f"FBX round-trip mismatch: meshes={len(reimport_meshes)} armatures={len(reimport_armatures)}")
reimport_armature = reimport_armatures[0]
required_bones = {
    "Hips", "Spine", "Chest", "Neck", "Head",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"
}
missing_bones = required_bones - {bone.name for bone in reimport_armature.data.bones}
if missing_bones:
    raise SystemExit("FBX lost humanoid bones: " + ", ".join(sorted(missing_bones)))
for obj in reimport_meshes:
    if not any(modifier.type == "ARMATURE" for modifier in obj.modifiers):
        raise SystemExit(f"FBX mesh lost armature modifier: {obj.name}")
    if weighted_vertex_count(obj) != len(obj.data.vertices):
        raise SystemExit(f"FBX mesh has unweighted vertices: {obj.name}")

reimport_points = [o.matrix_world @ Vector(corner) for o in reimport_meshes for corner in o.bound_box]
reimport_height = max(p.z for p in reimport_points) - min(p.z for p in reimport_points)
if not 1.55 <= reimport_height <= 2.0:
    raise SystemExit(f"Unexpected scaled Olivia height after FBX round-trip: {reimport_height}")

report = {
    "rigging_method": "manual_segment_distance_weights_v1",
    "source_model": glb_name,
    "source_height_m": round(height, 3),
    "export_scale_factor": round(scale_factor, 6),
    "target_height_m": round(reimport_height, 3),
    "source_meshes": source_mesh_count,
    "reimport_meshes": len(reimport_meshes),
    "source_vertices": source_vertex_count,
    "source_faces": source_face_count,
    "source_texture_images": len(used_source_images),
    "armature_bones": len(reimport_armature.data.bones),
    "bone_weight_counts": bone_weight_counts,
    "pose_test_max_deformation_m": round(deformation, 6),
    "fbx_size_bytes": out_fbx.stat().st_size,
    "fbx_sha256": hashlib.sha256(out_fbx.read_bytes()).hexdigest(),
}

OUT_FBX.parent.mkdir(parents=True, exist_ok=True)
out_fbx.replace(OUT_FBX)
REPORT_FILE.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("OLIVIA_RIG_TEST_OK")
print(json.dumps(report, indent=2))
