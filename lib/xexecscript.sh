#!/bin/bash
#
# requires:
#  bash
#
set -e

declare chroot_dir=$1

[[ -n "${local_repo_path}" ]] || exit 1
[[ -n "${rpm_dir}"         ]] || exit 1

[[ -d ${chroot_dir}/${local_repo_path} ]] || mkdir -p ${chroot_dir}/${local_repo_path}
rsync -avx ${local_repo_path}/ ${chroot_dir}/${local_repo_path}

cat <<EOS > ${chroot_dir}/etc/yum.repos.d/wakame-vdc.repo
[wakame-3rd-rhel6]
name=Wakame 3rd Party
baseurl=http://dlc.wakame.axsh.jp/packages/3rd/rhel/6/master/
gpgcheck=0
EOS

cat ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo
sed -i s,\$releasever,${distro_ver},g ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo
cat ${chroot_dir}/etc/yum.repos.d/CentOS-Base.repo

arch=$(arch)
case ${arch} in
  i*86)   basearch=i386; arch=i686;;
  x86_64) basearch=${arch};;
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

  vendor_dir=tests/vdc.sh.d/rhel/vendor/
  vendor_dir=${vendor_dir}/${basearch}
  [ -d ${vendor_dir} ] || mkdir -p ${vendor_dir}

  function list_3rd_party() {
    vdc_current_base_url=http://dlc.wakame.axsh.jp.s3.amazonaws.com/packages/rhel/6/current/${basearch}
    cat <<-EOS | egrep -v ^#
	# pkg_name                pkg_uri
	elrepo-release            http://elrepo.org/elrepo-release-6-5.el6.elrepo.noarch.rpm
	rabbitmq-server-2.7.1     http://www.rabbitmq.com/releases/rabbitmq-server/v2.7.1/rabbitmq-server-2.7.1-1.noarch.rpm
	openvswitch               ${vdc_current_base_url}/kmod-openvswitch-1.6.1-1.el6.${arch}.rpm
	openvswitch               ${vdc_current_base_url}/openvswitch-1.6.1-1.${arch}.rpm
	lxc                       ${vdc_current_base_url}/lxc-libs-0.8.0-1.el6.${arch}.rpm
	lxc                       ${vdc_current_base_url}/lxc-0.8.0-1.el6.${arch}.rpm
	EOS
  }

  function download_3rd_party() {
    list_3rd_party | while read pkg_name pkg_uri; do
      pkg_file=$(basename ${pkg_uri})
      echo downloading ${pkg_name} ...
      case ${pkg_uri} in
      http://*)
        [ -f ${vendor_dir}/${pkg_file} ] || {
          curl -R ${pkg_uri} -o ${vendor_dir}/${pkg_file}
        }
        ;;
      esac
    done
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
