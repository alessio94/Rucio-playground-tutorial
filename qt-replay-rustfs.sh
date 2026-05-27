#!/bin/bash
# Run the full RustFS integration sequence end-to-end.
# Assumes the base testbed (qt-000 through qt-008) has already been completed.

cd `dirname $0`
for script in qt-010-rustfs-bucket.sh \
              qt-011-rustfs-rse.sh \
              qt-012-rustfs-fts-creds.sh \
              qt-013-rustfs-tests.sh \
              qt-014-rustfs-results.sh ; do
  echo ">>> $script"
  ./"$script"
  echo ""
done
