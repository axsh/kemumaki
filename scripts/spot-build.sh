#!/bin/bash
#
# requires:
#   bash
#   rsync, tar, ls
#
set -e
#set -x

. ./../config/rpmbuild.conf

vdc_dir=$1
[[ -d ${vdc_dir} ]] || {
  echo "ERROR: repository not found: ${vdc_dir}" >/dev/stderr
  exit 1
}

vdc_build_id=$(cd ${vdc_dir} && git log -n 1 --pretty=format:"%h")

[[ $UID -ne 0 ]] && {
  echo "ERROR: Run as root" >/dev/stderr
  exit 1
}

release_id=$(cd ${vdc_dir} && rpmbuild/helpers/gen-release-id.sh)
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

time REPO_URI=$(cd ${vdc_dir}/.git && pwd) VDC_BUILD_ID=${vdc_build_id} ./rules clean rpm

[[ -d ${rpm_dir} ]] &&  rmdir -p ${rpm_dir} || :
time ./createrepo-vdc.sh

[[ -d ${yum_repository_dir}/master ]] || mkdir -p ${yum_repository_dir}/master

(
  cd ${yum_repository_dir}/master
  [[ -d ${release_id} ]] && rm -rf ${release_id} || :
  rsync -avx ${rpm_dir}/ ${release_id}

  tar zcvpf ${release_id}.tar.gz ${release_id}
  ls -la ${release_id}.tar.gz
)

[[ -L ${yum_repository_dir}/current ]] && rm ${yum_repository_dir}/current
ln -s ${yum_repository_dir}/master/${release_id} ${yum_repository_dir}/current
