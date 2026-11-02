from __future__ import annotations

import hashlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVES = [
    ROOT / "SourceArchives" / "olivia-free-fire.zip",
    ROOT / "SourceArchives" / "free-fire-clocktower-3d-model-by-rs-ratul.zip",
]

MODEL_EXT = {".fbx", ".glb", ".gltf", ".obj", ".dae", ".blend", ".3ds"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".tga", ".tif", ".tiff", ".bmp", ".webp"}
ANIM_EXT = {".anim", ".bvh", ".dae", ".fbx"}
AUDIO_EXT = {".wav", ".ogg", ".mp3"}

for archive in ARCHIVES:
    print(f"\n=== ARCHIVE: {archive.name} ===")
    if not archive.is_file():
        raise SystemExit(f"Missing archive: {archive}")
    raw = archive.read_bytes()
    print(f"size_bytes={len(raw)} sha256={hashlib.sha256(raw).hexdigest()}")
    with zipfile.ZipFile(archive) as zf:
        bad = zf.testzip()
        if bad:
            raise SystemExit(f"Corrupt ZIP member: {bad}")
        entries = [x for x in zf.infolist() if not x.is_dir()]
        print(f"integrity=OK files={len(entries)}")
        for ext, label in ((MODEL_EXT, "MODEL"), (IMAGE_EXT, "IMAGE"),
                           (ANIM_EXT, "ANIMATION_OR_MODEL"), (AUDIO_EXT, "AUDIO")):
            selected = [x for x in entries if Path(x.filename).suffix.lower() in ext]
            print(f"{label}_COUNT={len(selected)}")
            for item in selected:
                print(f"  {item.file_size:>10}  {item.filename}")
        print("OTHER_FILES:")
        for item in entries:
            if Path(item.filename).suffix.lower() not in MODEL_EXT | IMAGE_EXT | ANIM_EXT | AUDIO_EXT:
                print(f"  {item.file_size:>10}  {item.filename}")
