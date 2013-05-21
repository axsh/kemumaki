#!/bin/bash

set -e
#set -x

. ./../config/rpmbuild.conf

function setup_chroot_dir() {
  distro_name="centos"
  distro_ver="6"
  distro_subver="3"

  distro_detail="${distro_name}-${distro_ver}.${distro_subver}"

  for distro_arch in ${archs}; do
    base_dir=${rpmbuild_tmp_dir}/chroot/base
    [ -d ${base_dir} ] || mkdir -p ${base_dir}
    cd ${base_dir}

    distro_dir=${rpmbuild_tmp_dir}/chroot/base/${distro_name}-${distro_ver}_${distro_arch}
    chroot_dir=${rpmbuild_tmp_dir}/chroot/dest/${distro_name}-${distro_ver}_${distro_arch}

    distro_targz_file=${distro_detail}_${distro_arch}.tar.gz
    [ -f ${distro_targz_file}            ] || curl -fkL -O http://dlc.wakame.axsh.jp.s3.amazonaws.com/demo/rootfs-tree/${distro_targz_file}
    [ -d ${distro_detail}_${distro_arch} ] || tar zxpf ${distro_targz_file}
    [ -d ${distro_dir}                   ] || mv ${distro_detail}_${distro_arch} ${distro_dir}

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
