import bpy
import sys
import os
import json
from pathlib import Path
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(args) != 3:
    raise SystemExit("usage: rig_olivia.py -- rigged_reference.glb olivia_source.glb output.glb")
rig_path, olivia_path, output_path = map(os.path.abspath, args)

bpy.ops.wm.read_factory_settings(use_empty=True)

def import_gltf(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [obj for obj in bpy.context.scene.objects if obj not in before]

rig_objects = import_gltf(rig_path)
armatures = [obj for obj in rig_objects if obj.type == "ARMATURE"]
if len(armatures) != 1:
    raise RuntimeError(f"Expected one rig armature, found {len(armatures)}")
armature = armatures[0]
if len(armature.data.bones) < 40:
    raise RuntimeError(f"Reference skeleton too small: {len(armature.data.bones)} bones")

bone_points = []
for bone in armature.data.bones:
    bone_points.append(armature.matrix_world @ bone.head_local)
    bone_points.append(armature.matrix_world @ bone.tail_local)
arm_min = Vector([min(p[i] for p in bone_points) for i in range(3)])
arm_max = Vector([max(p[i] for p in bone_points) for i in range(3)])
arm_height = arm_max.z - arm_min.z
if arm_height < 0.5:
    raise RuntimeError(f"Invalid reference skeleton height: {arm_height}")

# Keep the original 65-bone armature and all 86 animation actions.
for obj in rig_objects:
    if obj != armature and obj.type == "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)

olivia_objects = import_gltf(olivia_path)
olivia_meshes = [obj for obj in olivia_objects if obj.type == "MESH"]
if len(olivia_meshes) != 7:
    print("OLIVIA_SOURCE_MESH_COUNT", len(olivia_meshes))
if not olivia_meshes:
    raise RuntimeError("Olivia GLB contains no mesh objects")

points = []
for obj in olivia_meshes:
    points.extend([obj.matrix_world @ Vector(corner) for corner in obj.bound_box])
olivia_min = Vector([min(p[i] for p in points) for i in range(3)])
olivia_max = Vector([max(p[i] for p in points) for i in range(3)])
olivia_height = olivia_max.z - olivia_min.z
if olivia_height < 1.0:
    raise RuntimeError(f"Invalid Olivia source height: {olivia_height}")

scale_factor = arm_height / olivia_height
olivia_center = (olivia_min + olivia_max) * 0.5
arm_center = (arm_min + arm_max) * 0.5
scale_matrix = Matrix.Scale(scale_factor, 4)
translation = Matrix.Translation(Vector((
    arm_center.x - olivia_center.x * scale_factor,
    arm_center.y - olivia_center.y * scale_factor,
    arm_min.z - olivia_min.z * scale_factor
)))
alignment = translation @ scale_matrix

# Preserve world-space positions, scale the source model to the rig, and
# align its feet and center to the reference skeleton.
for obj in olivia_meshes:
    world = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = alignment @ world
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)

def deselect_all():
    for obj in bpy.context.selected_objects:
        obj.select_set(False)

def segment_distance(point, start, end):
    direction = end - start
    length_sq = direction.length_squared
    if length_sq < 1e-10:
        return (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(direction) / length_sq))
    return (point - (start + direction * t)).length

def fallback_weights(mesh_obj):
    # Smooth nearest-segment skinning fallback. Four influences with normalized
    # inverse-distance weights avoid the two-bone hard seams that caused limbs
    # to collapse when Blender automatic weights failed.
    deform_bones = [b for b in armature.data.bones if b.use_deform]
    if not deform_bones:
        raise RuntimeError("Reference skeleton has no deform bones")
    bone_groups = {b.name: mesh_obj.vertex_groups.new(name=b.name) for b in deform_bones}
    arm_inverse = armature.matrix_world.inverted()
    segments = [(b, b.head_local.copy(), b.tail_local.copy()) for b in deform_bones]
    for vertex in mesh_obj.data.vertices:
        point = arm_inverse @ (mesh_obj.matrix_world @ vertex.co)
        nearest = sorted(((segment_distance(point, a, z), bone) for bone, a, z in segments),
                         key=lambda pair: pair[0])[:4]
        # Soft falloff; normalize all selected influences to exactly one.
        raw = [1.0 / max(distance, 0.04) ** 3 for distance, _bone in nearest]
        total = sum(raw)
        for (distance, bone), weight in zip(nearest, raw):
            normalized = weight / total
            if normalized > 0.001:
                bone_groups[bone.name].add([vertex.index], normalized, "REPLACE")
    # Ensure every vertex has weights and the mesh is actually deformed by this rig.
    for vertex in mesh_obj.data.vertices:
        if not any(group.weight(vertex.index) > 0.0 for group in mesh_obj.vertex_groups):
            raise RuntimeError(f"Unweighted vertex {vertex.index} in {mesh_obj.name}")

bound_meshes = 0
fallback_meshes = 0
for mesh_obj in olivia_meshes:
    deselect_all()
    mesh_obj.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        if not any(mod.type == "ARMATURE" for mod in mesh_obj.modifiers) or not mesh_obj.vertex_groups:
            raise RuntimeError("Automatic weights did not create a usable armature modifier")
    except Exception as exc:
        print("OLIVIA_AUTO_WEIGHT_FALLBACK", mesh_obj.name, repr(exc))
        for modifier in list(mesh_obj.modifiers):
            if modifier.type == "ARMATURE":
                mesh_obj.modifiers.remove(modifier)
        mesh_obj.vertex_groups.clear()
        mesh_obj.parent = armature
        mesh_obj.matrix_parent_inverse = armature.matrix_world.inverted()
        modifier = mesh_obj.modifiers.new("Olivia_Armature", "ARMATURE")
        modifier.object = armature
        fallback_weights(mesh_obj)
        fallback_meshes += 1
    bound_meshes += 1

# Detach the armature from any GLB container while preserving its world transform.
armature_world = armature.matrix_world.copy()
armature.parent = None
armature.matrix_world = armature_world

# Keep only the armature and Olivia's skinned meshes.
for obj in list(bpy.context.scene.objects):
    if obj != armature and obj not in olivia_meshes:
        bpy.data.objects.remove(obj, do_unlink=True)

# Select the rig and skinned meshes for export.
deselect_all()
armature.select_set(True)
for obj in olivia_meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = armature

Path(os.path.dirname(output_path)).mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_texcoords=True,
    export_normals=True,
    export_tangents=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_skins=True,
    export_animations=True,
    export_nla_strips=True,
    export_force_sampling=True,
    export_all_influences=True,
    export_cameras=False,
    export_lights=False
)

report = {
    "output": output_path,
    "output_bytes": os.path.getsize(output_path),
    "reference_bones": len(armature.data.bones),
    "reference_height": arm_height,
    "olivia_source_height": olivia_height,
    "scale_factor": scale_factor,
    "mesh_count": len(olivia_meshes),
    "bound_meshes": bound_meshes,
    "fallback_meshes": fallback_meshes,
    "vertex_count": sum(len(obj.data.vertices) for obj in olivia_meshes),
    "actions": len(bpy.data.actions),
    "action_names": [action.name for action in bpy.data.actions],
    "nla_tracks": len(armature.animation_data.nla_tracks) if armature.animation_data else 0,
    "materials": len(bpy.data.materials)
}
Path(output_path + ".json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("OLIVIA_RIG_OK", json.dumps(report))
