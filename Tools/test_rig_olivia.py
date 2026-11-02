from __future__ import annotations

import io
import json
import tempfile
import zipfile
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "SourceArchives/olivia-free-fire.zip"
tmp = Path(tempfile.mkdtemp(prefix="ff3d_olivia_rig_test_"))
with zipfile.ZipFile(ARCHIVE) as zf:
    glb_name = next(n for n in zf.namelist() if n.lower().endswith(".glb"))
    source_glb = tmp / "olivia.glb"
    source_glb.write_bytes(zf.read(glb_name))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source_glb))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if len(meshes) != 7:
    raise SystemExit(f"Unexpected Olivia mesh count: {len(meshes)}")

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

# The source is an A-pose: shoulder line high, arms angle down and outward.
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
    make_bone(f"{label}Shoulder",
              (center_x, center_y, z_chest),
              (center_x + side * shoulder_x, center_y, z_chest),
              "Chest")
    make_bone(f"{label}UpperArm",
              (center_x + side * shoulder_x, center_y, z_chest),
              (center_x + side * elbow_x, center_y, z_elbow),
              f"{label}Shoulder")
    make_bone(f"{label}LowerArm",
              (center_x + side * elbow_x, center_y, z_elbow),
              (center_x + side * wrist_x, center_y, z_wrist),
              f"{label}UpperArm")
    make_bone(f"{label}Hand",
              (center_x + side * wrist_x, center_y, z_wrist),
              (center_x + side * hand_x, center_y, z_hand),
              f"{label}LowerArm")

    make_bone(f"{label}UpperLeg",
              (center_x + side * hip_x, center_y, z_hips),
              (center_x + side * knee_x, center_y, z_knee),
              "Hips")
    make_bone(f"{label}LowerLeg",
              (center_x + side * knee_x, center_y, z_knee),
              (center_x + side * ankle_x, center_y, z_ankle),
              f"{label}UpperLeg")
    make_bone(f"{label}Foot",
              (center_x + side * ankle_x, center_y, z_ankle),
              (center_x + side * ankle_x, center_y - 0.28, z0 + 0.025),
              f"{label}LowerLeg")
    make_bone(f"{label}Toes",
              (center_x + side * ankle_x, center_y - 0.28, z0 + 0.025),
              (center_x + side * ankle_x, center_y - 0.42, z0 + 0.025),
              f"{label}Foot")

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
        distances = sorted(
            ((segment_distance(world, a, b), name) for name, (a, b) in bone_segments.items()),
            key=lambda item: item[0]
        )[:4]
        raw = [1.0 / ((distance + 0.12) ** 2) for distance, _ in distances]
        total = sum(raw)
        for (_, name), weight in zip(distances, raw):
            groups[name].add([vertex.index], weight / total, "REPLACE")

def weighted_vertex_count(obj):
    return sum(1 for v in obj.data.vertices if any(g.weight > 0.0001 for g in v.groups))

auto_weighted = 0
fallback_weighted = 0
for obj in meshes:
    world = obj.matrix_world.copy()
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception as exc:
        print(f"AUTO_WEIGHT_FAILED {obj.name}: {exc}", flush=True)
    if obj.parent != armature:
        obj.parent = armature
        obj.matrix_world = world
    modifiers = [m for m in obj.modifiers if m.type == "ARMATURE" and m.object == armature]
    if not modifiers:
        modifier = obj.modifiers.new("Olivia_Armature", "ARMATURE")
        modifier.object = armature
    if weighted_vertex_count(obj) == len(obj.data.vertices):
        auto_weighted += 1
    else:
        manual_weights(obj)
        fallback_weighted += 1
    if weighted_vertex_count(obj) != len(obj.data.vertices):
        raise SystemExit(f"Unweighted vertices remain in {obj.name}")

# Test a small pose change and verify that the skinned mesh actually deforms.
bpy.context.view_layer.update()
test_mesh = max(meshes, key=lambda obj: len(obj.data.vertices))
depsgraph = bpy.context.evaluated_depsgraph_get()
evaluated = test_mesh.evaluated_get(depsgraph)
evaluated_mesh = evaluated.to_mesh()
before = [evaluated.matrix_world @ v.co for v in evaluated_mesh.vertices]
evaluated.to_mesh_clear()
pose_bone = armature.pose.bones.get("LeftUpperArm")
if pose_bone is None:
    raise SystemExit("LeftUpperArm bone missing after rig creation.")
pose_bone.rotation_mode = "XYZ"
pose_bone.rotation_euler[0] = 0.12
bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()
evaluated = test_mesh.evaluated_get(depsgraph)
evaluated_mesh = evaluated.to_mesh()
after = [evaluated.matrix_world @ v.co for v in evaluated_mesh.vertices]
evaluated.to_mesh_clear()
deformation = max(((a-b).length for a, b in zip(before, after)), default=0.0)
pose_bone.rotation_euler = (0.0, 0.0, 0.0)
bpy.context.view_layer.update()
if deformation < 0.0001:
    raise SystemExit("Rig pose test produced no measurable mesh deformation.")

# Export one scaled FBX, with the source GLB's embedded textures.
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

# Re-import the FBX and validate skeleton, skinning, scale and mesh count.
bpy.ops.wm.read_factory_settings(use_empty=True)
if hasattr(bpy.ops.wm, "fbx_import"):
    bpy.ops.wm.fbx_import(filepath=str(out_fbx), use_anim=False)
else:
    bpy.ops.import_scene.fbx(filepath=str(out_fbx), use_image_search=True, use_anim=False)
reimport_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
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
    "fallback_weighted_meshes": fallback_weighted,
    "pose_test_max_deformation_m": round(deformation, 6),
    "fbx_size_bytes": out_fbx.stat().st_size,
}
print("OLIVIA_RIG_TEST_OK")
print(json.dumps(report, indent=2))
