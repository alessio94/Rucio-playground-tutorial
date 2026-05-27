#!/bin/bash
#
# Print a compatibility matrix summarising what was tested against RUSTFS_EU.
# Run this after qt-013 to get a snapshot of pass/fail for each operation.
#

docker exec -i dev-rucio-1 /bin/bash <<'END'
python3 << 'PYEOF'
import subprocess, json, sys

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.stdout.strip(), r.returncode

PASS = "\033[32mPASS\033[0m"
FAIL = "\033[31mFAIL\033[0m"
UNKN = "\033[33m????\033[0m"

results = []

# --- PUT (direct upload) ---
out, rc = run("rucio list-file-replicas test:file_rustfs_a 2>/dev/null | grep RUSTFS_EU")
results.append(("PUT  (direct upload)",         PASS if out else FAIL,
                "replica present at RUSTFS_EU" if out else "no replica found"))

# --- GET (direct download) ---
out, rc = run("ls file_rustfs_a 2>/dev/null")
results.append(("GET  (direct download)",        PASS if rc == 0 else FAIL,
                "file downloaded" if rc == 0 else "file missing"))

# --- TPC (MINIO1 → RUSTFS_EU) ---
out, rc = run("rucio list-file-replicas test:file_tpc_to_rustfs 2>/dev/null | grep RUSTFS_EU")
results.append(("TPC  (MINIO1 → RUSTFS_EU)",     PASS if out else FAIL,
                "replica replicated" if out else "replication not complete"))

# --- Presigned URL ---
out, rc = run(
    "rucio list-file-replicas --protocols s3 test:file_rustfs_a 2>/dev/null"
    " | grep 'https://rustfs'"
)
if out:
    http, _ = run(
        f"curl -sk -o /dev/null -w '%{{http_code}}' {out.split()[0]!r}"
    )
    ok = http.strip() in ("200", "206")
    results.append(("URL  (presigned GET)",          PASS if ok else FAIL,
                    f"HTTP {http}" if http else "curl failed"))
else:
    results.append(("URL  (presigned GET)",          UNKN, "no signed URL generated"))

# --- Rule convergence ---
out, rc = run("rucio rule list --account root 2>/dev/null | grep RUSTFS_EU | grep -v OK")
results.append(("RULE (no stuck/failed rules)",   PASS if not out else FAIL,
                "all rules OK" if not out else f"stuck/failed rules:\n{out}"))

print()
print("=" * 65)
print(f"  RustFS Compatibility Matrix  (RSE: RUSTFS_EU)")
print("=" * 65)
print(f"  {'Operation':<30} {'Result':<12} Notes")
print(f"  {'-'*30} {'-'*12} {'-'*20}")
for op, status, note in results:
    print(f"  {op:<30} {status:<21} {note}")
print("=" * 65)
print()
PYEOF
END
