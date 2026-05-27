#!/bin/bash
#
# Register RUSTFS_EU as an S3-compatible RSE in Rucio and wire it into
# the transfer mesh alongside MINIO1, MINIO2, and XRD3.
#
# https://rucio.github.io/documentation/operator/s3_rse_config/
#

# Register the RSE and set S3 protocol attributes
docker exec -i dev-rucio-1 /bin/bash <<END
rucio rse add RUSTFS_EU
rucio rse protocol add RUSTFS_EU --host rustfs --port 9003 --scheme https --prefix /rucio/ --impl rucio.rse.protocols.gfal.NoRename --domain-json '{"lan": {"read": 1, "write": 1, "delete": 1}, "wan": {"read": 1, "write": 1, "delete": 1, "third_party_copy_read": 1, "third_party_copy_write": 1}}'
rucio rse attribute add RUSTFS_EU --key sign_url --value s3
rucio rse attribute add RUSTFS_EU --key s3_url_style --value path
rucio rse attribute add RUSTFS_EU --key verify_checksum --value False
rucio rse attribute add RUSTFS_EU --key skip_upload_stat --value True
rucio rse attribute add RUSTFS_EU --key strict_copy --value True
rucio rse attribute add RUSTFS_EU --key fts --value https://fts:8446
rucio account limit add root --rse RUSTFS_EU --bytes infinity

# Connect RUSTFS_EU to the existing transfer mesh
rucio rse distance add RUSTFS_EU MINIO1 --distance 1
rucio rse distance add RUSTFS_EU MINIO2 --distance 1
rucio rse distance add RUSTFS_EU XRD3   --distance 1

rucio rse distance add MINIO1 RUSTFS_EU --distance 1
rucio rse distance add MINIO2 RUSTFS_EU --distance 1
rucio rse distance add XRD3   RUSTFS_EU --distance 1
END

# Append RUSTFS_EU credentials to rse-accounts.cfg.
# We re-read all three IDs so the file stays consistent if this script is
# re-run after qt-004 already wrote MINIO1/MINIO2 entries.
docker exec -i dev-rucio-1 /bin/bash <<'END'
ID1=$(rucio rse show MINIO1    | grep '^  id:' | awk '{print$2}')
ID2=$(rucio rse show MINIO2    | grep '^  id:' | awk '{print$2}')
ID3=$(rucio rse show RUSTFS_EU | grep '^  id:' | awk '{print$2}')
cat >/opt/rucio/etc/rse-accounts.cfg <<JSON
{
  "$ID1": {
    "access_key": "admin",
    "secret_key": "password",
    "signature_version": "s3v4",
    "region": "us-east-1"
  },
  "$ID2": {
    "access_key": "admin",
    "secret_key": "password",
    "signature_version": "s3v4",
    "region": "us-east-1"
  },
  "$ID3": {
    "access_key": "admin",
    "secret_key": "password",
    "signature_version": "s3v4",
    "region": "us-east-1"
  }
}
JSON
END
