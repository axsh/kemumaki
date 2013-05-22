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
vdc_branch=$2

[[ -d "${vdc_dir}" ]] || {
  echo "ERROR: repository not found: ${vdc_dir}" >/dev/stderr
  exit 1
}

release_id=$(cd ${vdc_dir} && rpmbuild/helpers/gen-release-id.sh)

(cd .. &&  git submodule update --init)

[[ -d ${rpm_dir} ]] && rm -rf ${rpm_dir}

for arch in ${archs}; do
  [[ -d "${rpmbuild_tmp_dir}" ]] || mkdir -p "${rpmbuild_tmp_dir}"
  (
    export repo_uri=$(cd ${vdc_dir}/.git && pwd)
    export build_id=$(cd ${vdc_dir} && git log -n 1 --pretty=format:"%h")
    export rpm_dir

    distro_name=centos
    distro_ver=6.4
    distro_arch=${arch}

    time setarch ${arch} \
     ../vmbuilder/kvm/rhel/6/vmbuilder.sh \
     --distro-name=${distro_name} \
     --distro-ver=${distro_ver}   \
     --distro-dir=${rpmbuild_tmp_dir}/chroot/base/${distro_name}-${distro_ver}_${distro_arch} \
     --execscript=$(pwd)/xexecscript.sh  \
     --hypervisor=null \
     --raw=${rpmbuild_tmp_dir}/${distro_name}-${distro_ver}_${distro_arch}.raw
  )
done

(
  cd ${rpm_dir}
  createrepo .
)

./gen-index-html.sh > ${rpm_dir}/index.html

[[ -d ${yum_repository_dir}/${vdc_branch} ]] || mkdir -p ${yum_repository_dir}/${vdc_branch}

(
  cd ${yum_repository_dir}/${vdc_branch}
  [[ -d ${release_id} ]] && rm -rf ${release_id}
  rsync -avx ${rpm_dir}/ ${release_id}
)

[[ -L ${yum_repository_dir}/${vdc_branch}/current ]] && rm ${yum_repository_dir}/${vdc_branch}/current
ln -s ${yum_repository_dir}/${vdc_branch}/${release_id} ${yum_repository_dir}/${vdc_branch}/current
