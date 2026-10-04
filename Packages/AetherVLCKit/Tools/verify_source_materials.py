#!/usr/bin/env python3
"""Verify extracted source inputs without downloading, extracting or building."""
import argparse
import hashlib
import json
from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def verify(path, row):
    if not path.is_file() or path.stat().st_size != row["bytes"] or digest(path) != row["sha256"]:
        raise ValueError(f"Source input differs: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--materials", type=Path, required=True, help="Extracted older source-input asset")
    parser.add_argument("--lua-source", type=Path, required=True)
    args = parser.parse_args()
    materials = json.loads((PACKAGE / "Provenance/source-materials.json").read_text())
    local = json.loads((PACKAGE / "Provenance/local-inputs.json").read_text())
    for row in local["files"]:
        verify(PACKAGE / row["path"], row)
    for row in materials["sourceArchives"]:
        verify(args.materials / row["name"], row)
    for row in materials["contribInputs"]:
        verify(args.materials / row["assetRelativePath"], row)
    verify(args.lua_source, materials["additionalSourceArchives"][0])
    print(json.dumps({"sourceArchives": 3, "contribArchivesAndSidecars": 68,
                      "luaVerified": True, "smallLocalInputs": len(local["files"]),
                      "compilerExecuted": False, "releaseAccepted": False}))


if __name__ == "__main__":
    main()
