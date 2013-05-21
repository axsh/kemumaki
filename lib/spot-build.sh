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

[[ -d ${vdc_dir} ]] || {
  echo "ERROR: repository not found: ${vdc_dir}" >/dev/stderr
  exit 1
}

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

(cd .. &&  git submodule update --init)

distro_name="centos"
distro_ver="6"
distro_subver="4"
distro_detail="${distro_name}-${distro_ver}.${distro_subver}"

[[ -d ${rpm_dir} ]] && rm -rf ${rpm_dir} || :

for arch in ${archs}; do
  ##
  ## 1. setup chroot_dir
  ##

  base_dir=${rpmbuild_tmp_dir}/chroot/base
  [ -d ${base_dir} ] || mkdir -p ${base_dir}

  distro_dir=${rpmbuild_tmp_dir}/chroot/base/${distro_name}-${distro_ver}_${arch}
  chroot_dir=${rpmbuild_tmp_dir}/chroot/dest/${distro_name}-${distro_ver}_${arch}

  distro_targz_file=${distro_detail}_${arch}.tar.gz
  [ -f ${base_dir}/${distro_targz_file}     ] || curl -fkL http://dlc.wakame.axsh.jp.s3.amazonaws.com/demo/rootfs-tree/${distro_targz_file} -o ${base_dir}/${distro_targz_file}
  [ -d ${base_dir}/${distro_detail}_${arch} ] || tar zxpf ${base_dir}/${distro_targz_file} -C ${base_dir}/
  [ -d ${distro_dir}                        ] || mv ${base_dir}/${distro_detail}_${arch} ${distro_dir}

  [[ -d "${chroot_dir}" ]] || mkdir -p ${chroot_dir}
  rsync -ax --delete ${distro_dir}/ ${chroot_dir}/

  ##
  ## 2. build rpms
  ##

  time setarch ${arch} ./rpmbuild.sh --build-id=$(cd ${vdc_dir} && git log -n 1 --pretty=format:"%h") --repo-uri=$(cd ${vdc_dir}/.git && pwd)

  ##
  ## 3. pick rpms
  ##
  case ${arch} in
  i686) basearch=i386 ;;
  esac

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


[[ -d ${yum_repository_dir}/${vdc_branch} ]] || mkdir -p ${yum_repository_dir}/${vdc_branch}

(
  cd ${yum_repository_dir}/${vdc_branch}
  [[ -d ${release_id} ]] && rm -rf ${release_id} || :
  rsync -avx ${rpm_dir}/ ${release_id}

  tar zcvpf ${release_id}.tar.gz ${release_id}
  ls -la ${release_id}.tar.gz
)

[[ -L ${yum_repository_dir}/${vdc_branch}/current ]] && rm ${yum_repository_dir}/${vdc_branch}/current
ln -s ${yum_repository_dir}/${vdc_branch}/${release_id} ${yum_repository_dir}/${vdc_branch}/current
