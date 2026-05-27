#!/bin/bash
#
# Create the "rucio" bucket in the RustFS instance.
# mc (MinIO client) is invoked from the dev-minio-1 container, which
# is on the same Docker network as rustfs and already has mc installed.
#

docker exec -i dev-minio-1 /bin/bash <<END
export MC_INSECURE=true
mc alias set rustfs https://rustfs:9003 admin password
mc mb rustfs/rucio
mc ls rustfs/
END
