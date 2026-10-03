#!/usr/bin/env python3
"""Build final frozen callback contracts; never launch an App or Simulator."""
import argparse
from datetime import datetime, timezone
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--package-snapshot', type=Path, required=True)
parser.add_argument('--vlckit-mirror', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
snapshot = args.package_snapshot.resolve()
mirror = args.vlckit_mirror.resolve()
output = args.output.resolve()
metadata = json.loads((snapshot / 'Provenance/inputs.json').read_text())
if not metadata['frozenApproved']:
    raise RuntimeError('Final consumer verification requires the owner-approved frozen snapshot')
generated = json.loads((snapshot / 'generated-provenance.json').read_text())
if not generated['frozenApproved']:
    raise RuntimeError('Regenerate the sources after the owners freeze the snapshot')
actual_source_hashes = {str(path.relative_to(snapshot)): hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in sorted((snapshot / 'Sources').rglob('*')) if path.is_file()}
if actual_source_hashes != generated['generatedFiles']:
    raise RuntimeError('Generated source inventory or bytes differ from the recorded snapshot')
for relative, expected in metadata['inputs'].items():
    if hashlib.sha256((snapshot / relative).read_bytes()).hexdigest() != expected:
        raise RuntimeError('Fixed original input changed: ' + relative)
if hashlib.sha256((snapshot / 'Patches/current-prototype.patch').read_bytes()).hexdigest() != metadata['prototypePatchSHA256']:
    raise RuntimeError('The approved prototype patch changed')
if output.exists():
    raise RuntimeError('Refusing to replace existing consumer evidence')
if not (mirror / 'VLCKit.xcframework/Info.plist').is_file():
    raise RuntimeError('Supply the already verified fixed local binary mirror')
public = (snapshot / 'Sources/AetherVLCBridge/include/AetherVLCMediaPlayer.h').read_text()
for spelling in ['mediaPlayerStopping(reason:inputTime:hadError:)',
                 'mediaPlayerClockPoint(time:position:systemDate:)',
                 'mediaPlayerInputPositionChanged(time:position:)']:
    if 'NS_SWIFT_NAME(' + spelling + ')' not in public:
        raise RuntimeError('Final public callback name differs: ' + spelling)
if 'measuredCoreTime' in public:
    raise RuntimeError('Prototype diagnostic getter must not be in the final public header')

output.mkdir(parents=True)
bridge = output / 'DiagnosticBridge'
shutil.copytree(snapshot, bridge, ignore=shutil.ignore_patterns('__pycache__'))
manifest = bridge / 'Package.swift'
formal = manifest.read_text()
local, count = re.subn(
    r'\.package\(\s*url:\s*"https://github\.com/videolan/vlckit(?:\.git)?"\s*,\s*revision:\s*"8f5ce02f09a7da5d061a24ddac3cb432f2a9b332"\s*\)',
    lambda _: '.package(name: "VLCKit", path: ' + json.dumps(str(mirror)) + ')', formal)
if count != 1:
    raise RuntimeError('Expected exactly one official fixed production dependency')
manifest.write_text(local)
(output / 'bridge-manifest-local.diff').write_text(''.join(difflib.unified_diff(
    formal.splitlines(keepends=True), local.splitlines(keepends=True),
    fromfile='formal/Package.swift', tofile='diagnostic/Package.swift')))
source_hashes = {}
for source in sorted((snapshot / 'Sources').rglob('*')):
    if source.is_file():
        relative = source.relative_to(snapshot)
        expected = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256((bridge / relative).read_bytes()).hexdigest() != expected:
            raise RuntimeError('Diagnostic bridge implementation differs')
        source_hashes[str(relative)] = expected
root = output / 'ConsumerPackage'
(root / 'Sources/ContractConsumer').mkdir(parents=True)
root_manifest = '''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "AetherVLCBridgeContractProbe", platforms: [.macOS("26.0"), .iOS("26.0")],
 products: [.executable(name: "ContractConsumer", targets: ["ContractConsumer"])],
 dependencies: [.package(name: "LocalVLCKit", path: MIRROR), .package(name: "AetherVLCBridge", path: BRIDGE)],
 targets: [.executableTarget(name: "ContractConsumer", dependencies: [.product(name: "VLCKit", package: "LocalVLCKit"), .product(name: "AetherVLCBridge", package: "AetherVLCBridge")])])
'''
(root / 'Package.swift').write_text(root_manifest.replace('MIRROR', json.dumps(str(mirror))).replace('BRIDGE', json.dumps(str(bridge))))
shutil.copy2(snapshot / 'Tools/ConsumerContract.swift', root / 'Sources/ContractConsumer/Consumer.swift')
graph = subprocess.run(['swift', 'package', '--package-path', str(root),
                        'show-dependencies', '--format', 'json'], capture_output=True, text=True)
(output / 'dependency-graph.json').write_text(graph.stdout)
(output / 'dependency-graph.stderr').write_text(graph.stderr)
if graph.returncode:
    raise RuntimeError('The diagnostic package graph did not resolve')

matrix = [
    ('macos-arm64', 'arm64-apple-macos26.0', 'macosx'),
    ('macos-x86_64', 'x86_64-apple-macos26.0', 'macosx'),
    ('ios-arm64', 'arm64-apple-ios26.0', 'iphoneos'),
    ('sim-arm64', 'arm64-apple-ios26.0-simulator', 'iphonesimulator'),
    ('sim-x86_64', 'x86_64-apple-ios26.0-simulator', 'iphonesimulator'),
]
results = []
for name, triple, sdk_name in matrix:
    sdk = subprocess.check_output(['xcrun', '--sdk', sdk_name, '--show-sdk-path'], text=True).strip()
    scratch = output / ('Build-' + name)
    command = ['swift', 'build', '--package-path', str(root), '--scratch-path', str(scratch),
               '--triple', triple, '--sdk', sdk, '--product', 'ContractConsumer', '-j', '2', '-v']
    entry = {'platform': name, 'command': command, 'startedAt': datetime.now(timezone.utc).isoformat()}
    with (output / (name + '.log')).open('w') as log:
        run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
    entry.update(exitCode=run.returncode, finishedAt=datetime.now(timezone.utc).isoformat())
    if run.returncode == 0:
        candidates = [p for p in scratch.rglob('ContractConsumer') if p.is_file()
                      and 'Products' in p.parts and not any(part.endswith('.dSYM') for part in p.parts)]
        if len(candidates) != 1:
            raise RuntimeError('Expected one actual linked consumer product')
        product = candidates[0]
        symbols = subprocess.check_output(['nm', '-m', str(product)], text=True)
        owned = [line for line in symbols.splitlines() if '_OBJC_CLASS_$_AetherVLCMediaPlayer' in line and '(undefined)' not in line]
        if not owned:
            raise RuntimeError('The owned player class was not strongly linked')
        stock = [line for line in symbols.splitlines() if '_OBJC_CLASS_$_VLCMediaPlayer' in line and '(undefined)' not in line]
        if stock:
            raise RuntimeError('Stock player class was unexpectedly defined by the consumer')
        state = json.loads((scratch / 'workspace-state.json').read_text())
        artifacts = state['object']['artifacts']
        if len(artifacts) != 1 or artifacts[0]['packageRef']['identity'] != 'localvlckit':
            raise RuntimeError('The graph contains multiple binary artifacts')
        compiler_log = (output / (name + '.log')).read_text()
        if '-fobjc-arc' not in compiler_log:
            raise RuntimeError('The actual wrapper compile did not enable Objective-C ARC')
        build_version = subprocess.check_output(['vtool', '-show-build', str(product)], text=True).strip()
        if not re.search(r'\bminos\s+26\.0\b', build_version):
            raise RuntimeError('The actual consumer deployment target is not 26.0')
        entry.update(product=str(product), SHA256=hashlib.sha256(product.read_bytes()).hexdigest(),
                     UUID=subprocess.check_output(['dwarfdump', '--uuid', str(product)], text=True).strip(),
                     buildVersion=build_version, automaticObjectiveCARC=True,
                     artifactCount=len(artifacts), ownedClassDefined=True, stockPlayerClassDefined=False)
    results.append(entry)
    (output / 'consumer-matrix.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps({'platform': name, 'exitCode': run.returncode}), flush=True)
    if run.returncode:
        sys.exit(run.returncode)
(output / 'consumer-proof.json').write_text(json.dumps({
    'frozenApproved': True, 'finalCallbacksCompiled': True, 'builds': results,
    'diagnosticManifestDiff': 'bridge-manifest-local.diff',
    'implementationFilesUnchanged': source_hashes, 'formalFilesWritten': False,
    'formalProjectGenerated': False, 'appsOrSimulatorsLaunched': False,
    'note': 'This is an explicitly modified local dependency-manifest build, not a fully unmodified remote production build.'
}, indent=2) + '\n')
