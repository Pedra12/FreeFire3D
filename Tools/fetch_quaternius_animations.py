from __future__ import annotations

import hashlib
import json
import shutil
import struct
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "SourceArchives/quaternius-universal-animation-library-standard.zip"
ASSET_DIR = ROOT / "Assets/Game/Animations/Quaternius"
ASSET = ASSET_DIR / "UAL1_Standard.fbx"
REPORT = ASSET_DIR / "AnimationImportReport.json"

DOWNLOAD_ENDPOINT = (
    "https://quaternius.itch.io/universal-animation-library/file/17958403"
    "?source=game_download&as_props=1"
)
EXPECTED_SHA256 = "cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724"

def request(url: str, data: bytes | None = None, headers: dict | None = None) -> bytes:
    req = urllib.request.Request(
        url,
        data=data,
        headers=headers or {},
        method="POST" if data is not None else "GET",
    )
    with urllib.request.urlopen(req, timeout=120) as response:
        return response.read()

payload = json.loads(request(
    DOWNLOAD_ENDPOINT,
    data=b"",
    headers={
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": "FreeFire3D-AssetPipeline/1.0",
    },
).decode("utf-8"))
download_url = payload.get("url")
if not isinstance(download_url, str) or not download_url.startswith("https://"):
    raise SystemExit("itch.io did not return a valid signed download URL.")

archive_bytes = request(download_url, headers={"User-Agent": "FreeFire3D-AssetPipeline/1.0"})
actual_sha256 = hashlib.sha256(archive_bytes).hexdigest()
if actual_sha256 != EXPECTED_SHA256:
    raise SystemExit(
        "Quaternius archive checksum mismatch: "
        f"expected {EXPECTED_SHA256}, got {actual_sha256}"
    )

ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
ASSET_DIR.mkdir(parents=True, exist_ok=True)
tmp_archive = ARCHIVE.with_suffix(".zip.tmp")
tmp_archive.write_bytes(archive_bytes)

with zipfile.ZipFile(tmp_archive) as zf:
    bad_member = zf.testzip()
    if bad_member:
        raise SystemExit(f"Quaternius archive failed ZIP integrity at {bad_member}")
    fbx_candidates = [
        name for name in zf.namelist()
        if Path(name).name == "UAL1_Standard.fbx"
        and "Unity" in Path(name).parts
    ]
    glb_candidates = [
        name for name in zf.namelist()
        if Path(name).name == "UAL1_Standard.glb"
        and "Unreal-Godot" in Path(name).parts
    ]
    if len(fbx_candidates) != 1 or len(glb_candidates) != 1:
        raise SystemExit(
            "Expected one Unity FBX and one Unreal-Godot GLB standard export; "
            f"found FBX={fbx_candidates}, GLB={glb_candidates}"
        )
    fbx_bytes = zf.read(fbx_candidates[0])
    glb_bytes = zf.read(glb_candidates[0])

if len(fbx_bytes) < 1024 or not fbx_bytes.startswith(b"Kaydara FBX Binary"):
    raise SystemExit("The selected Quaternius Unity asset is not a valid binary FBX.")
if glb_bytes[:4] != b"glTF":
    raise SystemExit("The selected Quaternius reference asset is not a GLB file.")
version, declared_length = struct.unpack_from("<II", glb_bytes, 4)
if version != 2 or declared_length != len(glb_bytes):
    raise SystemExit("Quaternius GLB header/version/length validation failed.")

offset = 12
gltf = None
while offset + 8 <= len(glb_bytes):
    chunk_size, chunk_type = struct.unpack_from("<II", glb_bytes, offset)
    offset += 8
    chunk = glb_bytes[offset:offset + chunk_size]
    offset += chunk_size
    if chunk_type == 0x4E4F534A:
        gltf = json.loads(chunk.decode("utf-8").rstrip("\\x00 "))
        break

if gltf is None:
    raise SystemExit("Quaternius reference GLB is missing its JSON chunk.")

animations = gltf.get("animations", [])
skins = gltf.get("skins", [])
nodes = gltf.get("nodes", [])
if len(animations) < 20:
    raise SystemExit(f"Unexpectedly few animation clips: {len(animations)}")
if len(skins) != 1:
    raise SystemExit(f"Expected one shared humanoid skin, found {len(skins)}")
if len(nodes) < 20:
    raise SystemExit(f"Unexpectedly small animation skeleton: {len(nodes)}")

bone_names = sorted({
    nodes[index].get("name", f"node_{index}")
    for index in skins[0].get("joints", [])
    if 0 <= index < len(nodes)
})
if len(bone_names) < 20:
    raise SystemExit(f"Humanoid skeleton contains too few joints: {len(bone_names)}")

tmp_asset = ASSET.with_suffix(".fbx.tmp")
tmp_asset.write_bytes(fbx_bytes)
tmp_archive.replace(ARCHIVE)
tmp_asset.replace(ASSET)
(ASSET_DIR / "UAL1_Standard.glb").unlink(missing_ok=True)

report = {
    "source": "Quaternius Universal Animation Library [Standard]",
    "source_url": "https://quaternius.itch.io/universal-animation-library",
    "license": "CC0 1.0 Universal",
    "selected_variant": "Unity/UAL1_Standard.fbx",
    "reference_manifest_variant": "Unreal-Godot/UAL1_Standard.glb",
    "root_motion": False,
    "archive_sha256": actual_sha256,
    "archive_size_bytes": len(archive_bytes),
    "fbx_sha256": hashlib.sha256(fbx_bytes).hexdigest(),
    "fbx_size_bytes": len(fbx_bytes),
    "animation_count": len(animations),
    "animation_names": [animation.get("name", f"Animation_{i}") for i, animation in enumerate(animations)],
    "reference_skin_count": len(skins),
    "reference_node_count": len(nodes),
    "reference_joint_count": len(bone_names),
    "reference_joint_names": bone_names,
}
REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("QUATERNIUS_ANIMATION_IMPORT_OK")
print(json.dumps(report, indent=2))
