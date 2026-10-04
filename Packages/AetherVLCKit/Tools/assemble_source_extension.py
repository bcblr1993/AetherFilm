#!/usr/bin/env python3
"""Archive an exact clean application commit plus the missing pinned Lua source.

No binary, original665MB asset, SDK, user cache or .build tree is included.
The result remains source material, not a release or rebuild acceptance claim.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

PACKAGE = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--commit", required=True, help="Exact final application commit")
    parser.add_argument("--lua-source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    materials = json.loads((PACKAGE / "Provenance/source-materials.json").read_text())
    lua = args.lua_source.read_bytes()
    expected = materials["additionalSourceArchives"][0]
    if len(lua) != expected["bytes"] or hashlib.sha256(lua).hexdigest() != expected["sha256"]:
        raise ValueError("Pinned Lua5.4.4 source differs")
    commit = subprocess.check_output(["git", "-C", str(args.repository), "rev-parse", "--verify", args.commit + "^{commit}"], text=True).strip()
    head = subprocess.check_output(["git", "-C", str(args.repository), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(args.repository), "status", "--porcelain"], text=True)
    if commit != head or dirty:
        raise ValueError("Final application commit must be the clean current HEAD")
    if args.output.exists():
        raise ValueError("Preserve existing output")
    manifest = {"applicationCommit": commit, "baseAsset": materials["baseAsset"], "luaSource": expected,
                "scope": "CORRESPONDING_SOURCE_EXTENSION_NOT_RELEASE_ACCEPTANCE",
                "fullPortableRebuildExecuted": False, "publicDistributionVerified": False}
    if not args.execute:
        print(json.dumps(manifest, indent=2))
        return
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="aetherfilm-source-", dir=args.output.parent) as temporary:
        source = Path(temporary) / "application.tar"
        subprocess.run(["git", "-C", str(args.repository), "archive", "--format=tar", "--prefix=application/",
                        "--output=" + str(source), commit], check=True)
        with tarfile.open(source) as original, tarfile.open(args.output, "x:gz") as target:
            for member in original:
                if member.name.startswith("application/.build/") or member.name.startswith("application/artifacts/"):
                    raise ValueError("Generated inputs must not be tracked into the source extension")
                target.addfile(member, original.extractfile(member) if member.isfile() else None)
            for name, payload in [("additional-sources/lua-5.4.4.tar.gz", lua),
                                  ("extension-manifest.json", (json.dumps(manifest, indent=2) + "\n").encode())]:
                member = tarfile.TarInfo(name); member.size = len(payload); member.mode = 0o644
                target.addfile(member, io.BytesIO(payload))
    value = hashlib.sha256()
    with args.output.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    print(json.dumps({"asset": args.output.name, "bytes": args.output.stat().st_size,
                      "sha256": value.hexdigest(), "applicationCommit": commit, "releaseAccepted": False}))


if __name__ == "__main__":
    main()
