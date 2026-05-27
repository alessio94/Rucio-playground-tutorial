#!/bin/bash

cd `dirname $0`

etc/certs/generate_minio12.sh
etc/certs/generate_rustfs.sh

docker compose \
  --file etc/docker/dev/docker-compose-qt.yml \
  --file etc/docker/dev/docker-compose-rustfs-override.yml \
  --profile storage up -d
