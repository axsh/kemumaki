#!/bin/bash
# rpm build script

set -e

. ./../config/rpmbuild.conf

# > time build_id=$(cd ${vdc_dir} && git log -n 1 --pretty=format:"%h") repo_uri=$(cd ${vdc_dir}/.git && pwd) setarch ${arch} ./rpmbuild.sh
# spot-build.sh sets "repo_uri" and "build_id" parameter.
../vmbuilder/kvm/rhel/6/vmbuilder.sh \
 --distro-name=${distro_name} \
 --distro-ver=${distro_ver}   \
 --distro-dir=${rpmbuild_tmp_dir}/chroot/base/${distro_name}-${distro_ver}_${distro_arch} \
 --execscript=$(pwd)/xexecscript.sh  \
 --hypervisor=null \
 --raw=${rpmbuild_tmp_dir}/${distro_name}-${distro_ver}_${distro_arch}.raw
