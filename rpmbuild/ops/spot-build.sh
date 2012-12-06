#!/bin/bash
#
# requires:
#   bash
#   rsync, tar, ls
#
set -e
set -x

. ./config_s3.env

release_id=$(../helpers/gen-release-id.sh)

[[ -d ${rpm_dir} ]] || mkdir -p ${rpm_dir}

[[ $UID -ne 0 ]] && {
  echo "ERROR: Run as root" >/dev/stderr
  exit 1
}

[[ -f ${release_id}.tar.gz ]] && {
  echo "already built: ${release_id}" >/dev/stderr
  exit 1
}

exec 2>${release_id}.err

time ./rules clean rpm

time ./createrepo-vdc.sh

[[ -d ${release_id} ]] && rm -rf ${release_id} || :
rsync -avx ${rpm_dir} ${release_id}

tar zcvpf ${release_id}.tar.gz ${release_id}
ls -la ${release_id}.tar.gz
