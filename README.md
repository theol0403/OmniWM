# Real workspace-bar recordings

Review media for the animation-only PR in theol0403/OmniWM, code commit `322e400272a8a64fe8a2c3813d21102abc36ae6a`.

These are ScreenCaptureKit recordings of the actual installed OmniWM Dev app. Only the native workspace-bar window is captured; there is no substitute UI, generated imagery, simulated icon set, audio, or document content.

- **Switching:** ordinary workspace changes and rapid reversals. The MP4 and new animated PNG both retain all 170 captured frames. The replaced GIF had only 42.
- **Resizing:** the real bar shrinks and recenters when an empty temporary TextEdit window exits. The three-second MP4 excerpt retains all 17 captured frames, as does the new animated PNG; the replaced GIF had only 6. Only idle lead/tail was trimmed from the original 30.027858-second capture.

`workspace-bar-preview.png` is the full-frame animated preview. It is lossless relative to the normalized actual capture pixels, and independent decoding verified every frame. It uses changed-pixel rectangles to reduce file size without removing frames or changing the resulting image. `preview-processing.json` records source hashes and frame timing; `preview-verification.json` records independent decoded checks.

The previews use an 11ms minimum frame delay to avoid [Chromium's 100ms clamp for animated-image delays of 10ms or less](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/graphics/deferred_image_decoder.cc#L301-L306). This adds 10.533ms across the entire switching preview and 1.917ms across resizing. No frames are synthesized, interpolated, or skipped. Longer source gaps are preserved. The original MP4s are unchanged and retain the exact source presentation timing; use them for timing review.

The fixed crop contains actual panel pixels at the display's original scale. Black outside the panel represents uncaptured pixels. Recorded ScreenCaptureKit content scaling is reversed; missing detail is not reconstructed. Spatial resolution remains 1188×60 for switching and 1240×60 for resizing.

These recordings demonstrate behavior, not a renderer FPS guarantee. Typical ordinary-transition capture intervals are about 18ms, but rapid switching has larger gaps. Viewer scheduling and background-tab throttling can also affect playback.

The executable SHA256 is `3660892b2c75b2b099ad1cf1a2e5ca67c4bcda01315fd2dfd89fbc0c7e342695`. Provenance and original encoding checks accompany each clip. The original video manifest includes historical GIF-export statistics; current preview statistics are in preview-processing.json. Raw IPC data, document titles, desktop images, global screen coordinates, synthetic demos, and unsuccessful captures are excluded.
