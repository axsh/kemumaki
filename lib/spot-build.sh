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

(cd .. &&  git submodule update --init)

if [[ -d ${rpm_dir} ]]; then
  rm -rf ${rpm_dir}
fi
[[ -d "${rpmbuild_tmp_dir}" ]] || mkdir -p "${rpmbuild_tmp_dir}"

for arch in ${archs}; do
  distro_name=centos
  distro_ver=6.4
  distro_arch=${arch}

  (
    export build_id=$(cd ${vdc_dir} && git log -n 1 --pretty=format:"%h")
    export repo_uri=$(cd ${vdc_dir}/.git && pwd)

    setarch ${arch} \
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

release_id=$(cd ${vdc_dir} && rpmbuild/helpers/gen-release-id.sh)

(
  cd ${yum_repository_dir}/${vdc_branch}
  if [[ -d ${release_id} ]]; then
    rm -rf ${release_id}
  fi
  rsync -avx ${rpm_dir}/ ${release_id}
)

[[ -L ${yum_repository_dir}/${vdc_branch}/current ]] && rm ${yum_repository_dir}/${vdc_branch}/current
ln -s ${yum_repository_dir}/${vdc_branch}/${release_id} ${yum_repository_dir}/${vdc_branch}/current
