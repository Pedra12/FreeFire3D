from __future__ import annotations

import hashlib
import glob
import json
import sys
from pathlib import Path

for package_path in glob.glob("/usr/lib/python*/dist-packages") + glob.glob("/usr/local/lib/python*/site-packages"):
    if package_path not in sys.path:
        sys.path.append(package_path)
import numpy  # Required by Blender 5 FBX importer
import bpy

ROOT = Path(__file__).resolve().parents[1]
FBX = ROOT / "Assets/Game/Animations/Quaternius/UAL1_Standard.fbx"
SOURCE_REPORT = ROOT / "Assets/Game/Animations/Quaternius/AnimationImportReport.json"
OUT = ROOT / "Assets/Game/Animations/Quaternius/FBXInspectionReport.json"

if not FBX.is_file():
    raise SystemExit(f"Quaternius Unity FBX is missing: {FBX}")

source_report = json.loads(SOURCE_REPORT.read_text(encoding="utf-8").strip())
actual_hash = hashlib.sha256(FBX.read_bytes()).hexdigest()
if actual_hash != source_report.get("fbx_sha256"):
    raise SystemExit("Quaternius FBX hash does not match the downloaded source manifest.")

bpy.ops.wm.read_factory_settings(use_empty=True)
fbx_importer = bpy.ops.import_scene.fbx
fbx_import_properties = {
    prop.identifier for prop in fbx_importer.get_rna_type().properties
}
fbx_import_args = {
    "filepath": str(FBX),
    "use_anim": True,
    "use_custom_normals": True,
}
fbx_import_args = {
    key: value for key, value in fbx_import_args.items()
    if key in fbx_import_properties
}
print("FBX_IMPORT_PROPERTIES=" + ",".join(sorted(fbx_import_properties)), flush=True)
fbx_importer(**fbx_import_args)

armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
actions = [action for action in bpy.data.actions if action.frame_range[1] > action.frame_range[0]]

if len(armatures) != 1:
    raise SystemExit(f"Expected one Quaternius animation armature, found {len(armatures)}")
if len(armatures[0].data.bones) < 20:
    raise SystemExit(f"Quaternius animation rig has too few bones: {len(armatures[0].data.bones)}")
if len(actions) < 20:
    raise SystemExit(f"Quaternius FBX imported too few animation actions: {len(actions)}")

action_names = sorted(action.name for action in actions)
required_groups = {
    "Idle_Loop": ("Idle_Loop",),
    "Walk_Loop": ("Walk_Loop",),
    "Jog_Fwd_Loop": ("Jog_Fwd_Loop",),
    "Sprint_Loop": ("Sprint_Loop",),
    "Crouch_Idle_Loop": ("Crouch_Idle_Loop",),
    "Crouch_Fwd_Loop": ("Crouch_Fwd_Loop",),
    "Jump_Start": ("Jump_Start",),
    "Jump_Loop": ("Jump_Loop",),
    "Jump_Land": ("Jump_Land",),
}
missing = [
    key for key, variants in required_groups.items()
    if not any(any(name.endswith(variant) for variant in variants) for name in action_names)
]
if missing:
    raise SystemExit("Quaternius FBX is missing core locomotion actions: " + ", ".join(missing))

report = {
    "source": "Quaternius Universal Animation Library [Standard]",
    "fbx_sha256": actual_hash,
    "armature_count": len(armatures),
    "bone_count": len(armatures[0].data.bones),
    "donor_mesh_count": len(meshes),
    "animation_action_count": len(actions),
    "animation_action_names": action_names,
    "required_locomotion_actions": sorted(required_groups),
    "missing_required_actions": missing,
}
OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("QUATERNIUS_FBX_INSPECTION_OK")
print(json.dumps(report, indent=2))
