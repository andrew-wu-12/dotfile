# !/bin/bash
#

cache_dirs=('~/Library/Caches', '/var/log/')

for CACHE_DIR in "${cache_dirs[@]}"; do
  rm -rf CACHE_DIR
done

echo "Clean Cache Success!"
