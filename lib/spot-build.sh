#!/bin/bash
#
# requires:
#   bash
#   rsync, tar, ls
#
set -e

. $(cd $(dirname ${BASH_SOURCE[0]}) && pwd)/../config/rpmbuild.conf

vdc_dir=$1
vdc_branch=${2:-master}

[[ -d "${vdc_dir}" ]] || {
  echo "ERROR: repository not found: ${vdc_dir}" >/dev/stderr
  exit 1
}

(cd ${abs_dirname} && git submodule update --init)

[[ -d ${rpm_dir} ]] && rm -rf ${rpm_dir}

for arch in ${archs}; do
  [[ -d "${rpmbuild_tmp_dir}" ]] || mkdir -p "${rpmbuild_tmp_dir}"
  (
    # for xexecscript.sh internal parameters
    export local_repo_path=$(cd ${vdc_dir}/.git && pwd)
    export rpm_dir

    # for vmbuilder.sh options
    distro_name=centos
    distro_ver=6.4
    distro_arch=${arch}

    raw_path=${rpmbuild_tmp_dir}/${distro_name}-${distro_ver}_${distro_arch}.raw

    time setarch ${arch} \
     ${abs_dirname}/vmbuilder/kvm/rhel/6/vmbuilder.sh \
     --swapsize=0 \
     --execscript=${abs_dirname}/lib/xexecscript.sh  \
     --hypervisor=null \
     --distro-name=${distro_name} \
     --distro-ver=${distro_ver}   \
     --distro-dir=${rpmbuild_tmp_dir}/chroot/base/${distro_name}-${distro_ver}_${distro_arch} \
            --raw=${raw_path}

    # make sure to remove working raw file
    [[ -f ${raw_path} ]] && rm ${raw_path}
  )
done

(
  cd ${rpm_dir}
  createrepo .
)

${abs_dirname}/lib/gen-index-html.sh > ${rpm_dir}/index.html

[[ -d ${yum_repository_dir}/${vdc_branch} ]] || mkdir -p ${yum_repository_dir}/${vdc_branch}
release_id=$(cd ${vdc_dir} && rpmbuild/helpers/gen-release-id.sh)

(
  cd ${yum_repository_dir}/${vdc_branch}
  [[ -d ${release_id} ]] && rm -rf ${release_id}
  rsync -avx ${rpm_dir}/ ${release_id}
)

[[ -d ${rpm_dir} ]] && rm -rf ${rpm_dir}

[[ -L ${yum_repository_dir}/${vdc_branch}/current ]] && rm ${yum_repository_dir}/${vdc_branch}/current
ln -s ${yum_repository_dir}/${vdc_branch}/${release_id} ${yum_repository_dir}/${vdc_branch}/current
