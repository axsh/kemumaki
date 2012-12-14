#!/bin/bash
#
# requires:
#   bash
#   rsync, tar, ls
#
set -e
set -x

. ./config_s3.env

abs_dirname=$(cd $(dirname $0) && pwd)
vdc_repo_dir=$1
[[ -d ${vdc_repo_dir} ]] || {
  echo "ERROR: repository not found: ${vdc_repo_dir}" >/dev/stderr
  exit 1
}

checkout_target=$2
[[ -n ${checkout_target} ]] && (cd ${vdc_repo_dir} && git checkout ${checkout_target})

vdc_build_id=$(cd ${vdc_repo_dir} && git log -n 1 --pretty=format:"%h")

[[ $UID -ne 0 ]] && {
  echo "ERROR: Run as root" >/dev/stderr
  exit 1
}

release_id=$(${vdc_repo_dir}/rpmbuild/helpers/gen-release-id.sh)
[[ -f ${release_id}.tar.gz ]] && {
  echo "already built: ${release_id}" >/dev/stderr
  exit 0
} || :

# exec 2>${release_id}.err
#
# Jenkins reported following errors.
#
# + exec
# Build step 'Execute shell' marked build as failure
# Finished: FAILURE

time REPO_URI=$(cd ${vdc_repo_dir}/.git && pwd) VDC_BUILD_ID=${vdc_build_id} ./rules clean rpm

[[ -d ${rpm_dir} ]] &&  mkdir -p ${rpm_dir} || :
time ./createrepo-vdc.sh

#[[ -d ${release_id} ]] && rm -rf ${release_id} || :
#rsync -avx ${rpm_dir} ${release_id}
#
#tar zcvpf ${release_id}.tar.gz ${release_id}
#ls -la ${release_id}.tar.gz
