#!/bin/bash
#
# requires:
#  bash
#
set -e

declare chroot_dir=$1

repo_uri=${repo_uri:-git://github.com/axsh/wakame-vdc.git}
[[ -n "${rpm_dir}" ]] || exit 1

local_path=${repo_uri}
[[ -d ${chroot_dir}/${local_path} ]] || mkdir -p ${chroot_dir}/${local_path}
rsync -avx ${local_path}/ ${chroot_dir}/${local_path}

chroot ${chroot_dir} $SHELL -ex <<EOS
  echo nameserver 8.8.8.8 >> /etc/resolv.conf
  echo nameserver 8.8.4.4 >> /etc/resolv.conf

  rpm -Uvh http://dlc.wakame.axsh.jp.s3-website-us-east-1.amazonaws.com/epel-release
  yum --disablerepo='*' --enablerepo=base install -y git make sudo rpm-build rpmdevtools yum-utils tar

  cd /tmp
  [[ -d wakame-vdc ]] || git clone ${repo_uri} wakame-vdc
  cd wakame-vdc

  # download lxc, rabbitmq-server and openvswitch
  ./tests/vdc.sh.d/rhel/3rd-party.sh download

  yum-builddep -y rpmbuild/SPECS/*.spec

  VDC_BUILD_ID=${build_id} VDC_REPO_URI=${repo_uri} ./rpmbuild/rules binary-snap
EOS

# pick rpms

for arch in $(arch) noarch; do
  # mapping arch:basearch pair
  case "${arch}" in
    i686) basearch=i386    ;;
  x86_64) basearch=x86_64  ;;
  noarch) basearch=noarch  ;;
  esac

  [[   -d "${rpm_dir}/${basearch}" ]] && rm -rf ${rpm_dir}/${basearch}
  mkdir -p ${rpm_dir}/${basearch}

  subdirs="
    tmp/wakame-vdc/tests/vdc.sh.d/rhel/vendor/${basearch}
       root/rpmbuild/RPMS/${arch}
    ${HOME}/rpmbuild/RPMS/${arch}
  "
  for subdir in ${subdirs}; do
    pkg_dir=${chroot_dir}/${subdir}
    [[ -d "${pkg_dir}" ]] || continue
    rsync -av --exclude=epel-* --exclude=elrepo-* ${pkg_dir}/*.rpm ${rpm_dir}/${basearch}/
  done
done
