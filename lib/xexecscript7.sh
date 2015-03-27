#!/bin/bash
#
# requires:
#  bash
#
set -e
set -x

declare chroot_dir=$1

[[ -n "${local_repo_path}" ]] || exit 1
[[ -n "${rpm_dir}"         ]] || exit 1

mkdir -p ${chroot_dir}/${local_repo_path}
rsync -avx ${local_repo_path}/ ${chroot_dir}/${local_repo_path}

cat <<-EOS | tee ${chroot_dir}/etc/yum.repos.d/wakame-vdc.repo
	[wakame-3rd-rhel7]
	name=Wakame 3rd Party
	baseurl=http://dlc.wakame.axsh.jp/packages/3rd/rhel/7/master/
	gpgcheck=0
	EOS

# hold-releasever
if [[ -n "${distro_ver}" ]]; then
  mkdir -p             ${chroot_dir}/etc/yum/vars

  echo ${distro_ver} > ${chroot_dir}/etc/yum/vars/releasever
  cat                  ${chroot_dir}/etc/yum/vars/releasever
fi

function baseurl() {
  local releasever=${1}

  local baseurl=http://vault.centos.org

  case "${releasever}" in
    5.11 | 6.6 | 7.0.1406 )
      baseurl=http://ftp.riken.jp/Linux/centos
      ;;
  esac

  echo ${baseurl}
}

# hold-releasever.hold-baseurl
if [[ -f ${chroot_dir}/etc/yum/vars/releasever ]]; then
  releasever=$(< ${chroot_dir}/etc/yum/vars/releasever)
  majorver=${releasever%%.*}

  mv ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo{,.saved}

  baseurl=$(baseurl ${releasever})

  cat <<-REPO > ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo
	[base]
	name=CentOS-\$releasever - Base
	baseurl=${baseurl}/\$releasever/os/\$basearch/
	gpgcheck=1
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${majorver}

	[updates]
	name=CentOS-\$releasever - Updates
	baseurl=${baseurl}/\$releasever/updates/\$basearch/
	gpgcheck=1
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${majorver}
	REPO
fi

cat ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo

arch=$(arch)
case "${arch}" in
  i*86)   basearch=i386 arch=i686 ;;
  x86_64) basearch=${arch} ;;
esac

chroot ${chroot_dir} $SHELL -ex <<EOS
  yum clean metadata --disablerepo='*' --enablerepo='base'

  echo nameserver 8.8.8.8 >> /etc/resolv.conf
  echo nameserver 8.8.4.4 >> /etc/resolv.conf

  rpm -Uvh http://ftp.jaist.ac.jp/pub/Linux/Fedora/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
  # workaround 2014/10/17
  #
  # in order escape below error
  # > Error: Cannot retrieve metalink for repository: epel. Please verify its path and try again
  #
  sed -i \
   -e 's,^#baseurl,baseurl,' \
   -e 's,^mirrorlist=,#mirrorlist=,' \
   -e 's,http://download.fedoraproject.org/pub/epel/,http://ftp.jaist.ac.jp/pub/Linux/Fedora/epel/,' \
   /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo

  yum --disablerepo='*' --enablerepo=base install -y git make sudo rpm-build rpmdevtools yum-utils tar
EOS

chroot ${chroot_dir} $SHELL -ex <<'EOS'
  deploy_to=/var/tmp/buildbook-rhel7
  git clone https://github.com/wakameci/buildbook-rhel7.git ${deploy_to}

  cd ${deploy_to}
  ./run-book.sh openvswitch.vnet
EOS

chroot ${chroot_dir} $SHELL -ex <<'EOS'
  cd /tmp
  [[ -d wakame-vdc ]] || git clone ${local_repo_path} wakame-vdc
  cd wakame-vdc

  case "${releasever}" in
    *)
      yum install --disablerepo=updates -y libyaml libyaml-devel
      ;;
  esac

  yum-builddep -y rpmbuild/SPECS/*.spec

  VDC_BUILD_ID=$(cd ${local_repo_path}/../ && git log -n 1 --pretty=format:"%h") VDC_REPO_URI=${local_repo_path} ./rpmbuild/rules binary-snap
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
