# Real workspace-bar recordings

Review media for the animation-only PR in theol0403/OmniWM, code commit `322e400272a8a64fe8a2c3813d21102abc36ae6a`.

These are ScreenCaptureKit recordings of the actual installed OmniWM Dev app on macOS. Only the native workspace-bar window is captured. There is no substitute UI, generated imagery, overlaid demo bar, simulated icon set, audio, or document content.

- **switching/workspace-bar.mp4**: normal workspace switches followed by rapid reversals. All 170 captured frames retain their original presentation timing.
- **resizing/workspace-bar.mp4**: the native bar shrinks and recenters after quitting an empty temporary TextEdit window. This is a three-second excerpt (8.5–11.5 seconds) of a 30.027858-second capture. All 17 captured frames and all transition timing are preserved; only idle lead/tail is trimmed.

GIFs are lower-cadence previews; use the MP4 files to review motion. Each fixed crop contains original panel pixels at the display's original pixel scale. Black outside the panel represents uncaptured pixels, and transparent pixels are composited for H.264. Recorded ScreenCaptureKit content scaling is reversed during encoding; no missing visual detail or intermediate frames are synthesized.

The recordings show actual behavior, not a renderer FPS measurement. ScreenCaptureKit omitted unchanged frames and also delivered uneven intervals during switching (up to 1.257 seconds); these gaps are preserved. The clips do not establish continuous 60/120fps smoothness.

The executable SHA256 is `3660892b2c75b2b099ad1cf1a2e5ca67c4bcda01315fd2dfd89fbc0c7e342695`. Sanitized provenance, per-frame timing/hashes, and independent decoded-video checks accompany each clip. Raw IPC data, document titles, desktop images, and global screen coordinates are not published. Earlier rejected synthetic demos and unsuccessful captures are excluded.
