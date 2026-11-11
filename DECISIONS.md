# DECISIONS.md

Log format: date, decision, reason.

## Decided
- Camera placement: propped-up phone, side-on, seeing the whole body. Reason: pose tracking needs the full body in frame to judge depth and body line.
- Server is the authority: the client never submits a trusted rep total. Reason: the phone can be modified.
- Video stays on device; only joint and angle data is uploaded. Reason: privacy and smaller uploads.
- Cheating is handled with flags and a suspicion score, not auto-bans, in the early phases. Reason: avoid punishing honest users for false positives.

- 2026-11-11: Mobile stack is Flutter with native ML Kit pose detection on both Android and iOS. Reason: identical landmarks and confidence scores across platforms; zero video frames passed to Dart (only landmarks).
- 2026-11-11: Server stack is Laravel (PHP) API with PostgreSQL. Rating engine is a pure, unit-tested service class inside the API. Reason: clean MVC architecture, robust transactions for rating updates, and identical DB behavior in development and production.
- 2026-11-11: Matches are turn-based / asynchronous for MVP, designed so live 1v1 can be added later without schema breaks. Each attempt requires a server-issued nonce and fixed submission window. Player B cannot see Player A's reps until B submits. Unaccepted challenges expire with no rating change. Reason: network resilience, simpler initial client sync, cheat-resistant blindness.
- 2026-11-11: Outcome resolution. Tie = equal valid reps = draw. An attempt starts when its nonce is consumed; started but not submitted within the window = forfeit (loss). Upload retries after a connection drop are allowed within the window and must be idempotent. Technical validation failures (low confidence, tracking loss) void the attempt and allow a retry within the window, with no score change. Clear cheat signals (nonce reuse, impossible timing, copied data) = loss plus a flag for review. Reason: protect honest players from false penalties while closing the "start, peek, abandon" loophole.
- 2026-11-11: Scoring model changed from Elo to cumulative Ego Score. Ego Score = lifetime total of server-validated reps (only reps the server recomputes as valid are counted; the client's own count is never used). Battles are timed with a fixed duration set in config; the player with the most valid reps when the timer ends wins, equal reps = draw. Battle reps also add to the Ego Score. Every attempt (battle or solo) starts with a server-issued nonce and has a fixed duration. Reason: simple, motivating, and the fixed timer closes the start-peek-abandon loophole.
- 2026-11-11: Revised battle win condition and Ego Rating back to Win/Loss Elo with a Tug-of-War Dominance Bar. (1) **Tug-of-War Progress Bar**: Starts at 50/50 (`0.5`). Each valid rep shifts the bar by `1 / (2 * knockout_lead_reps)` where `knockout_lead_reps = 15` in `config/thresholds.json`. Achieving a `+15` net rep lead fills the bar to `1.0` (`100%`) for an instant **KO Victory**; if neither player hits `+15` before `battle_timer_seconds` (60s), whoever holds more of the bar (`>50%`, most server-validated reps) wins by **Decision** (equal reps = Draw). (2) **Win/Loss Elo Ego Rating**: Ranking is driven by match Wins, Losses, and Draws using Elo math (`initial = 1000`, `scale = 400`, `K = 40` for first 10 provisional matches, `K = 24` thereafter, `floor = 100`, all in `config/thresholds.json`). Lifetime server-validated reps are tracked separately as a secondary career stat. Reason: "Defend Your EGO" requires real stakes where winning takes EGO from your rival and losing drops your rating, while the Tug-of-War bar turns head-to-head push-up battles into an interactive game.
- 2026-11-11: Beta distribution uses GitHub Pages (`deploy-pages.yml`) for the interactive Web Beta Hub (`/` landing + `/app/` Flutter Web build) and GitHub Releases (`release-apk.yml`) for downloadable Android APK/AAB builds with SHA-256 checksums, gated by `sync_thresholds.sh --check`, `flutter analyze`, and the 18-test unit/widget/E2E suite. Reason: allows immediate zero-install browser testing alongside direct Android APK installation for physical camera testing.

## Open (decide before building on them)
- Do solo (non-battle) reps count toward Ego Score?
- Timer length (config value)
- Weekly/monthly leaderboard resets so new players can compete
- Matchmaking basis (recent best result vs lifetime total)
- Max plausible reps per minute (config value, used for validation)
- Challenge expiry and submission-window durations (config values)
- Tiebreaker rule, if any
- Who can challenge whom (rating-gap limits, anti win-trading)
- One account per person / smurf prevention
- Confirm push-ups as the launch movement
- Minimum age and content rating
