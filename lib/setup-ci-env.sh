#!/bin/bash

set -e
#set -x

. ./../config/rpmbuild.conf

function setup_chroot_dir() {
  distro_name="centos"
  distro_ver="6"

  for distro_arch in ${archs}; do
    distro_dir=${rpmbuild_tmp_dir}/chroot/base/${distro_name}-${distro_ver}_${distro_arch}
    chroot_dir=${rpmbuild_tmp_dir}/chroot/dest/${distro_name}-${distro_ver}_${distro_arch}

    ../vmbuilder/kvm/rhel/6/vmbuilder.sh \
      --distro-name=${distro_name} \
      --distro-ver=${distro_ver}   \
      --distro-dir=${distro_dir}   \
      --chroot-dir=                \
      --hypervisor=null            \
      --raw=${chroot_dir}.raw

    [[ -d "${chroot_dir}" ]] || mkdir -p ${chroot_dir}
    rsync -ax --delete ${distro_dir}/ ${chroot_dir}/
  done
}

case $1 in
setup_chroot_dir)
  (cd .. &&  git submodule update --init)
  $1
  ;;
esac
