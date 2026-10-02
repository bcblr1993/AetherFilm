# Real playback regression

Generate copyright-free fixtures with an existing ffmpeg:

```sh
python3 PlaybackTests/generate_fixtures.py
python3 PlaybackTests/generate_smb_fixture.py
python3 PlaybackTests/generate_4k_fixture.py
```

Include `.build/PlaybackFixtures` as a folder resource in the playback XCTest
target, or supply its absolute path with `AETHERFILM_FIXTURES`. The tests fail
when fixtures are missing. The fixtures contain synthetic video, sine-wave
audio, Chinese SRT/ASS subtitles and two MKV chapters; no user film is copied.

`FilmPlaybackTests` covers H.264/AAC MP4, HEVC/AAC MOV, MPEG-4/MP3 AVI,
multitrack MKV, decoder/video/audio output counters, pause, seek, rate, resume,
natural completion, track selection, embedded/external subtitle registration,
chapters, broken input, rapid switching and stop cleanup. External subtitles
cover SRT, ASS and WebVTT. Missing or unsupported subtitles report a separate,
recoverable error while video/audio output continues; successful retry and
opening another video clear that error. The separate 4K HEVC case checks actual decoding and
output; VideoToolbox hardware acceleration needs its own captured evidence.
Subtitle appearance,
Chinese glyphs/style, audible output and synchronization require rendered UI
and device acceptance in addition to these tests.

Run macOS UI acceptance in Tart `macos27`. Run the iOS target in a simulator
and on the intended real iPhone; simulator decoding does not prove hardware
decoding, audible output or 4K performance on that device.

The real SMB case uses the fixture launcher's private loopback SMB2 server and
the production `SMBProvider` / `SMBStreamingServer` with the real VLC player.
The 75-second video is large enough to verify output starts before full-file
reading. The case seeks ten times across the file, stops/reopens twice and
checks read bytes stop increasing after stream teardown. Run the launcher
with `--bootstrap-only --media-folder .build/PlaybackFixtures`, then pass only
`AETHERFILM_SMB_BOOTSTRAP_URL` through the Xcode test scheme. The test fetches
random credentials into memory; do not put passwords in `.xctestrun`, logs or
result bundles. This integration case explicitly skips if no fixture server
is configured; that skip is not SMB playback acceptance.

`run_smb_playback.py` makes a temporary `.xctestrun` copy beside the built
original and inserts only the non-secret bootstrap URL. It removes that copy
on exit. Use `--all-playback` for the entire playback/AppStore target, or omit
it for the SMB case alone. Example after `build-for-testing`:

```sh
/private/tmp/aetherfilm-smb-test-venv/bin/python scripts/test_smb_integration.py \
  --bootstrap-only --media-folder .build/PlaybackFixtures -- \
  python3 PlaybackTests/run_smb_playback.py \
  --xctestrun .build/iOSDerived/Build/Products/AetherFilm-iOS_iphonesimulator27.0-arm64.xctestrun \
  --destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  --result .build/results/SMB-playback-unique.xcresult --all-playback
```

Use the actual built `.xctestrun` filename and a fresh result path. Install
only the test requirements through the repository fixture setup instructions;
the test launcher binds to loopback and shuts down with the command.
