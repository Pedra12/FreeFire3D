from __future__ import annotations

import hashlib
import io
import json
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVES = [
    ROOT / "SourceArchives" / "olivia-free-fire.zip",
    ROOT / "SourceArchives" / "free-fire-clocktower-3d-model-by-rs-ratul.zip",
]
MODEL_EXT = {".fbx", ".glb", ".gltf", ".obj", ".dae", ".blend", ".3ds"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".tga", ".tif", ".tiff", ".bmp", ".webp"}
AUDIO_EXT = {".wav", ".ogg", ".mp3"}

def inspect_glb(data: bytes, label: str) -> None:
    if len(data) < 20 or data[:4] != b"glTF":
        return
    version, total = struct.unpack_from("<II", data, 4)
    if version != 2 or total > len(data):
        print(f"  GLB_HEADER version={version} declared={total} actual={len(data)}")
        return
    offset = 12
    while offset + 8 <= total:
        size, kind = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + size]
        offset += size
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk.decode("utf-8").rstrip("\\x00 "))
            print(f"  GLB {label}: nodes={len(gltf.get('nodes', []))} "
                  f"meshes={len(gltf.get('meshes', []))} skins={len(gltf.get('skins', []))} "
                  f"animations={len(gltf.get('animations', []))} "
                  f"materials={len(gltf.get('materials', []))} "
                  f"images={len(gltf.get('images', []))}")
            print("  GLB_NODE_NAMES=" + ", ".join(
                str(n.get("name", f"node_{i}")) for i, n in enumerate(gltf.get("nodes", []))
                if n.get("name")
            )[:3000])
            print("  GLB_ANIMATION_NAMES=" + ", ".join(
                str(a.get("name", f"animation_{i}")) for i, a in enumerate(gltf.get("animations", []))
            ))
            print("  GLB_SKIN_NAMES=" + ", ".join(
                str(s.get("name", f"skin_{i}")) for i, s in enumerate(gltf.get("skins", []))
            ))

def inspect_zip(data: bytes, label: str, depth: int = 0) -> None:
    if depth > 3:
        print(f"MAX_NESTED_ZIP_DEPTH reached: {label}")
        return
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        bad = zf.testzip()
        if bad:
            raise SystemExit(f"Corrupt ZIP member in {label}: {bad}")
        entries = [x for x in zf.infolist() if not x.is_dir()]
        print(f"\n--- ZIP LEVEL {depth}: {label} files={len(entries)} integrity=OK ---")
        for item in entries:
            ext = Path(item.filename).suffix.lower()
            print(f"{item.file_size:>10}  {item.filename}")
            if ext == ".glb":
                inspect_glb(zf.read(item), item.filename)
            elif ext == ".zip":
                print(f"  NESTED_ARCHIVE: {item.filename}")
                inspect_zip(zf.read(item), item.filename, depth + 1)

for archive in ARCHIVES:
    print(f"\n=== ARCHIVE: {archive.name} ===")
    if not archive.is_file():
        raise SystemExit(f"Missing archive: {archive}")
    raw = archive.read_bytes()
    print(f"size_bytes={len(raw)} sha256={hashlib.sha256(raw).hexdigest()}")
    inspect_zip(raw, archive.name)
