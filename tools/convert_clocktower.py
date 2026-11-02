import bpy
import json
import math
import os
from pathlib import Path
from mathutils import Matrix, Vector

source = Path(os.environ["CLOCKTOWER_BLEND"]).resolve()
source_root = Path(os.environ["CLOCKTOWER_ROOT"]).resolve()
output = Path(os.environ["CLOCKTOWER_GLB"]).resolve()
output.parent.mkdir(parents=True, exist_ok=True)

if not source.is_file():
    raise SystemExit(f"Clocktower blend not found: {source}")

bpy.ops.wm.open_mainfile(filepath=str(source))
scene = bpy.context.scene

# The source Clocktower scene is already Y-up. Keep its original axes; a
# manual 90-degree rotation would turn the map depth into its vertical axis.

# Repair the absolute Windows paths stored by the original Blender project.
relinked = 0
missing_images = []
for image in bpy.data.images:
    if image.source != "FILE" or not image.filepath:
        continue
    raw = bpy.path.abspath(image.filepath).replace(chr(92), "/")
    image_name = raw.split("/")[-1]
    original = Path(raw)
    if not original.is_file():
        matches = [candidate for candidate in source_root.rglob(image_name) if candidate.is_file()]
        if matches:
            image.filepath = str(matches[0])
            image.reload()
            relinked += 1
        else:
            missing_images.append(image_name)

mesh_objects = [obj for obj in scene.objects if obj.type == "MESH"]
if len(mesh_objects) < 30:
    raise SystemExit(f"Clocktower source has too few mesh objects: {len(mesh_objects)}")

base = next((obj for obj in mesh_objects if obj.name.startswith("Base_02_LOD0_0")), None)
if base is None:
    raise SystemExit("Clocktower base mesh Base_02_LOD0_0 was not found")

def world_corners(obj):
    return [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]

all_points = [point for obj in mesh_objects for point in world_corners(obj)]
minimum = Vector([min(point[i] for point in all_points) for i in range(3)])
maximum = Vector([max(point[i] for point in all_points) for i in range(3)])
base_points = world_corners(base)
base_min = Vector([min(point[i] for point in base_points) for i in range(3)])
base_max = Vector([max(point[i] for point in base_points) for i in range(3)])
base_center = (base_min + base_max) * 0.5

# Center the 87 x 113 metre block and use the center of the terrain base as
# the provisional ground reference. Godot validation will verify the floor.
horizontal_center_x = (minimum.x + maximum.x) * 0.5
horizontal_center_y = (minimum.y + maximum.y) * 0.5
shift = Vector((-horizontal_center_x, -horizontal_center_y, -base_center.z))
for obj in list(scene.objects):
    obj.matrix_world.translation += shift

# Recompute normalized bounds after the transform.
all_points = [point for obj in mesh_objects for point in world_corners(obj)]
minimum = Vector([min(point[i] for point in all_points) for i in range(3)])
maximum = Vector([max(point[i] for point in all_points) for i in range(3)])

for obj in bpy.context.selected_objects:
    obj.select_set(False)
for obj in mesh_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = base

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

report = {
    "source": str(source),
    "output": str(output),
    "output_bytes": output.stat().st_size,
    "mesh_count": len(mesh_objects),
    "vertices": sum(len(obj.data.vertices) for obj in mesh_objects),
    "triangles": sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons) for obj in mesh_objects),
    "materials": len({material.name for obj in mesh_objects for material in obj.data.materials if material}),
    "images": [{"name": image.name, "size": list(image.size), "path": image.filepath} for image in bpy.data.images if image.source == "FILE"],
    "relinked_images": relinked,
    "missing_images": missing_images,
    "normalized_bounds": {"min": list(minimum), "max": list(maximum), "dimensions": list(maximum - minimum)},
    "base_bounds_before_centering": {"min": list(base_min), "max": list(base_max), "center": list(base_center)},
    "ground_reference_before_centering": base_center.z,
    "objects": [{"name": obj.name, "vertices": len(obj.data.vertices), "triangles": sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons), "bounds_min": list(Vector([min(point[i] for point in world_corners(obj)) for i in range(3)])), "bounds_max": list(Vector([max(point[i] for point in world_corners(obj)) for i in range(3)])), "center": list((Vector([min(point[i] for point in world_corners(obj)) for i in range(3)]) + Vector([max(point[i] for point in world_corners(obj)) for i in range(3)])) * 0.5)} for obj in mesh_objects]
}
Path(str(output) + ".json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("CLOCKTOWER_GLB_OK", json.dumps({key: report[key] for key in ["output_bytes", "mesh_count", "vertices", "triangles", "materials", "relinked_images", "missing_images", "normalized_bounds", "ground_reference_before_centering"]}))
