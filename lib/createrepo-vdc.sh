#!/bin/bash

set -e
#set -x

. ./../config/rpmbuild.conf

[ -d ${rpm_dir} ] && rm -rf ${rpm_dir}
mkdir -p ${rpm_dir}

for arch in ${archs}; do
  case ${arch} in
  i*86)   basearch=i386; arch=i686;;
  x86_64) basearch=${arch};;
  esac

  chroot_dir=${rpmbuild_tmp_dir}/chroot/dest/centos-6_${arch}

  #
  # arch, basearch
  #
  [ -d ${rpm_dir}/${basearch} ] || mkdir -p ${rpm_dir}/${basearch}
  subdirs="
    tmp/wakame-vdc/tests/vdc.sh.d/rhel/vendor/${basearch}
    root/rpmbuild/RPMS/${arch}
    ${HOME}/rpmbuild/RPMS/${arch}
  "
  for subdir in ${subdirs}; do
    pkg_dir=${chroot_dir}/${subdir}
    bash -c "[ -d ${pkg_dir} ] && rsync -av --exclude=epel-* --exclude=elrepo-* ${pkg_dir}/*.rpm ${rpm_dir}/${basearch}/ || :"
  done

  #
  # noarch
  #
  [ -d ${rpm_dir}/noarch ] || mkdir -p ${rpm_dir}/noarch
  subdirs="
    root/rpmbuild/RPMS/noarch
    ${HOME}/rpmbuild/RPMS/noarch
  "
  for subdir in ${subdirs}; do
    pkg_dir=${chroot_dir}/${subdir}
    bash -c "[ -d ${pkg_dir} ] && rsync -av --exclude=epel-* --exclude=elrepo-* ${pkg_dir}/*.rpm ${rpm_dir}/noarch/ || :"
  done
done

# create repository metadata files.
(
 cd ${rpm_dir}
 createrepo .
)

# generate index
./gen-index-html.sh > ${rpm_dir}/index.html
