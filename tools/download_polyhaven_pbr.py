#!/usr/bin/env python3
"""Download CC0 2K PBR materials from Poly Haven for the 4v4 prototype."""
import json
import re
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

API = "https://api.polyhaven.com"
OUT = Path("game/assets/textures/pbr")
HEADERS = {"User-Agent": "FreeFire3D-4v4-asset-pipeline/1.0"}

def read_url(url, timeout=90):
    request = urllib.request.Request(url, headers=HEADERS)
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.read()
        except Exception as exc:
            last_error = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Download failed: {url}: {last_error}")

def get_json(url):
    return json.loads(read_url(url).decode("utf-8"))

def searchable_text(asset_id, meta):
    values = [asset_id, str(meta.get("name", "")), str(meta.get("category", ""))]
    for field in ("categories", "tags", "keywords"):
        value = meta.get(field, [])
        if isinstance(value, list):
            values.extend(str(item) for item in value)
        else:
            values.append(str(value))
    return " ".join(values).lower()

def choose_asset(assets, groups):
    for group in groups:
        candidates = []
        for asset_id, meta in assets.items():
            text = searchable_text(asset_id, meta)
            if all(term in text for term in group):
                popularity = meta.get("downloads", meta.get("download_count", 0))
                try:
                    popularity = int(popularity)
                except Exception:
                    popularity = 0
                candidates.append((popularity, asset_id, meta))
        if candidates:
            candidates.sort(reverse=True, key=lambda row: row[0])
            return candidates[0][1], candidates[0][2]
    return None, None

def walk_files(node, path=()):
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            yield path, node
        for key, value in node.items():
            yield from walk_files(value, path + (str(key),))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from walk_files(value, path + (str(index),))

def normalize_map_name(parts):
    raw = " ".join(parts).lower()
    if any(x in raw for x in ("diffuse", "albedo", "basecolor", "base color", "color")):
        return "basecolor"
    if "nor_gl" in raw or "normal" in raw or "nor_dx" in raw:
        return "normal"
    if "rough" in raw:
        return "roughness"
    if "ambient" in raw or re.search(r"(^|\W)ao(\W|$)", raw):
        return "ao"
    if "metal" in raw:
        return "metallic"
    if "disp" in raw or "height" in raw:
        return "height"
    return re.sub(r"[^a-z0-9]+", "_", parts[0].lower()).strip("_") or "map"

def select_2k_maps(files):
    selected = {}
    for parts, item in walk_files(files):
        lowered = [part.lower() for part in parts]
        if "2k" not in lowered:
            continue
        map_name = normalize_map_name(parts)
        url = item["url"]
        ext = Path(urlparse(url).path).suffix.lower().lstrip(".")
        if ext not in ("jpg", "jpeg", "png", "exr", "tif", "tiff"):
            continue
        rank = 0
        if map_name == "basecolor":
            rank = 3 if ext in ("jpg", "jpeg") else 2
        elif map_name in ("normal", "roughness", "ao", "metallic", "height"):
            rank = 3 if ext == "png" else 2
        if map_name not in selected or rank > selected[map_name][0]:
            selected[map_name] = (rank, url, ext)
    return selected

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    assets = get_json(API + "/assets?type=textures")
    if not isinstance(assets, dict) or not assets:
        raise SystemExit("Poly Haven returned no texture asset catalogue")

    roles = {
        "wall": [[ "brick", "wall" ], [ "plaster" ], [ "concrete", "wall" ]],
        "floor": [[ "wood", "floor" ], [ "wood", "planks" ], [ "concrete", "floor" ]],
        "roof": [[ "roof", "tile" ], [ "roof" ]],
        "ground": [[ "grass" ], [ "ground" ], [ "soil" ]],
        "concrete": [[ "concrete" ]]
    }
    manifest = {
        "provider": "Poly Haven",
        "license": "CC0",
        "resolution": "2K",
        "assets": {}
    }

    for role, groups in roles.items():
        asset_id, meta = choose_asset(assets, groups)
        if not asset_id:
            print("POLYHAVEN_ROLE_SKIPPED", role)
            continue
        files = get_json(f"{API}/files/{asset_id}")
        maps = select_2k_maps(files)
        if "basecolor" not in maps:
            print("POLYHAVEN_NO_2K_BASECOLOR", role, asset_id, list(maps))
            continue
        role_dir = OUT / role
        role_dir.mkdir(parents=True, exist_ok=True)
        entry = {
            "asset_id": asset_id,
            "name": meta.get("name", asset_id),
            "maps": {}
        }
        for map_name, (_rank, url, ext) in maps.items():
            suffix = "jpg" if ext == "jpeg" else ext
            target = role_dir / f"{map_name}.{suffix}"
            target.write_bytes(read_url(url, timeout=120))
            entry["maps"][map_name] = {
                "file": str(target),
                "bytes": target.stat().st_size,
                "source_url": url
            }
        manifest["assets"][role] = entry
        print("POLYHAVEN_MATERIAL_OK", role, asset_id, "maps", ",".join(entry["maps"]))

    if len(manifest["assets"]) < 3:
        raise SystemExit("Insufficient Poly Haven 2K materials downloaded")
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    (OUT / "ASSET_CREDITS.txt").write_text(
        "PBR texture materials downloaded from Poly Haven. License: CC0. "
        "Source: https://polyhaven.com/ and https://api.polyhaven.com/\n",
        encoding="utf-8"
    )
    print("POLYHAVEN_PBR_OK", json.dumps({k: v["asset_id"] for k, v in manifest["assets"].items()}))

if __name__ == "__main__":
    main()
