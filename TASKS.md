# TASKS.md

Update this file as work is completed. Only work on the **current phase**.

## Phase 0: Decisions (completed)
- [x] Choose mobile stack (log in DECISIONS.md)
- [x] Choose server language, framework and database
- [x] Decide live vs turn-based matches
- [x] Decide disconnect and tie handling
- [x] Agent posts a plan and it is approved

## Phase 1: Rep counter (current)
- [x] Draft MATCH_DATA_FORMAT.md (v1.1 schema, continuous raw series, reason codes including TRACKING_GAP)
- [x] Shared config/thresholds.json (canonical thresholds, copy script, and pre-commit/CI hash verification)
- [ ] Step 0: Spike native ML Kit pose module on mid-range Android phone and report SPIKE_RESULTS.md
- [x] Shared test fixtures (hand-derived multi-rep, reversal, gap, and edge-case attempts for Dart and PHP)
- [x] Angle calculation, auto-selection of body side by joint confidence, and EMA smoothing
- [x] Rep state machine with hysteresis, monotonic relative timestamps, and dropped frame gap recording
- [x] Per-rep record builder matching MATCH_DATA_FORMAT.md
- [x] Simple on-screen framing check (full body visible, side-on) on test screen
- [ ] Manual test checklist run on real people

## Mobile UI/UX Structure & Beta Release Setup (completed)
- [x] Theme tokens & design system matching `Pushgard — Logo & App Icon.pdf` (Carbon Black `#0B0B0F`, Dark Slate `#1B1A26`, Volt Lime `#D4FF2A`)
- [x] Official brand assets & launcher icons (`assets/pushgard-*.svg`, Android `mipmap-*`, Web PWA icons)
- [x] Home Screen, Framing Check (`GET READY`), Live Battle HUD (`Tug-of-War` +15 KO Bar), Result Screen, Ranks & Battle Log, and Profile/Sensor Calibration
- [x] Unit & E2E Beta Tester User Journey Suite (`18/18` passing: 8 kinematic fixtures + 7 Elo/Tug-of-War/UI tests + 3 E2E user journey tests)
- [x] GitHub Pages Beta Hub (`web-portal/index.html` + live `/app/` Flutter Web build via `.github/workflows/deploy-pages.yml`)
- [x] GitHub Releases Android APK/AAB pipeline (`.github/workflows/release-apk.yml` + `scripts/prepare_release.sh`)

## Phase 2: Server and score
- [ ] Create match and nonce endpoints
- [ ] Submit match endpoint with validation (including Tug-of-War +15 rep lead KO timestamp check)
- [ ] Win/Loss Elo Ego Rating calculation & history logic with unit tests
- [ ] Fetch scores, league bracket & match history endpoint

## Later (do not start yet)
See ROADMAP.md.
