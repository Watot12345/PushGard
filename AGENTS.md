# AGENTS.md — Rules for the coding agent

Read this file at the start of every session. Then read `docs/TASKS.md` to see the current phase.

## Project
PushGard is a mobile app where men battle head-to-head and are ranked with an Elo-style system called **Ego Rating**. Movement is detected on the phone and validated on a server. See `docs/PRODUCT_SPEC.md`.

## Working rules
1. **Plan first.** Before creating or restructuring files, post a short plan (folders, libraries, data formats) and wait for approval.
2. **Stay in the current phase.** Only work on what `docs/TASKS.md` marks as current. Do not build later-phase features (attestation, screen-flash challenge, Rust core, anti-debugging, memory masking) unless told to.
3. **The server never trusts a client rep count.** The client uploads per-rep movement data; the server recomputes valid reps itself.
4. **No hard-coded thresholds.** Angles, depths, confidence limits, timing limits, K-factors and similar values live in one config file with comments.
5. **Live camera only.** No gallery access, no video-file input.
6. **Video stays on the device.** Only joint/angle data is uploaded. Never upload or store camera frames.
7. **Flag, don't ban.** Suspicious matches get flags and a suspicion score. Nothing auto-bans a player.
8. **Log decisions.** Any non-obvious choice goes in `docs/DECISIONS.md` with the date and reason.
9. **Ask, don't guess.** If a spec is ambiguous or you think it is wrong, say so and ask.
10. **Test what you build.** Rating math and server validation need unit tests before a phase is marked done.
11. **Summarize after each major piece.** State what changed, what is untested, and what is next.

## Definition of done for a task
- Code runs and tests pass.
- Config values are documented.
- `docs/TASKS.md` is updated.
- Anything undecided is listed under "Open" in `docs/DECISIONS.md`.
