# PRODUCT_SPEC.md

## What PushGard is
A mobile app where men challenge each other to head-to-head movement battles. Each player's performance is measured by the phone, validated by a server, and ranked with an Elo-style Win/Loss system called **Ego Rating** (starting at `1000 EGO`, with lifetime server-validated reps tracked as a career stat). During a battle, a live **Tug-of-War Progress Bar** starts at 50/50 and shifts with every valid rep: hitting a `+15` rep lead (`knockout_lead_reps` in `config/thresholds.json`) fills the bar to 100% for an instant **KO Victory**, or whoever holds more of the bar when the 60s timer ends wins by **Decision**. The brand tagline is "EGO RANKING — DEFEND YOUR EGO".

## Brand
- Name: PushGard
- Mark: shield with two upward chevrons
- Palette and typography: see `BRAND_GUIDE.md` (written when real UI work starts)

## Core user flow
1. Player signs in and sees their **Ego Rating** (Win/Loss Elo), Rank Shield tier, and Win Streak.
2. Player creates a match or accepts a challenge.
3. Both players get a countdown, started by the server.
4. Each player performs push-ups in front of a propped-up phone camera while driving the **Tug-of-War Bar** toward their rival's end.
5. The app tracks the movement on-device and builds the raw angle series.
6. Each phone uploads that data with the match nonce.
7. The server validates both submissions from raw angles and timestamps.
8. If both pass, the server determines the winner (by `+15` rep lead KO or highest valid rep count at 60s), updates both players' **Ego Rating** using Elo Win/Loss math, and increments their career valid reps.
9. Both players see the battle outcome (KO or Decision) and their Elo gain/loss (`+EGO` / `-EGO`).

## Scope of current phase
In scope:
- On-device rep counting from live camera pose tracking (`REP_COUNTING_SPEC.md`)
- Server that validates matches and updates Ego Score (`EGO_SCORE_SPEC.md`, `API_SPEC.md`)
- A basic test screen, not a polished UI

Out of scope (postponed, see `ROADMAP.md`):
- Hardware attestation (Play Integrity / App Attest)
- Screen-flash and random-hold challenges
- Rust shared core
- Anti-debugging and memory masking
- Polished UI, social features, leaderboards, payments

## Non-goals
- Perfect cheat-proofing. The goal is to make cheating more work than it is worth.
- Storing or sharing user video.

## Open product questions
Tracked in `DECISIONS.md` under "Open":
- Exact movement(s) supported at launch
- Live simultaneous matches vs turn-based submissions
- Disconnect and tie handling
- Minimum age and content rating
