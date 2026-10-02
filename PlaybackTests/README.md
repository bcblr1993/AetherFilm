# Real playback regression

Generate copyright-free fixtures with an existing ffmpeg:

```sh
python3 PlaybackTests/generate_fixtures.py
```

Include `.build/PlaybackFixtures` as a folder resource in the playback XCTest
target, or supply its absolute path with `AETHERFILM_FIXTURES`. The tests fail
when fixtures are missing. The fixtures contain synthetic video, sine-wave
audio, Chinese SRT/ASS subtitles and two MKV chapters; no user film is copied.

`FilmPlaybackTests` covers H.264/AAC MP4, HEVC/AAC MOV, MPEG-4/MP3 AVI,
multitrack MKV, decoder/video/audio output counters, pause, seek, rate, resume,
natural completion, track selection, embedded/external subtitle registration,
chapters, broken input, rapid switching and stop cleanup. Subtitle appearance,
Chinese glyphs/style, audible output and synchronization require rendered UI
and device acceptance in addition to these tests.

Run macOS UI acceptance in Tart `macos27`. Run the iOS target in a simulator
and on the intended real iPhone; simulator decoding does not prove hardware
decoding, audible output or 4K performance on that device.
