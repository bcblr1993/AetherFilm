#!/usr/bin/env python3
"""Reproduce a package snapshot from pinned inputs plus the reviewed patch."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--require-frozen', action='store_true')
args = parser.parse_args()
package_root = Path(__file__).resolve().parents[1]
metadata = json.loads((package_root / 'Provenance/inputs.json').read_text())
if args.require_frozen and not metadata['frozenApproved']:
    raise RuntimeError('Root and playback have not frozen this snapshot')
for relative, expected in metadata['inputs'].items():
    if hashlib.sha256((package_root / relative).read_bytes()).hexdigest() != expected:
        raise RuntimeError('Pinned input changed: ' + relative)
patch = package_root / 'Patches/current-prototype.patch'
if hashlib.sha256(patch.read_bytes()).hexdigest() != metadata['prototypePatchSHA256']:
    raise RuntimeError('Reviewed prototype patch changed')
output = args.output.resolve()
target = output / 'Sources/AetherVLCBridge'
if target.exists():
    raise RuntimeError('Refusing to replace an existing generated source tree')
output.mkdir(parents=True, exist_ok=True)
private_names = ['VLCLibVLCBridging.h', 'AetherVLCMediaPlayer+Internal.h',
                 'VLCEventsHandler.h', 'VLCHelperCode.h']

def imports(text):
    def replace(match):
        name = match.group(1)
        if name == 'AetherVLCMediaPlayer.h' or name in private_names:
            return '#import "' + name + '"'
        if name.startswith('VLC') and '/' not in name:
            return '#import <VLCKit/' + name + '>'
        return match.group(0)
    return re.sub(r'#\s*import <([^>]+)>', replace, text)

banner = ('/* Modified by AetherNative on ' + metadata['modificationDate'] + '.\n'
          ' * Changes: player/notification namespace, typed callbacks with fixed stopping snapshots,\n'
          ' * checked interpolation, and target-relative SwiftPM header imports.\n'
          ' * Original LGPL notices are retained.\n'
          ' */\n')
with tempfile.TemporaryDirectory(prefix='aether-bridge-generation-', dir=output) as temporary:
    namespace = Path(temporary) / 'Namespace'
    subprocess.run([sys.executable, str(package_root / 'Tools/generate_namespaced_wrapper.py'),
                    '--upstream', str(package_root / 'PinnedInputs/Wrapper'), '--output', str(namespace)], check=True)
    subprocess.run(['patch', '-p' + str(metadata.get('patchStripComponents', 1)), '--batch', '--forward', '--fuzz=0', '-i', str(patch)],
                   cwd=namespace, check=True)
    for relative, expected in metadata['capturedPrototypeHashes'].items():
        if hashlib.sha256((namespace / relative).read_bytes()).hexdigest() != expected:
            raise RuntimeError('Patch does not reproduce the captured prototype: ' + relative)
    include = target / 'include'
    private = target / 'Private'
    vendor = target / 'Vendor/vlc'
    include.mkdir(parents=True)
    private.mkdir()
    vendor.mkdir(parents=True)
    header = (namespace / 'include/AetherVLCMediaPlayer.h').read_text()
    (include / 'AetherVLCMediaPlayer.h').write_text(banner + header)
    implementation = imports((namespace / 'src/AetherVLCMediaPlayer.m').read_text())
    (target / 'AetherVLCMediaPlayer.m').write_text(banner + '#import "Private/AetherVLCPrefix.h"\n' + implementation)
    for name in private_names:
        original = (namespace / 'include' / name).read_text()
        converted = imports(original)
        changed = converted != original or name in ['AetherVLCMediaPlayer+Internal.h', 'VLCLibVLCBridging.h']
        (private / name).write_text((banner if changed else '') + converted)
    prefix = imports((namespace / 'include/Prefix.pch').read_text())
    (private / 'AetherVLCPrefix.h').write_text(banner + prefix)
    for path in (package_root / 'PinnedInputs/PublicC').glob('*.h'):
        shutil.copy2(path, vendor / path.name)
record = dict(metadata)
record['generatedFiles'] = {str(path.relative_to(output)): hashlib.sha256(path.read_bytes()).hexdigest()
                            for path in sorted(target.rglob('*')) if path.is_file()}
(output / 'generated-provenance.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'generated': str(target), 'frozenApproved': metadata['frozenApproved'],
                  'files': len(record['generatedFiles'])}))
