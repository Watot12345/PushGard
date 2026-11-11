#!/usr/bin/env bash
set -euo pipefail

# PushGard Thresholds Canonicalization, Copy, and Verification Script
# Usage:
#   ./scripts/sync_thresholds.sh          # Synchronizes and copies canonical JSON
#   ./scripts/sync_thresholds.sh --check  # Verifies hashes in CI / pre-commit

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SOURCE="${REPO_ROOT}/config/thresholds.json"
MOBILE_TARGET="${REPO_ROOT}/mobile/assets/config/thresholds.json"
SERVER_TARGET="${REPO_ROOT}/server/config/thresholds.json"
HASH_FILE="${REPO_ROOT}/config/thresholds.hash"

MODE="sync"
if [[ "${1:-}" == "--check" || "${1:-}" == "--verify" ]]; then
  MODE="check"
fi

python3 - <<EOF
import json
import hashlib
import sys
import os

source_path = "${CONFIG_SOURCE}"
mobile_path = "${MOBILE_TARGET}"
server_path = "${SERVER_TARGET}"
hash_path = "${HASH_FILE}"
mode = "${MODE}"

if not os.path.exists(source_path):
    print(f"Error: Source thresholds file not found at {source_path}", file=sys.stderr)
    sys.exit(1)

with open(source_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Canonical JSON: keys sorted, compact separators without whitespace
canonical_bytes = json.dumps(data, sort_keys=True, separators=(',', ':')).encode('utf-8')
canonical_hash = hashlib.sha256(canonical_bytes).hexdigest()

if mode == "check":
    # CI / Pre-commit verification
    errors = []
    if not os.path.exists(hash_path):
        errors.append(f"Hash file missing: {hash_path}")
    else:
        with open(hash_path, 'r', encoding='utf-8') as f:
            expected_hash = f.read().strip()
        if expected_hash != canonical_hash:
            errors.append(f"Hash mismatch in {hash_path}! Expected: {expected_hash}, Calculated: {canonical_hash}")

    for target_path, label in [(mobile_path, "mobile"), (server_path, "server")]:
        if not os.path.exists(target_path):
            errors.append(f"Target missing for {label}: {target_path}")
        else:
            with open(target_path, 'rb') as f:
                target_bytes = f.read()
            target_hash = hashlib.sha256(target_bytes).hexdigest()
            if target_hash != canonical_hash:
                errors.append(f"File out of sync for {label} at {target_path} (hash: {target_hash})")

    if errors:
        print("FAIL: Threshold verification failed with errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        print("Run './scripts/sync_thresholds.sh' to re-synchronize.", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"PASS: All thresholds in sync. Canonical SHA-256: {canonical_hash}")
        sys.exit(0)

elif mode == "sync":
    # Copy mode
    os.makedirs(os.path.dirname(mobile_path), exist_ok=True)
    os.makedirs(os.path.dirname(server_path), exist_ok=True)

    with open(mobile_path, 'wb') as f:
        f.write(canonical_bytes)

    with open(server_path, 'wb') as f:
        f.write(canonical_bytes)

    with open(hash_path, 'w', encoding='utf-8') as f:
        f.write(canonical_hash + '\n')

    print(f"SUCCESS: Synchronized canonical thresholds to mobile and server targets.")
    print(f"Canonical SHA-256: {canonical_hash}")
EOF
