#!/bin/bash
#
# Register RustFS S3 credentials in FTS3 and update the GFAL2 s3.conf so
# that FTS-mediated third-party copies (presigned-URL mode) work for RUSTFS_EU.
#
# https://docs.egi.eu/users/tutorials/adhoc/data-transfer-object-storage/
# https://fts3-docs.web.cern.ch/fts3-docs/docs/s3_support.html
#

docker exec -i dev-fts-1 /bin/bash <<'END'
# Register rustfs as a cloud storage backend in FTS3
curl \
  --cert /etc/grid-security/hostcert.pem \
  --key /etc/grid-security/hostkey.pem \
  --capath /etc/grid-security/certificates \
  https://fts:8446/config/cloud_storage \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"storage_name":"S3:rustfs"}'

curl \
  --cert /etc/grid-security/hostcert.pem \
  --key /etc/grid-security/hostkey.pem \
  --capath /etc/grid-security/certificates \
  https://fts:8446/config/cloud_storage \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"user_dn":"/CN=Rucio User","storage_name":"S3:rustfs","access_token":"admin","access_token_secret":"password"}'

# Rewrite GFAL2 s3.conf to include all three S3 backends.
# The section name [S3:<hostname>] is matched by GFAL2 against the URL host.
cat >/etc/gfal2.d/s3.conf <<INI
[S3:MINIO1]
ACCESS_KEY=admin
SECRET_KEY=password
REGION=us-east-1
ALTERNATE=true

[S3:MINIO2]
ACCESS_KEY=admin
SECRET_KEY=password
REGION=us-east-1
ALTERNATE=true

[S3:rustfs]
ACCESS_KEY=admin
SECRET_KEY=password
REGION=us-east-1
ALTERNATE=true
INI
END
