# AetherFilm VLCKit source materials

This package records the modified native backend used by AetherFilm. The current
artifact contains only macOS ARM64, iOS ARM64 and iOS Simulator ARM64, with minimum
OS 26.0 and SDK 27.0. `Provenance/artifact.json` and `Package.swift` pin the actual
assembled Native6 binary. Its planned GitHub asset is not yet publicly distributed.

The wrapper base is `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`; the libVLC base is
`005e69e67a8730f128e44bde68437fbb048cf45f`. The source archive whose tree is
`9cb4e084a5e41ba0f7037c209884d8816ef929ad` already contains the official twelve
VLCKit patches. **Do not apply those twelve patches again.** Historical stock
checksums describe earlier inputs, not the modified current artifact.

## Recorded execution and limits

`Provenance/native4-build-record.json` records the actual four C source compilations
and archive replacements for all three platforms, and the actual two wrapper
targets on each platform. It preserves argv with `${REPOSITORY}` and
`${DEVELOPER_DIR}` path tokens. `Provenance/artifact.json` records the assembled
three-slice product. `Provenance/native5-build-record.json` records the subsequent
audio output time-domain correction: one production `dec.o` was compiled for
each platform, replacing only that native member in its core and full archives,
then both wrapper targets were built again. The Native4 record remains historical
evidence, including its earlier assembled-artifact checksum. These records do
not establish a fresh portable rebuild or App,
physical-device, accessibility, recovery or public-distribution acceptance.

The five original local patches were applied, without fuzz, to nine affected
files from the pinned official patched archive. The sixth patch,
`audio-output-domain.patch`, was applied without fuzz to the unchanged original
`src/audio_output/dec.c`; its result matches the source used by all three new
compilers. It preserves output timestamps before playback-rate conversion so
fallback drain delays stay in physical time. The ten current source pins cover
nine production C/ObjC files and the GSM build rule. Three portable wrapper
project patches were also applied and syntax
checked against the pinned original wrapper project. Only these small source
proofs and tool syntax/help checks were executed during preparation of this
package. `Tools/rebuild_core.py` has not been used for a full portable build.

Native6 preserves the preceding six patches and all ten source hashes. Its seventh
patch, `output-clock-cadence.patch`, changes the real AVSampleBuffer renderer
observation interval from 1 second to 100 milliseconds. AetherNative modified
`modules/audio_output/apple/avsamplebuffer.m` on 2026-10-04; the original copyright
and license remain intact. The patch applied without fuzz or offset to the
official pinned source, and its result is the source compiled on all three platforms.
The current eleven source pins include that file. `native6-build-record.json`
records those actual three object compilations, one full-archive member replacement
per platform, unchanged Native5 core archives and six normal wrapper targets.
It also records the macOS-only removal of one weak private compiler availability
link guard when the frontend minimum changed from 10.13 to 26.0; all other 29
defined names match. The old object metadata minimum of 11.0 is distinct from
that old frontend setting. All public headers, module APIs and 302 module exports
remain unchanged. The original Simulator half-speed function case passed its
unchanged 30-second gate, with genuine normal-clock samples about every 100 ms.
This isolated case is not the final application, physical-device or distribution gate.

## Prepare source inputs

Use a new owned directory on an ARM64 Mac with at least 12 GiB available. Obtain
the older source asset named in `Provenance/source-materials.json` and compare its
size and SHA-256 before extraction. It contains the three pinned source archives
and 64 contrib archives plus four sidecars. Preserve that asset separately;
the final extension does not duplicate its 665 MB contents.

Obtain `lua-5.4.4.tar.gz`, whose upstream URL is
<https://www.lua.org/ftp/lua-5.4.4.tar.gz>. Its required size is 360876 bytes and
SHA-256 is
`164c7849653b80ae67bec4b7473b884bf5cc8d2dca05653475ec2ed27b9ebf61`.
The original source asset does not contain this required archive.

The following variables are caller-selected absolute paths, not machine-specific
defaults. The verifier reads archives and does not extract or build them:

```sh
package_dir="$repository_dir/Packages/AetherVLCKit"
python3 "$package_dir/Tools/verify_source_materials.py" \
  --materials "$materials_dir" --lua-source "$lua_source"
```

Prepare three separate fresh VLC source trees by extracting
`vlc-patched-source.tar.gz`. Copy the contents of the verified
`contrib-tarballs/` directory to each tree's `contrib/tarballs/`, then copy the
verified Lua archive there. Apply the following local patches once per tree:

```sh
for patch_name in native-aperture gsm-deployment paused-preview-core \
                  decoder-flush-preview held-io-recovery audio-output-domain \
                  output-clock-cadence; do
  patch --directory="$vlc_source" -p1 --batch --forward --fuzz=0 \
    < "$package_dir/Patches/$patch_name.patch"
done
```

Keep the original archives, patch logs and original license files. A source tar
does not itself reconstruct the original Git metadata used by version generation.
Resolving that metadata, checking full-tree identity and performing a fresh
complete build remain explicit portable-build tasks; source preparation is not
reported as a completed rebuild. For an alternative Git checkout, pin the base
commit and apply the twelve official patches exactly once before the seven local
patches. Never combine that step with the already patched source archive.

## Core build entry point

Use Xcode containing SDK 27.0 selected through its normal `DEVELOPER_DIR` setting.
The driver asks `xcrun` for the selected SDK; no installed Xcode path is embedded.
Provide existing GNU make and pinned VLC `extras/tools` host tools, including
Meson. Their fresh bootstrap, archive checks and version inventory are required
before running this driver; it does not install global tools. Existing recorded
host-tool build results are historical evidence, not a portable bootstrap test.

Rust and Cargo must be 1.96.0, with existing standard libraries for
`aarch64-apple-darwin`, `aarch64-apple-ios` and `aarch64-apple-ios-sim`.
`Provenance/source-materials.json` records the actual versions, official installer
archive pins, rav1e Cargo.lock and vendor-source boundaries. The upstream rav1e
nightly declaration is retained in source; the recorded iOS builds selected the
existing 1.96.0 toolchain explicitly. Repacking a vendor archive changes its
container checksum and requires crate/checksum/payload review; it cannot be
claimed to match the old outer archive hash.

For each platform, create an existing parent directory and choose a new output
directory outside its source tree. This command only checks inputs and prints a
plan. Add `--execute` only when intentionally starting the full compiler run:

```sh
python3 "$package_dir/Tools/rebuild_core.py" \
  --source "$vlc_source" --output "$core_output" --platform mac \
  --rust-bin "$rust_bin" --gmake "$gnu_make" --host-tools-bin "$host_tools_bin"
```

Use `mac`, `sim` or `device`. The driver supplies `--arch=arm64`, the corresponding
SDK 27.0, `Configuration/build26.conf`, `--disable-debug` and four jobs. It owns its
output caches and restores its temporary directory through contrib's `env -i`
Meson invocation. It does not replace an existing output or change `HOME` or
`RUSTUP_HOME`. Logs and outcomes remain in the new output. A successful compiler
exit still requires archive architecture, minimum-OS, module, symbol and license
inspection, followed by wrapper and application tests.

The driver intentionally checks all eleven Native6 release source hashes. When rebuilding
with user modifications, retain the original release pins and create a separate
record of the modified hashes and build identity. Such a rebuild is not the
byte-identical release artifact.

## Wrapper reconstruction

Extract three fresh copies of the pinned `vlckit-source.tar.gz`. Apply the
corresponding `Patches/wrapper-{mac,sim,device}.patch` with `patch -p1 --batch
--forward --fuzz=0`. These patches change SDK framework references, header-phase
selection and the two native archive references. The archive references use the
Xcode build variable `AETHERFILM_CORE_ARCHIVE` instead of a local absolute path.

Before compiling, reconstruct the libVLC header directory and generated version
headers from that platform's core build using the pinned upstream wrapper build
procedure. Populate the platform's `Headers/Internal/vlc-plugins-*.h` from its
generated `static-module-list.c`. The checked-in module lists are the actual 302
module release lists and can validate this fixed configuration; changing modules
requires regeneration and renewed symbol inspection. Header generation and this
fresh wrapper preparation are not automated by the core driver and remain
portable-build tasks.

Use the two actual argv arrays in `Provenance/native6-build-record.json` as the
wrapper recipe: first target `Static libVLC`, then `VLCKit`, Release, four jobs,
ARM64, minimum 26.0, SDK 27.0, unsigned, owned SYMROOT/OBJROOT/cache directories
and `DEBUG_INFORMATION_FORMAT=dwarf`. Rebase `${REPOSITORY}` and select new
outputs. Supply `AETHERFILM_CORE_ARCHIVE=/absolute/path/to/libvlc-full-static.a`
to both targets for the portable PBX project. Retain `-ObjC -framework IOKit
-framework SystemConfiguration` on macOS, and `-ObjC -framework Metal` plus
`ENABLE_BITCODE=NO` on iOS. Inspect the resulting three frameworks and assemble
the XCFramework using `xcodebuild -create-xcframework`; do not claim hashes from
another machine until the actual bytes have been inspected and hashed.

## Final corresponding-source extension

Once the final application changes have been committed and the checkout is
clean, use the exact commit with the verified Lua input. The default prints a
manifest; `--execute` creates a new small source extension containing the tracked
application source and Lua archive, with a manifest referencing the older asset:

```sh
python3 "$package_dir/Tools/assemble_source_extension.py" \
  --repository "$repository_dir" --commit "$final_commit" \
  --lua-source "$lua_source" --output "$new_extension_asset"
```

Publish the original source asset and the actual final extension alongside the
binary, with their measured sizes/checksums and the exact final application
commit. Preserve upstream copyright/license notices, including both COPYING
files here and the application Notices. Packaging source does not establish
public availability, App acceptance or LGPL relinking/replacement verification.
Those are separate release gates in `docs/RELEASE.md`.
