#!/bin/bash
# rpm build script

set -e

. ./../config/rpmbuild.conf

args=
while [ $# -gt 0 ]; do
  arg="$1"
  case "${arg}" in
    --*=*)
      key=${arg%%=*}; key=$(echo ${key##--} | tr - _)
      value=${arg##--*=}
      eval "${key}=\"${value}\""
      ;;
    *)
      args="${args} ${arg}"
      ;;
  esac
  shift
done

distro_name=centos
distro_ver=6
distro_arch=$(arch)
# spot-build.sh sets "repo_uri" parameter.
repo_uri=${repo_uri:-git://github.com/axsh/wakame-vdc.git}

[[ $UID -ne 0 ]] && {
  echo "ERROR: Run as root" >/dev/stderr
  exit 1
}

[[ -d "$rpmbuild_tmp_dir" ]] || mkdir -p "$rpmbuild_tmp_dir"

chroot_dir=${rpmbuild_tmp_dir}/chroot/dest/${distro_name}-${distro_ver}_${distro_arch}

for mount_target in proc dev; do
  mount | grep ${chroot_dir}/${mount_target} || mount --bind /${mount_target} ${chroot_dir}/${mount_target}
done

###> execscript

local_path=${repo_uri}
[ -d ${chroot_dir}/${local_path} ] || mkdir -p ${chroot_dir}/${local_path}
rsync -avx ${local_path}/ ${chroot_dir}/${local_path}

chroot ${chroot_dir} $SHELL -ex <<EOS
  echo nameserver 8.8.8.8 >> /etc/resolv.conf
  echo nameserver 8.8.4.4 >> /etc/resolv.conf

  rpm -Uvh http://dlc.wakame.axsh.jp.s3-website-us-east-1.amazonaws.com/epel-release
  yum --disablerepo='*' --enablerepo=base install -y git make sudo rpm-build rpmdevtools yum-utils

  cd /tmp
  [ -d wakame-vdc ] || git clone ${repo_uri} wakame-vdc
  cd wakame-vdc

  # download lxc, rabbitmq-server and openvswitch
  ./tests/vdc.sh.d/rhel/3rd-party.sh download

  yum-builddep -y rpmbuild/SPECS/*.spec

  VDC_BUILD_ID=${build_id} VDC_REPO_URI=${repo_uri} ./rpmbuild/rules binary-snap
EOS

###< execscript

for mount_target in proc dev; do
  mount | grep ${chroot_dir}/${mount_target} && umount -l ${chroot_dir}/${mount_target}
done

echo "Complete!!"
