# ARCHITECTURE.md

Items marked **TO DECIDE** are not chosen yet. Record the choice in `DECISIONS.md` before building on it.

## Components
1. **Mobile app**: Flutter camera capture, UI shell, match flow.
2. **Pose module**: native ML Kit pose detection on Android and iOS. Only landmarks and confidence values pass to Dart; zero camera frames leave native memory.
3. **Rep engine**: Dart module calculating angles and managing the rep state machine, building per-rep records (`REP_COUNTING_SPEC.md`).
4. **API server**: Laravel (PHP 8.4) API handling matches, nonces, submissions, validation and score updates (`API_SPEC.md`).
5. **Database**: PostgreSQL storing players, matches, attempts, score histories, and flags.
6. **Config**: shared JSON config files for rep thresholds, battle timer length, and max rep limits.

## Data flow
```
Camera -> Pose module (ML Kit) -> Rep engine -> per-rep record (on device)
   -> upload with match nonce -> Laravel API
   -> server re-validates reps -> winner decided & Ego Score updated -> result to both players
```
Video frames never leave the device. Only the per-rep record is uploaded (`MATCH_DATA_FORMAT.md`).

## Suggested folder structure
```
pushgard/
  AGENTS.md
  README.md
  docs/
  mobile/
    app/            UI shell and match flow
    pose/           native ML Kit pose module bridge
    rep_engine/     angles, state machine, rep records
  server/
    api/            Laravel controllers and endpoints
    validation/     rep and match checks
    score/          Ego Score calculation and history
    tests/          unit and feature tests
  config/
    thresholds.*    rep and validation constants
    score.*         timer and score constants
```
Adjust to the chosen stack, then log the final structure in `DECISIONS.md`.

## Trust boundaries
- The phone is untrusted. It can be modified, so its rep total is never used as a result.
- The server is the authority for valid reps, winners and ratings.
- Nonces are issued by the server, single-use, and expire.

## Later phases (not built yet)
Attestation, challenge-response, shared Rust core and client hardening are listed in `ROADMAP.md`. Design the upload format so a signature field can be added later without breaking changes (see `MATCH_DATA_FORMAT.md` version field).
