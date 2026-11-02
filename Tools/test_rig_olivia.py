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
OUT_GLB = OUT_DIR / "Olivia.glb"
REPORT_FILE = OUT_DIR / "OliviaRigReport.json"
OUT_DIR.mkdir(parents=True, exist_ok=True)

if OUT_GLB.exists():
    old_report = {}
    if REPORT_FILE.exists():
        try:
            old_report = json.loads(REPORT_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    if old_report.get("rigging_method") == "manual_segment_distance_weights_v1":
        OUT_GLB.unlink()
        REPORT_FILE.unlink(missing_ok=True)
    else:
        raise SystemExit("Refusing to overwrite an unrecognized Olivia model.")
other_models = [p for p in OUT_DIR.rglob("*") if p.is_file()
                and p.suffix.lower() in {".glb", ".gltf", ".fbx", ".obj", ".blend", ".dae"}
                and p != OUT_GLB]
if other_models:
    raise SystemExit("Refusing to mix Olivia model versions: " + ", ".join(str(p) for p in other_models))

tmp = Path(tempfile.mkdtemp(prefix="ff3d_olivia_rig_"))
with zipfile.ZipFile(ARCHIVE) as zf:
    glb_name = next(n for n in zf.namelist() if n.lower().endswith(".glb"))
    source_glb = tmp / "olivia_source.glb"
    source_glb.write_bytes(zf.read(glb_name))

def read_glb_json(path: Path):
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise SystemExit(f"Invalid GLB header: {path}")
    version, declared_length = struct.unpack_from("<II", data, 4)
    if version != 2 or declared_length != len(data):
        raise SystemExit(f"Invalid GLB version/length: {path}")
    offset = 12
    gltf = None
    binary = b""
    while offset + 8 <= len(data):
        chunk_size, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + chunk_size]
        offset += chunk_size
        if chunk_type == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8").rstrip("\x00 "))
        elif chunk_type == 0x004E4942:
            binary = chunk
    if gltf is None:
        raise SystemExit(f"GLB JSON chunk missing: {path}")
    return data, gltf, binary

_, source_json, source_binary = read_glb_json(source_glb)
image_dir = tmp / "source_textures"
image_dir.mkdir()
extracted_images = {}
for index, image in enumerate(source_json.get("images", [])):
    mime = image.get("mimeType", "image/png")
    ext = ".jpg" if "jpeg" in mime or "jpg" in mime else ".webp" if "webp" in mime else ".png"
    if "bufferView" in image:
        view = source_json["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        image_bytes = source_binary[start:start + view["byteLength"]]
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
            source_image.convert("RGBA").save(normalized_path, format="PNG", optimize=True)
    except Exception as exc:
        raise SystemExit(f"Could not decode embedded Olivia image {index} ({mime}): {exc}")
    extracted_images[index] = normalized_path

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source_glb))
print("OLIVIA_IMPORTED_IMAGES=" + ", ".join(img.name for img in bpy.data.images), flush=True)

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
    normalized_copy = image_dir / f"BlenderTexture_{index}.png"
    loaded.filepath_raw = str(normalized_copy)
    loaded.file_format = "PNG"
    loaded.save()
    loaded.pack()
    if not loaded.has_data or loaded.size[0] <= 0 or loaded.size[1] <= 0:
        raise SystemExit(f"Could not create Blender texture data for Olivia image {index}")
    loaded_images_by_index[index] = loaded

mapped_image_indices = set()
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
                    mapped_image_indices.add(index)

if not mapped_image_indices:
    raise SystemExit("No Olivia material nodes were linked to the extracted GLB textures.")
used_source_images = set()
for material in bpy.data.materials:
    if material.use_nodes and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                used_source_images.add(node.image)
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
    group_names = {group.index: group.name for group in obj.vertex_groups}
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

scale_factor = 1.78 / height
armature.scale = (scale_factor, scale_factor, scale_factor)
bpy.context.view_layer.update()

# Keep only the rig and skinned meshes in the exported GLB.
for obj in list(bpy.context.scene.objects):
    if obj.type not in {"MESH", "ARMATURE"}:
        bpy.data.objects.remove(obj, do_unlink=True)

out_glb = tmp / "Olivia.glb"
gltf_operator = bpy.ops.export_scene.gltf
gltf_properties = {prop.identifier for prop in gltf_operator.get_rna_type().properties}
gltf_args = {
    "filepath": str(out_glb),
    "export_format": "GLB",
    "export_image_format": "AUTO",
    "export_materials": "EXPORT",
    "export_texcoords": True,
    "export_normals": True,
    "export_tangents": True,
    "export_skins": True,
    "export_animations": False,
    "export_cameras": False,
    "export_lights": False,
    "export_apply": False,
    "export_draco_mesh_compression_enable": False,
    "export_yup": True,
}
gltf_args = {key: value for key, value in gltf_args.items() if key in gltf_properties}
print("GLTF_EXPORT_PROPERTIES=" + ",".join(sorted(gltf_properties)), flush=True)
gltf_operator(**gltf_args)
if not out_glb.is_file() or out_glb.stat().st_size < 1024:
    raise SystemExit("Blender did not create a usable rigged Olivia GLB.")

_, exported_json, _ = read_glb_json(out_glb)
exported_images = len(exported_json.get("images", []))
exported_meshes = len(exported_json.get("meshes", []))
exported_skins = len(exported_json.get("skins", []))
mesh_nodes_info = [
    {
        "name": node.get("name", ""),
        "mesh": node.get("mesh"),
        "skin": node.get("skin"),
        "primitives": len(exported_json.get("meshes", [])[node["mesh"]].get("primitives", []))
            if "mesh" in node else 0
    }
    for node in exported_json.get("nodes", []) if "mesh" in node
]
print("OLIVIA_GLB_MESH_NODES=" + json.dumps(mesh_nodes_info), flush=True)
unskinned_nodes = [node["name"] or f"mesh_{node['mesh']}" for node in mesh_nodes_info if node["skin"] is None]
if unskinned_nodes:
    raise SystemExit("GLB contains mesh nodes without the humanoid skin: " + ", ".join(unskinned_nodes))
if exported_meshes != source_mesh_count:
    raise SystemExit(f"GLB mesh count mismatch: {exported_meshes} != {source_mesh_count}")
if exported_skins != 1:
    raise SystemExit(f"Rigged Olivia GLB must contain exactly one skin, found {exported_skins}")
if exported_images != len(used_source_images):
    raise SystemExit(f"Olivia texture export mismatch: source={len(used_source_images)} GLB={exported_images}")

# Round-trip the GLB and verify skeleton, skin weights, texture count and scale.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out_glb))
reimport_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
reimport_armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
if len(reimport_meshes) < source_mesh_count or len(reimport_meshes) > source_mesh_count + 2 or len(reimport_armatures) != 1:
    raise SystemExit(f"GLB round-trip mismatch: meshes={len(reimport_meshes)} armatures={len(reimport_armatures)}")
print("OLIVIA_REIMPORT_MESHES=" + ", ".join(
    f"{obj.name}:{len(obj.data.vertices)}" for obj in reimport_meshes
), flush=True)
reimport_armature = reimport_armatures[0]
required_bones = {
    "Hips", "Spine", "Chest", "Neck", "Head",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg"
}
missing_bones = required_bones - {bone.name for bone in reimport_armature.data.bones}
if missing_bones:
    raise SystemExit("GLB lost humanoid bones: " + ", ".join(sorted(missing_bones)))
expected_mesh_node_names = {node["name"] for node in mesh_nodes_info}
validated_reimport_meshes = [
    obj for obj in reimport_meshes if obj.name in expected_mesh_node_names
]
unexpected_reimport_meshes = [
    obj.name for obj in reimport_meshes if obj.name not in expected_mesh_node_names
]
if {obj.name for obj in validated_reimport_meshes} != expected_mesh_node_names:
    raise SystemExit("Blender GLB round-trip did not restore every exported mesh node.")
skinned_reimport_meshes = [
    obj for obj in validated_reimport_meshes
    if any(modifier.type == "ARMATURE" for modifier in obj.modifiers)
]
if len(skinned_reimport_meshes) != len(expected_mesh_node_names):
    raise SystemExit("One or more exported Olivia mesh nodes lost their armature modifier.")
reimport_vertex_count = sum(len(obj.data.vertices) for obj in validated_reimport_meshes)
reimport_face_count = sum(len(obj.data.polygons) for obj in validated_reimport_meshes)
for obj in validated_reimport_meshes:
    if weighted_vertex_count(obj) != len(obj.data.vertices):
        raise SystemExit(f"Exported GLB mesh has unweighted vertices: {obj.name}")

reimport_points = [o.matrix_world @ Vector(corner) for o in validated_reimport_meshes for corner in o.bound_box]
reimport_height = max(p.z for p in reimport_points) - min(p.z for p in reimport_points)
if not 1.55 <= reimport_height <= 2.0:
    raise SystemExit(f"Unexpected scaled Olivia height after GLB round-trip: {reimport_height}")

report = {
    "rigging_method": "manual_segment_distance_weights_v1",
    "source_model": glb_name,
    "source_height_m": round(height, 3),
    "export_scale_factor": round(scale_factor, 6),
    "target_height_m": round(reimport_height, 3),
    "source_meshes": source_mesh_count,
    "reimport_meshes": len(reimport_meshes),
    "reimport_skinned_meshes": len(skinned_reimport_meshes),
    "reimport_validated_meshes": len(validated_reimport_meshes),
    "reimport_helper_meshes_ignored": unexpected_reimport_meshes,
    "reimport_vertices": reimport_vertex_count,
    "reimport_faces": reimport_face_count,
    "source_vertices": source_vertex_count,
    "source_faces": source_face_count,
    "source_texture_images": len(used_source_images),
    "glb_images": exported_images,
    "glb_meshes": exported_meshes,
    "glb_mesh_nodes": len(mesh_nodes_info),
    "glb_skinned_mesh_nodes": sum(1 for node in mesh_nodes_info if node["skin"] is not None),
    "glb_skins": exported_skins,
    "armature_bones": len(reimport_armature.data.bones),
    "bone_weight_counts": bone_weight_counts,
    "pose_test_max_deformation_m": round(deformation, 6),
    "glb_size_bytes": out_glb.stat().st_size,
    "glb_sha256": hashlib.sha256(out_glb.read_bytes()).hexdigest(),
}

out_glb.replace(OUT_GLB)
REPORT_FILE.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("OLIVIA_RIG_TEST_OK")
print(json.dumps(report, indent=2))
