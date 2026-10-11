# Changelog

All notable changes to **SkinScope for Lightroom Classic** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] - 2026-10-11

### 🚀 Major Highlights

- **Intent-Based Filmstrip Culling (`⚡ Apply & Next ▶`)**:
  - Instead of statically copying numeric slider values across photos, SkinScope carries forward your chosen **grading intent** (Complexion Target, Lock status, Sun Tan, Mood/Look, and preferred High/Mid/Low Exposure tier).
  - Each photo in the sequence is individually sampled and dynamically solved to achieve the exact target look under its own specific lighting and flash exposure.
  - Exposure tier preference (Low, Mid, High) is now persistently remembered across navigation.

- **Native Lightroom Speed & Zero-Lag Navigation**:
  - **Asynchronous Develop Readings**: Initial photo metadata and develop parameters are read directly from Lightroom's database, eliminating the multi-second UI pause previously spent waiting for Develop side panels to load.
  - **Debounced Background Sampling (0.15s)**: Rapid sequential navigation clicks (`Next ▶` / `◀ Prev`) immediately cancel pending in-flight sampling passes, preventing background task backlogs and queue stalls.
  - **Filtered Filmstrip Respect**: Navigation strictly follows the active filtered filmstrip view (e.g. rated, flagged, or filtered subsets) rather than jumping to filtered-out raw files.

- **Persistent Python Sampling Daemon**:
  - On Windows and macOS, the raw pixel sampling engine now runs as a persistent background daemon resident in memory.
  - Eliminates cold-start Python process spin-up latency on every photo transition.

- **Complexion Lock (`🔒` / `🔓`)**:
  - Added a dedicated Lock toggle button directly beside the Complexion dropdown.
  - Prevents accidental profile switches caused by Windows Win32 ComboBox mouse-wheel and trackpad scrolling gestures while browsing the HUD.

### 🎨 Color Science & UI Enhancements

- **Dynamic Before/After Swatch (`◀ Prior / Live / Target`)**:
  - Swatch shows unedited baseline (Prior) stacked against active live adjustments and target color posts without black borders.
- **Architectural Documentation**:
  - Added comprehensive Intent-Based Auto-Grading & Filmstrip Workflow sequence diagram to `SPECIFICATION.md`.

---

## [1.0.0] - 2026-09-19

### Initial Release

- **ITU-R BT.709 Vectorscope Engine**:
  - Real-time $YC_bC_r$ coordinate mapping and hue angle ($\theta$) tracking against the universal Human Skin Tone Line ($\approx 124.5^\circ$).
- **8 Plain-English Complexion Standards**:
  - Calibrated reference profiles based on Alexis Van Hurkman’s *Color Correction Handbook* (Porcelain, Fair European, East Asian, Olive, Brown Light, Brown Medium, Brown Deep, Deep Melanin).
- **Luma-Normalized Saturation Formula**:
  - Completely exposure-invariant chroma-to-luma evaluation.
- **Photographic Dead-Band Controller**:
  - Natural skin saturation band ($19\% - 28\%$) preventing oversaturation and spray-tan artifacts.
- **3-Way Logarithmic EV Snapping**:
  - Low-Key, Balanced Mid, and High-Key exposure auto-calibration buttons.
- **344px Real-Time Floating HUD**:
  - Matches Lightroom Classic side-panel footprint with seamless live preview swatches.
