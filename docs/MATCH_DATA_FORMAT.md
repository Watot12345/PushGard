# MATCH_DATA_FORMAT.md — Specification v1.1

This document defines the schema for attempt uploads from the PushGard mobile app to the server.

---

## 1. Security & Authenticity Boundary (Non-Goal in v1.1)

> [!WARNING]
> **This format does not and cannot prove that uploaded samples originated from a genuine, live camera stream.**
> In Phase 1 and Phase 2, the format relies on client-reported raw geometric angles and timestamps. Hardware attestation (Apple DeviceCheck / App Attest, Google Play Integrity) and active liveness challenges (screen-flash spectral reflections) are strictly scheduled for later phases per `ROADMAP.md` and `PRODUCT_SPEC.md`.

---

## 2. Versioning & Supported-Versions Policy

* Format versioning follows `MAJOR.MINOR`.
* Backward-compatible additions (e.g., optional diagnostic metadata fields) increment `MINOR`.
* Breaking changes (e.g., renaming fields, changing coordinate systems or units) increment `MAJOR`.
* The server maintains an active whitelist of accepted format versions (currently `["1.1"]`).
* If an uploaded payload contains an unsupported version, the server rejects the request with `HTTP 426 Upgrade Required` including the minimum supported app and format versions.

---

## 3. Attempt Submission Payload Schema (v1.1)

```json
{
  "version": "1.1",
  "attempt_id": "01931ea4-82a1-7d12-9c94-1a80d418bc22",
  "match_id": "01931ea4-82a1-7d12-9c94-1a80d418bc23",
  "nonce": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "client": {
    "app_version": "1.0.0+1",
    "platform": "android",
    "device_model": "Pixel 7a",
    "pose_model_version": "mlkit-pose-fast-v1",
    "thresholds_hash": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
  },
  "metrics": {
    "body_side_selected": "right",
    "effective_fps": 28.4,
    "total_samples": 1704,
    "nominal_interval_ms": 33.3,
    "dropped_frame_gaps": [
      [14250, 14360]
    ]
  },
  "samples": [
    [0, 164.2, 4.8, 0.91],
    [35, 163.8, 5.1, 0.90],
    [71, 159.2, 5.5, 0.89],
    [106, 151.0, 6.2, 0.88],
    [1020, 84.1, 7.5, 0.84],
    [1850, 163.9, 5.0, 0.89]
  ],
  "client_claimed_reps": [
    {
      "rep_index": 1,
      "start_ms": 35,
      "bottom_ms": 1020,
      "top_ms": 1850,
      "min_elbow_angle": 84.1,
      "max_elbow_angle": 163.9,
      "valid": true,
      "reject_reason": null
    }
  ]
}
```

---

## 4. Field Definitions & Server Validation Rules

### 4.1 Authentication & Top-Level Identifiers
* **Authentication**: `player_id` is **never included in the JSON payload**. The server identifies the player exclusively via the authenticated Bearer token in the HTTP `Authorization` header.
* `version`: Must match an accepted version string (`"1.1"`).
* `attempt_id`: UUID issued by the server when the attempt was reserved.
* `match_id`: UUID of the 1v1 battle match; set to `null` if a solo training attempt.
* `nonce`: Single-use cryptographic nonce issued alongside `attempt_id`. The server verifies that the nonce has not been consumed and marks it consumed immediately upon validation.

### 4.2 Client Environment Block
* `client.app_version`: Client semver string.
* `client.platform`: `"android"` or `"ios"`.
* `client.device_model`: Hardware device identifier (e.g., `"Pixel 7a"`, `"iPhone14,2"`).
* `client.pose_model_version`: Underlying native ML Kit model identifier.
* `client.thresholds_hash`: SHA-256 hex digest of the canonical (normalized: sorted keys, no whitespace) `thresholds.json`. The server compares this against its own canonical hash. A mismatch flags the attempt for parameter divergence.

### 4.3 Metrics (Client Claims vs. Server Truth)
> [!NOTE]
> All fields under `metrics` are **untrusted client claims**. The server recomputes each metric directly from `samples` during validation. A significant discrepancy flags the attempt.
* `metrics.body_side_selected`: **Fixed per attempt.** The active side (`"left"` or `"right"`) is determined during the pre-start framing check based on higher joint confidence and locked for the entire attempt. Flipping sides mid-attempt is invalid because pushups are strictly side-on.
* `metrics.total_samples`: Count of items in `samples`. Recomputed by server as `count(samples)`.
* `metrics.effective_fps`: Client-claimed sample rate. Recomputed by server as:
  $$\text{effective\_fps} = \frac{\text{total\_samples} \times 1000}{t_{\text{last}} - t_0}$$
  Must be $\ge \text{min\_acceptable\_fps}$ (20.0 fps, aligned directly with the hardware spike fail line). An attempt below 20.0 fps lacks the temporal resolution to reliably detect reversal inflection points and is rejected with reason `LOW_FPS`.
* `metrics.nominal_interval_ms`: The median frame interval ($\text{median}(\Delta t_i)$) across the attempt.
* `metrics.dropped_frame_gaps`: Array of `[gap_start_ms, gap_end_ms]` intervals where:
  $$\Delta t_i > \text{gap\_multiplier} \times \text{nominal\_interval\_ms}$$
  The server independently re-scans `samples` to identify all gaps.

### 4.4 The Continuous Raw Angle Series (`samples`)
* $t = 0$: Defined as the **exact millisecond when the countdown ends and the battle timer starts**.
* Sample structure: Compact 4-element tuple `[t_ms, raw_elbow, raw_body, conf]`:
  1. `t_ms` (integer): Monotonic milliseconds elapsed since countdown completion ($t \ge 0$).
  2. `raw_elbow` (float): Unsmoothed, raw 3-point elbow angle in degrees ($\angle \text{shoulder-elbow-wrist}$).
  3. `raw_body` (float): Unsmoothed, raw body-line deviation in degrees ($\lvert \angle \text{shoulder-hip-ankle} - 180^\circ \rvert$).
  4. `conf` (float): Minimum joint confidence score across the 6 key joints of the active side for that frame.
* **Server Window Enforcing**:
  * The server checks that the final sample timestamp $t_{\text{last}}$ is near `battle_timer_seconds * 1000` (within allowable submission grace window).
  * Any samples recorded with $t > \text{battle\_timer\_seconds} \times 1000$ are **silently dropped** by the server before running the rep detection engine.

### 4.5 Client Claimed Reps (`client_claimed_reps`) & Reason Codes
* Optional array containing the reps and reject reasons displayed on the user's HUD during the match.
* **The server runs its own cycle-detection and rep validation algorithm on the raw `samples` array.** The client's count is never used to award reps.
* If $\text{valid\_reps}_{\text{server}} \neq \text{valid\_reps}_{\text{client}}$, the server logs a `COUNT_MISMATCH` flag for audit, but the server's recomputed count is the sole authority.

#### Standard Rep Rejection Reason Codes
| Reason Code | Definition / Threshold Trigger |
|---|---|
| `SHALLOW` | Minimum elbow angle at the bottom of the rep failed to reach depth (`min_elbow_angle > depth_elbow_angle_max`). |
| `NO_LOCKOUT` | Elbow angle at cycle completion failed to return to full extension (`max_elbow_angle < lockout_elbow_angle_min`). |
| `BODY_LINE` | Hip sag or pike deviation exceeded tolerance during the cycle (`max_body_line_deviation > body_line_tolerance`). |
| `LOW_CONFIDENCE` | Joint confidence on any key joint dropped below threshold (`min_confidence < min_joint_confidence`). |
| `TRACKING_GAP` | A dropped-frame gap ($\Delta t_i > \text{gap\_multiplier} \times \text{nominal\_interval}$) exceeding `max_allowed_gap_ms` (500ms) occurred during the cycle. |
| `TOO_FAST` | Rep cycle duration was shorter than physiological limit (`duration < min_rep_duration_seconds`). |
| `TOO_SLOW` | Rep cycle duration exceeded maximum allowed limit (`duration > max_rep_duration_seconds`). |
