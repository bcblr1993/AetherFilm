#!/usr/bin/env python3
"""Create an explicit owned local build copy; preserve formal remote manifests."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--project-root', type=Path, required=True)
parser.add_argument('--bridge-snapshot', type=Path, required=True)
parser.add_argument('--vlckit-mirror', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
original = args.project_root.resolve()
bridge_source = args.bridge_snapshot.resolve()
mirror = args.vlckit_mirror.resolve()
output = args.output.resolve()
asset_expected_hashes = {}
if output.exists():
    raise RuntimeError('Refusing to overwrite an existing diagnostic tree')
if not (mirror / 'Package.swift').is_file() or not (mirror / 'VLCKit.xcframework/Info.plist').is_file():
    raise RuntimeError('Supply the already verified local VLCKit package mirror')
try:
    repo_root = Path(subprocess.check_output(['git', '-C', str(original), 'rev-parse', '--show-toplevel'], text=True).strip())
except subprocess.CalledProcessError:
    repo_root = None
if repo_root == original:
    relative_files = subprocess.check_output(
        ['git', '-C', str(original), 'ls-files', '--cached', '--others', '--exclude-standard', '-z']
    ).decode().split('\0')
    relative_files = [path for path in relative_files if path]
    export = 'tracked and non-ignored new working-copy files; SHA proves actual bytes, not an immutable commit export'
else:
    manifest = original.parent / 'MANIFEST.sha256'
    if not manifest.is_file() or original.name != 'ApplicationSource':
        raise RuntimeError('Use the repository root or a verified source-asset ApplicationSource')
    for line in manifest.read_text().splitlines():
        expected, relative = line.split('  ', 1)
        if not relative.startswith('ApplicationSource/'):
            continue
        relative = relative[len('ApplicationSource/'):]
        if Path(relative).is_absolute() or '..' in Path(relative).parts:
            raise RuntimeError('Invalid source-asset path')
        if not re.fullmatch(r'[0-9a-f]{64}', expected):
            raise RuntimeError('Invalid source-asset hash')
        asset_expected_hashes[relative] = expected
    relative_files = sorted(asset_expected_hashes)
    if not relative_files:
        raise RuntimeError('Source-asset manifest contains no ApplicationSource files')
    export = 'frozen application source-asset files'
output.mkdir(parents=True)
source_hashes = {}
for relative in relative_files:
    source = original / relative
    if not source.is_file():
        raise RuntimeError('Required tracked source is unavailable: ' + relative)
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    source_hashes[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
    if asset_expected_hashes and source_hashes[relative] != asset_expected_hashes[relative]:
        raise RuntimeError('Frozen source-asset file changed: ' + relative)
    shutil.copy2(source, destination)
local_bridge = output / 'Packages/AetherVLCBridge'
if local_bridge.exists():
    # Replace only the self-created copied package, not original source files.
    shutil.rmtree(local_bridge)
shutil.copytree(bridge_source, local_bridge, ignore=shutil.ignore_patterns('__pycache__'))
spec_file = output / 'project.yml'
original_spec = spec_file.read_text()
spec = json.loads(subprocess.check_output(
    ['/usr/bin/ruby', '-rjson', '-ryaml', '-e',
     'puts JSON.generate(YAML.safe_load(STDIN.read, permitted_classes: [], permitted_symbols: [], aliases: true))'],
    input=original_spec, text=True))
packages = spec['packages']
# Existing local project overrides may use LocalVLCKit as their key. Normalize
# all direct and transitive references to one mirror while keeping that key.
vlc_key = 'LocalVLCKit' if 'LocalVLCKit' in packages else 'VLCKit'
packages.pop('VLCKit', None)
packages.pop('LocalVLCKit', None)
packages[vlc_key] = {'path': str(mirror)}
packages['AetherVLCBridge'] = {'path': 'Packages/AetherVLCBridge'}
for name, target in spec['targets'].items():
    dependencies = target.setdefault('dependencies', [])
    for dependency in dependencies:
        if dependency.get('package') in ['VLCKit', 'LocalVLCKit']:
            dependency['package'] = vlc_key
            dependency['product'] = 'VLCKit'
    if target['type'] in ['application', 'bundle.unit-test']:
        if not any(item.get('package') == 'AetherVLCBridge' for item in dependencies):
            dependencies.append({'package': 'AetherVLCBridge', 'product': 'AetherVLCBridge'})
spec_file.write_text(subprocess.check_output(
    ['/usr/bin/ruby', '-rjson', '-ryaml', '-e', 'puts YAML.dump(JSON.parse(STDIN.read))'],
    input=json.dumps(spec, ensure_ascii=False), text=True))
manifest_file = local_bridge / 'Package.swift'
remote_manifest = manifest_file.read_text()
replacement = '.package(name: "VLCKit", path: ' + json.dumps(str(mirror)) + ')'
fixed_dependency = (
    r'\.package\(\s*url:\s*"https://github\.com/videolan/vlckit(?:\.git)?"\s*,\s*revision:\s*"8f5ce02f09a7da5d061a24ddac3cb432f2a9b332"\s*\)'
    r'|\.package\(\s*name:\s*"VLCKit"\s*,\s*path:\s*"\.\./AetherVLCKit"\s*\)'
)
local_manifest, count = re.subn(fixed_dependency,
                              lambda _: replacement, remote_manifest)
if count != 1:
    raise RuntimeError('Expected exactly one fixed formal VLCKit dependency')
manifest_file.write_text(local_manifest)
implementation_proof = {}
for path in (bridge_source / 'Sources').rglob('*'):
    if path.is_file():
        relative = path.relative_to(bridge_source)
        expected = hashlib.sha256(path.read_bytes()).hexdigest()
        actual = hashlib.sha256((local_bridge / relative).read_bytes()).hexdigest()
        if expected != actual:
            raise RuntimeError('Diagnostic local mirror changed implementation bytes')
        implementation_proof[str(relative)] = expected
for relative, expected in source_hashes.items():
    if hashlib.sha256((original / relative).read_bytes()).hexdigest() != expected:
        raise RuntimeError('Original working source changed during diagnostic preparation')
record = {'diagnosticOnly': True, 'exportMethod': export, 'sourceHashes': source_hashes,
          'mirror': str(mirror), 'directProjectPackageKey': vlc_key,
          'bridgeImplementationFilesUnchanged': implementation_proof,
          'formalRemoteManifestSHA256': hashlib.sha256(remote_manifest.encode()).hexdigest(),
          'localManifestSHA256': hashlib.sha256(local_manifest.encode()).hexdigest(),
          'formalProjectAndPackageFilesWritten': False,
          'projectRegenerated': False, 'sourceSnapshotFrozenApproved':
          json.loads((bridge_source / 'Provenance/inputs.json').read_text())['frozenApproved']}
(output / 'local-mirror-provenance.json').write_text(json.dumps(record, indent=2) + '\n')
(output / 'bridge-manifest-local.diff').write_text(''.join(difflib.unified_diff(
    remote_manifest.splitlines(keepends=True), local_manifest.splitlines(keepends=True),
    fromfile='formal/Package.swift', tofile='diagnostic/Package.swift')))
(output / 'project-local.diff').write_text(''.join(difflib.unified_diff(
    original_spec.splitlines(keepends=True), spec_file.read_text().splitlines(keepends=True),
    fromfile='formal/project.yml', tofile='diagnostic/project.yml')))
print(json.dumps({'diagnosticTree': str(output), 'sameBridgeImplementationFiles': len(implementation_proof),
                  'projectRegenerated': False, 'formalFilesWritten': False}))
