# REP_COUNTING_SPEC.md

All numeric values below are **starting points to tune with real testing**. They must live in the config file, never in code.

## Setup assumptions
- Phone is propped up on the floor or a stand, **side-on**, so the whole body is in frame.
- Live camera only. No gallery or video-file input.
- Lighting and distance guidance is shown before the countdown.

## Tracked joints
Shoulder, elbow, wrist, hip, knee, ankle on the visible side of the body. Each joint has a position and a confidence score from the pose model.

## Derived measurements (per frame)
- **Elbow angle**: shoulder-elbow-wrist
- **Body-line angle**: shoulder-hip-ankle (deviation from a straight line)
- **Joint confidence**: minimum confidence across the joints used

## Rep state machine
```
TOP (arms locked out)
  -> DESCENDING (elbow angle decreasing)
  -> BOTTOM (elbow angle at or below depth threshold)
  -> ASCENDING (elbow angle increasing)
  -> TOP (elbow angle at or above lockout threshold)  => rep complete
```
A rep is **valid** only if every condition below passes during that cycle.

## Validity conditions
| Condition | Starting value | Config key |
|---|---|---|
| Bottom elbow angle at or below | 90 degrees | `depth_elbow_angle_max` |
| Top elbow angle at or above | 160 degrees | `lockout_elbow_angle_min` |
| Body-line deviation at most | 15 degrees | `body_line_tolerance` |
| Min joint confidence on every frame of the rep | 0.6 | `min_joint_confidence` |
| Min rep duration | 0.5 s | `min_rep_duration` |
| Max rep duration | 8 s | `max_rep_duration` |

Rejected reps are recorded with a reason code (`SHALLOW`, `NO_LOCKOUT`, `BODY_LINE`, `LOW_CONFIDENCE`, `TOO_FAST`, `TOO_SLOW`) and do not count.

## Handling bad tracking
- If key joints drop below the confidence limit, pause counting and show a "reposition" prompt.
- Smooth angles with a short filter (e.g. moving average over a few frames) so jitter does not cause false state changes. The filter window is a config value.
- Use hysteresis (separate enter and exit thresholds) so hovering near a threshold does not flip states.

## Output per rep
For each rep (valid or rejected), record:
- `rep_index`
- `start_ts`, `bottom_ts`, `top_ts` (milliseconds from match start)
- `min_elbow_angle`, `max_elbow_angle`, `max_body_line_deviation`
- `min_confidence`
- `valid` (boolean) and `reject_reason` if invalid
- A sampled `angle_series`: timestamped elbow and body-line angles at a fixed rate

Exact field names and types are defined in `MATCH_DATA_FORMAT.md`.

## Not counted as the result
The on-device valid-rep count is for live display only. The server recomputes valid reps from the uploaded data.

## Testing checklist (manual)
- Full clean reps
- Half reps (shallow)
- No lockout at top
- Sagging hips and piked hips
- Poor lighting, partial body out of frame
- Phone too close or too far
- Different body sizes and clothing
- Phone bumped mid-set
Tune thresholds from these tests, and log changes in `DECISIONS.md`.
