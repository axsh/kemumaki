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

[[ -d "${vdc_dir}" ]] || {
  echo "ERROR: repository not found: ${vdc_dir}" >/dev/stderr
  exit 1
}

release_id=$(cd ${vdc_dir} && rpmbuild/helpers/gen-release-id.sh)

(cd .. &&  git submodule update --init)

[[ -d ${rpm_dir} ]] && rm -rf ${rpm_dir}

for arch in ${archs}; do
  time build_id=$(cd ${vdc_dir} && git log -n 1 --pretty=format:"%h") repo_uri=$(cd ${vdc_dir}/.git && pwd) setarch ${arch} ./rpmbuild.sh
done

(
  cd ${rpm_dir}
  createrepo .
)

./gen-index-html.sh > ${rpm_dir}/index.html

[[ -d ${yum_repository_dir}/${vdc_branch} ]] || mkdir -p ${yum_repository_dir}/${vdc_branch}

(
  cd ${yum_repository_dir}/${vdc_branch}
  [[ -d ${release_id} ]] && rm -rf ${release_id}
  rsync -avx ${rpm_dir}/ ${release_id}

  tar zcvpf ${release_id}.tar.gz ${release_id}
  ls -la ${release_id}.tar.gz
)

[[ -L ${yum_repository_dir}/${vdc_branch}/current ]] && rm ${yum_repository_dir}/${vdc_branch}/current
ln -s ${yum_repository_dir}/${vdc_branch}/${release_id} ${yum_repository_dir}/${vdc_branch}/current
