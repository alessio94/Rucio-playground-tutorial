#!/bin/bash
#
# Run upload, download, third-party copy, and presigned-URL tests against
# RUSTFS_EU.  Tests are deliberately unchanged from the MinIO equivalents so
# any failure reveals a RustFS compatibility gap rather than a test quirk.
#
# https://github.com/rucio/k8s-tutorial#create-initial-transfer-testing-data
#

echo "=== [1/4] Direct upload to RUSTFS_EU ==="
docker exec -i dev-rucio-1 /bin/bash <<END
dd if=/dev/urandom of=file_rustfs_a bs=10M count=1
dd if=/dev/urandom of=file_rustfs_b bs=10M count=1

rucio upload --rse RUSTFS_EU --scope test file_rustfs_a
rucio upload --rse RUSTFS_EU --scope test file_rustfs_b

rucio did add --type dataset test:dataset_rustfs
rucio did content add -to test:dataset_rustfs test:file_rustfs_a test:file_rustfs_b

rucio list-file-replicas test:file_rustfs_a
END

echo ""
echo "=== [2/4] Direct download from RUSTFS_EU ==="
docker exec -i dev-rucio-1 /bin/bash <<END
rucio download --rse RUSTFS_EU test:file_rustfs_a
ls -lh file_rustfs_a
END

echo ""
echo "=== [3/4] Third-party copy: MINIO1 → RUSTFS_EU ==="
docker exec -i dev-rucio-1 /bin/bash <<END
# Upload a fresh file to MINIO1, then replicate it to RUSTFS_EU via FTS TPC
dd if=/dev/urandom of=file_tpc_to_rustfs bs=10M count=1
rucio upload --rse MINIO1 --scope test file_tpc_to_rustfs

rucio did add --type dataset test:dataset_tpc_rustfs
rucio did content add -to test:dataset_tpc_rustfs test:file_tpc_to_rustfs

rucio rule add test:dataset_tpc_rustfs --copies 1 --rses RUSTFS_EU

rucio rule list --account root

rucio-judge-evaluator  --run-once
rucio-conveyor-submitter --run-once
rucio-conveyor-poller  --run-once --older-than 0
rucio-conveyor-finisher --run-once

echo "--- Rule status after TPC run ---"
rucio rule list --account root

echo "--- Replica locations for file_tpc_to_rustfs ---"
rucio list-file-replicas test:file_tpc_to_rustfs
END

echo ""
echo "=== [4/4] Presigned URL (signurlarity) test ==="
docker exec -i dev-rucio-1 /bin/bash <<END
# Generate a presigned GET URL for a file on RUSTFS_EU and fetch it
SIGNED=\$(rucio list-file-replicas --protocols s3 test:file_rustfs_a \
         | awk '/https:\/\/rustfs/{print \$1}' | head -1)
if [ -z "\$SIGNED" ]; then
  echo "WARN: no presigned URL returned — sign_url attribute may not be working"
else
  echo "Presigned URL: \$SIGNED"
  curl -sk -o /dev/null -w "HTTP %{http_code}  size=%{size_download}B\n" "\$SIGNED"
fi
END
