from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT
errors: list[str] = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

manifest_path = ROOT / "Packages" / "manifest.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    deps = manifest.get("dependencies", {})
    for package in (
        "com.unity.render-pipelines.universal",
        "com.unity.inputsystem",
        "com.unity.ugui",
        "com.unity.cloud.gltfast",
    ):
        require(package in deps, f"Missing required package: {package}")
except Exception as exc:
    errors.append(f"Invalid Packages/manifest.json: {exc}")

version_path = ROOT / "ProjectSettings" / "ProjectVersion.txt"
version_text = version_path.read_text(encoding="utf-8") if version_path.exists() else ""
require(bool(re.search(r"^m_EditorVersion: 6000\.", version_text, re.MULTILINE)),
        "Unity editor version is not pinned to Unity 6.0.")

required_files = [
    "Assets/Scripts/Player/TPSPlayerMotor.cs",
    "Assets/Scripts/Player/TPSCharacterSetup.cs",
    "Assets/Scripts/Camera/TPSCameraRig.cs",
    "Assets/Scripts/Input/MobileInputBridge.cs",
    "Assets/Scripts/Input/VirtualJoystick.cs",
    "Assets/Scripts/Input/TouchLookArea.cs",
    "Assets/Scripts/Input/MobileActionButton.cs",
    "Assets/Scripts/Match/MatchConfiguration.cs",
    "Assets/Scripts/Match/MatchRuntimeSettings.cs",
    "Assets/Scripts/World/ClocktowerCollisionAuthoring.cs",
    "Assets/Editor/OliviaAvatarAssetBuilder.cs",
    "Assets/Editor/QuaterniusAnimationImporter.cs",
    "Tools/inspect_quaternius_fbx.py",
    "Assets/Editor/InitialMatchSceneBuilder.cs",
    "Assets/Documentation/CONTENT_SELECTION.md",
]
for relative in required_files:
    require((ROOT / relative).is_file(), f"Missing required Unity file: {relative}")

# Catch mismatches between runtime Animator calls and the parameters created
# by the editor-side controller builder before the project reaches Unity.
motor_source = (ROOT / "Assets/Scripts/Player/TPSPlayerMotor.cs").read_text(encoding="utf-8")
animator_builder = (ROOT / "Assets/Editor/QuaterniusAnimationImporter.cs").read_text(encoding="utf-8")
runtime_parameters = {
    line.split('"')[1]
    for line in motor_source.splitlines()
    if "animator.Set" in line and '"' in line
}
builder_parameters = {
    line.split('"')[1]
    for line in animator_builder.splitlines()
    if "controller.AddParameter" in line and '"' in line
}
require(runtime_parameters <= builder_parameters,
        "TPSPlayerMotor references Animator parameters not created by the controller builder: "
        + ", ".join(sorted(runtime_parameters - builder_parameters)))
require({"Speed", "Crouching", "Grounded"} <= builder_parameters,
        "Olivia Animator Controller is missing a required locomotion parameter.")

legacy_suffixes = {".gd", ".tscn", ".godot", ".import"}
legacy_files = [p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*")
                if p.is_file() and p.suffix.lower() in legacy_suffixes]
require(not legacy_files, "Godot files found in the Unity project tree: " + ", ".join(legacy_files))

content_doc = (ROOT / "Assets/Documentation/CONTENT_SELECTION.md").read_text(encoding="utf-8")
require(content_doc.count("Olivia, one rigged humanoid") == 1,
        "Content manifest must select exactly one player character.")
require(content_doc.count("Clocktower") >= 1,
        "Content manifest must identify the one approved match map.")

expected_archives = [
    REPO / "SourceArchives" / "olivia-free-fire.zip",
    REPO / "SourceArchives" / "free-fire-clocktower-3d-model-by-rs-ratul.zip",
    REPO / "SourceArchives" / "quaternius-universal-animation-library-standard.zip",
]
for archive in expected_archives:
    require(archive.is_file(), f"Approved source archive missing: {archive.name}")

for relative in ("Assets/Game/Characters/Olivia", "Assets/Game/Maps/Clocktower"):
    folder = ROOT / relative
    model_files = [p for p in folder.rglob("*") if p.is_file()
                   and p.suffix.lower() in {".glb", ".gltf", ".fbx", ".obj", ".blend"}]
    require(len(model_files) <= 1,
            f"More than one model in canonical asset slot {relative}: "
            + ", ".join(p.name for p in model_files))

map_model = ROOT / "Assets/Game/Maps/Clocktower/Clocktower.glb"
map_report = ROOT / "Assets/Game/Maps/Clocktower/AssetImportReport.json"
if map_model.exists():
    require(map_report.is_file(), "Clocktower GLB exists without its import report.")
    if map_report.is_file():
        try:
            report = json.loads(map_report.read_text(encoding="utf-8"))
            require(report.get("texture_references_missing") == 0,
                    "Clocktower import report records missing texture references.")
            require(report.get("glb_images") == report.get("used_source_texture_images"),
                    "Clocktower GLB does not contain every used source texture image.")
        except Exception as exc:
            errors.append(f"Invalid Clocktower AssetImportReport.json: {exc}")

olivia_model = ROOT / "Assets/Game/Characters/Olivia/Olivia.glb"
olivia_report = ROOT / "Assets/Game/Characters/Olivia/OliviaRigReport.json"
if olivia_model.exists():
    require(olivia_report.is_file(), "Olivia GLB exists without its rig report.")
    if olivia_report.is_file():
        try:
            report = json.loads(olivia_report.read_text(encoding="utf-8"))
            require(1.55 <= report.get("target_height_m", 0) <= 2.0,
                    "Olivia rig report has an invalid gameplay height.")
            require(report.get("pose_test_max_deformation_m", 0) > 0.0001,
                    "Olivia rig report does not prove mesh deformation.")
            require(report.get("source_meshes") == report.get("glb_meshes") == 7,
                    "Olivia GLB must preserve the seven source meshes.")
            require(report.get("source_meshes", 0) <= report.get("reimport_meshes", 0) <= report.get("source_meshes", 0) + 2,
                    "Olivia GLB round-trip produced an unexpected number of mesh primitives.")
            require(report.get("reimport_validated_meshes") == report.get("glb_mesh_nodes"),
                    "Olivia GLB round-trip did not validate every exported mesh node.")
            require(report.get("reimport_skinned_meshes") == report.get("glb_mesh_nodes"),
                    "Olivia GLB round-trip lost skinning on an exported mesh node.")
            require(report.get("armature_bones", 0) >= 15,
                    "Olivia rig report contains too few humanoid bones.")
            require(report.get("glb_skins") == 1,
                    "Olivia GLB must contain exactly one skin.")
            require(report.get("glb_mesh_nodes") == report.get("glb_skinned_mesh_nodes"),
                    "One or more Olivia mesh nodes are not bound to the humanoid skin.")
            require(report.get("glb_meshes") == 7,
                    "Olivia GLB must preserve the seven source meshes.")
            require(report.get("glb_images") == report.get("source_texture_images"),
                    "Olivia GLB does not contain all source texture images.")
        except Exception as exc:
            errors.append(f"Invalid OliviaRigReport.json: {exc}")

animation_model = ROOT / "Assets/Game/Animations/Quaternius/UAL1_Standard.fbx"
animation_report = ROOT / "Assets/Game/Animations/Quaternius/AnimationImportReport.json"
animation_folder = ROOT / "Assets/Game/Animations/Quaternius"
animation_models = [p for p in animation_folder.rglob("*") if p.is_file()
                    and p.suffix.lower() in {".glb", ".gltf", ".fbx", ".obj", ".blend"}]
require(animation_models == [animation_model],
        "Quaternius must have exactly one selected Unity FBX animation source.")
require(animation_report.is_file(), "Quaternius animation FBX is missing its import report.")
if animation_report.is_file():
    try:
        report = json.loads(animation_report.read_text(encoding="utf-8"))
        require(report.get("selected_variant") == "Unity/UAL1_Standard.fbx",
                "Quaternius animation source must be the Unity FBX export.")
        require(report.get("root_motion") is False,
                "Quaternius animation source must use the in-place, no-root-motion variant.")
        require(report.get("animation_count", 0) >= 20,
                "Quaternius animation manifest contains too few clips.")
        require(report.get("reference_joint_count", 0) >= 20,
                "Quaternius reference skeleton contains too few joints.")
        require(report.get("license") == "CC0 1.0 Universal",
                "Quaternius animation license metadata is missing or unexpected.")
        require(len(report.get("fbx_sha256", "")) == 64,
                "Quaternius FBX SHA-256 is missing.")
    except Exception as exc:
        errors.append(f"Invalid Quaternius AnimationImportReport.json: {exc}")

fbx_inspection = ROOT / "Assets/Game/Animations/Quaternius/FBXInspectionReport.json"
require(fbx_inspection.is_file(), "Quaternius FBX is missing its Blender inspection report.")
if fbx_inspection.is_file():
    try:
        report = json.loads(fbx_inspection.read_text(encoding="utf-8"))
        require(report.get("armature_count") == 1,
                "Quaternius FBX must contain exactly one animation armature.")
        require(report.get("bone_count", 0) >= 20,
                "Quaternius FBX inspection found too few bones.")
        require(report.get("animation_action_count") == report.get("animation_count", 43),
                "Quaternius FBX inspection did not confirm the expected animation count.")
        require(report.get("animation_action_count", 0) >= 20,
                "Quaternius FBX contains too few imported animation actions.")
        require(not report.get("missing_required_actions"),
                "Quaternius FBX is missing required locomotion actions.")
        require(len(report.get("fbx_sha256", "")) == 64,
                "Quaternius FBX inspection hash is missing.")
    except Exception as exc:
        errors.append(f"Invalid Quaternius FBXInspectionReport.json: {exc}")

if errors:
    print("UNITY_STRUCTURE_CHECK_FAILED")
    for error in errors:
        print(" - " + error)
    sys.exit(1)

print("UNITY_STRUCTURE_CHECK_OK")
print("Unity project is isolated from Godot files.")
print("One canonical player slot: Olivia.")
print("One canonical map slot: Clocktower.")
print("Three approved source archives and the canonical animation source are present.")
