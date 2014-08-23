#!/bin/bash
#
# requires:
#  bash
#
set -e

declare chroot_dir=$1

[[ -n "${local_repo_path}" ]] || exit 1
[[ -n "${rpm_dir}"         ]] || exit 1

mkdir -p ${chroot_dir}/${local_repo_path}
rsync -avx ${local_repo_path}/ ${chroot_dir}/${local_repo_path}

cat <<-EOS | tee ${chroot_dir}/etc/yum.repos.d/wakame-vdc.repo
	[wakame-3rd-rhel6]
	name=Wakame 3rd Party
	baseurl=http://dlc.wakame.axsh.jp/packages/3rd/rhel/6/master/
	gpgcheck=0
	EOS

# hold-releasever
if [[ -n "${distro_ver}" ]]; then
  mkdir -p             ${chroot_dir}/etc/yum/vars

  echo ${distro_ver} > ${chroot_dir}/etc/yum/vars/releasever
  cat                  ${chroot_dir}/etc/yum/vars/releasever
fi

# hold-releasever.hold-baseurl
if [[ -f ${chroot_dir}/etc/yum/vars/releasever ]]; then
  releasever=$(< ${chroot_dir}/etc/yum/vars/releasever)
  majorver=${releasever%%.*}

  mv ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo{,.saved}

  cat <<-REPO > ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo
	[base]
	name=CentOS-\$releasever - Base
	baseurl=http://ftp.riken.jp/Linux/centos/\$releasever/os/\$basearch/
	gpgcheck=1
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-${majorver}

	[updates]
	name=CentOS-\$releasever - Updates
	baseurl=http://ftp.riken.jp/Linux/centos/\$releasever/updates/\$basearch/
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

  rpm -Uvh http://dlc.wakame.axsh.jp.s3-website-us-east-1.amazonaws.com/epel-release
  yum --disablerepo='*' --enablerepo=base install -y git make sudo rpm-build rpmdevtools yum-utils tar

  cd /tmp
  [[ -d wakame-vdc ]] || git clone ${local_repo_path} wakame-vdc
  cd wakame-vdc

  # download lxc, rabbitmq-server and openvswitch
  ###>>> ./tests/vdc.sh.d/rhel/3rd-party.sh download

  function list_3rd_party() {
    cat <<-EOS | egrep -v ^#
	http://elrepo.org/elrepo-release-6-5.el6.elrepo.noarch.rpm
	http://www.rabbitmq.com/releases/rabbitmq-server/v2.7.1/rabbitmq-server-2.7.1-1.noarch.rpm
	http://dlc.wakame.axsh.jp.s3.amazonaws.com/packages/rhel/6/current/${basearch}/kmod-openvswitch-1.6.1-1.el6.${arch}.rpm
	http://dlc.wakame.axsh.jp.s3.amazonaws.com/packages/rhel/6/current/${basearch}/openvswitch-1.6.1-1.${arch}.rpm
	http://dlc.wakame.axsh.jp.s3.amazonaws.com/packages/rhel/6/current/${basearch}/lxc-libs-0.8.0-1.el6.${arch}.rpm
	http://dlc.wakame.axsh.jp.s3.amazonaws.com/packages/rhel/6/current/${basearch}/lxc-0.8.0-1.el6.${arch}.rpm
	EOS
  }

  function download_3rd_party() {
    local vendor_dir=tests/vdc.sh.d/rhel/vendor/${basearch}
    mkdir -p \${vendor_dir}

    local pkg_uri=
    while read pkg_uri; do
      curl -fsSkL \${pkg_uri} -o \${vendor_dir}/\${pkg_uri##*/}
    done < <(list_3rd_party)
  }

  download_3rd_party

  ###<<< ./tests/vdc.sh.d/rhel/3rd-party.sh download

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
