# SPIKE_RESULTS.md — Step 0: ML Kit Pose Benchmark on Mid-Range Android

**Target Profile**: Mid-range Android (Android 12+, CameraX Hardware Level $\ge$ LIMITED, ML Kit Pose Detection in Stream Mode).  
**Test Protocol**: 60-second continuous push-up session in side-on position (phone propped up on floor, full body in frame).

---

## 1. Measured Architecture & Camera Pipeline
* **Video Frames**: Processed directly in native memory via `ImageAnalysis` analyzer (`com.google.mlkit:pose-detection:18.0.0-beta5`). **Zero video frames touch Dart memory.**
* **Preview**: Drawn via hardware `SurfaceTexture` directly on GPU using Flutter `Texture` widget.
* **Landmarks Stream**: Native code dispatches only 33 3D coordinates and `inFrameLikelihood` floats over Flutter `EventChannel`.
* **Stability Measure**: Evaluates bone length variation coefficient $\frac{\sigma(L)}{\mu(L)}$ for upper arm, forearm, and torso to measure rigid skeleton stability and 2D perspective distortion.

---

## 2. Pass / Fail Benchmark Criteria

| Metric | Pass Target | Hard Fail Line | Measured Result | Status |
|---|---|---|---|---|
| **Sustained Effective FPS** (over 60s continuous pushups) | $\ge 25.0\text{ fps}$ | $< 20.0\text{ fps}$ | *[PENDING DEVICE RUN]* | Pending |
| **Prone Landmark Dropout Rate** (frames with key joint likelihood $< 0.60$) | $< 5.0\%$ of frames | $> 10.0\%$ of frames | *[PENDING DEVICE RUN]* | Pending |
| **Bottom-Position Confidence** (shoulder, elbow, wrist at maximum depth) | $\ge 0.60$ on all 3 joints | $< 0.50$ (tracking lost at bottom) | *[PENDING DEVICE RUN]* | Pending |
| **Thermal / Rate Stability** | FPS drop $< 10\%$ over 60s | Drop $> 20\%$ | *[PENDING DEVICE RUN]* | Pending |
| **Bone-Length Variation ($\frac{\sigma}{\mu}$)** | $\le 8.0\%$ across reps | $> 15.0\%$ (severe distortion) | *[PENDING DEVICE RUN]* | Pending |

---

## 3. How to Run the Benchmark on Device

1. Connect your mid-range Android phone via USB or Wireless ADB (`adb devices`).
2. Run the spike harness:
   ```bash
   cd mobile
   flutter run -d <your-device-id>
   ```
3. Grant camera permission.
4. Prop the phone up on the floor, side-on, showing full body in push-up position.
5. Tap **"START 60s PUSH-UP BENCHMARK"** and perform push-ups for 60 seconds.
6. The test auto-stops at 60s, computes all raw metrics, and presents a dialog.
7. Tap **"Copy JSON"** and paste the raw output into this document.

---

## 4. Raw Metrics Log

```json
{
  "device_model": "[Pending execution on connected device]",
  "duration_seconds": "60.0",
  "total_samples": 0,
  "effective_fps": "0.0",
  "median_interval_ms": "0.0",
  "gap_count": 0,
  "dropout_rate_pct": "0.0",
  "bone_length_variation_pct": {
    "upper_arm": "0.0",
    "forearm": "0.0",
    "torso": "0.0"
  },
  "confidence_at_bottom": {
    "shoulder": "0.0",
    "elbow": "0.0",
    "wrist": "0.0",
    "hip": "0.0"
  },
  "confidence_at_top": {
    "shoulder": "0.0",
    "elbow": "0.0",
    "wrist": "0.0",
    "hip": "0.0"
  }
}
```

---

## 5. Decision & Next Steps
* Awaiting raw device numbers. If all metrics meet the Pass Target, we proceed to **Step 2 (Shared Fixtures)** and **Step 3 (Cycle State Machine)**.
* If any metric falls below the pass line, apply the valid ML Kit options (e.g. 480p target resolution, STREAM_MODE) per the fallback plan before proceeding.
