#!/bin/bash

function load_config(){
  [[ ! -f ${config_dir}/kemumaki.conf ]] || . ${config_dir}/kemumaki.conf
}

function set_debug(){
  [[ ${KEMUMAKI_DEBUG:-${debug}} = true ]] && set -x || :
}

function initialize(){
  abs_dirname=$(cd $(dirname ${BASH_SOURCE[0]})/../ && pwd)
  lib_dir=${abs_dirname}/lib
  config_dir=${KEMUMAKI_CONFIG_DIR:-${abs_dirname}/config}
  . ${lib_dir}/util.sh
  load_config
  set_debug

  kemumaki_env=${KEMUMAKI_ENV:-shinjuku}
  vdc_build_target=${VDC_BUILD_TARGET:-${vdc_build_target:-}}
  tmp_dir=${abs_dirname}/tmp
  rpmbuild_tmp_dir=${tmp_dir}/rpmbuild
  report_dir=${KEMUMAKI_REPORT_DIR:-${report_dir:-/var/www/html/reports}}
  report_dir=${report_dir%/} # remove trailing slash
  report_url_prefix=${KEMUMAKI_REPORT_URL_PREFIX:-${report_url_prefix:-reports}}
  
  run_mode=${run_mode:-jenkins}

  # kemumaki
  kemumaki_repo_url=${kemumaki_repo_url:-https://github.com/axsh/kemumaki.git}
  kemumaki_branch=${KEMUMAKI_BRANCH:-${kemumaki_branch:-master}}
  
  # vdc
  vdc_repo_url=${VDC_REPO_URL:-${vdc_repo_url:-https://github.com/axsh/wakame-vdc.git}}
  vdc_branch=${GIT_BRANCH:-${vdc_branch:-master}}
  vdc_branch=${vdc_branch##*/} # remote/feathre-foo -> feature-foo
  vdc_dir=${VDC_DIR:-${WORKSPACE:-${vdc_dir:-${abs_dirname}/wakame-vdc}}}

  # vmapp
  vmapp_deploy_dir=${VMAPP_DEPLOY_DIR:-${vmapp_deploy_dir:-/var/www/html/axsh/wakame}}
  vmapp_suite=${VMAPP_DEPLOY_DIR:-${vmapp_suite:-all}}

  ssh_opts=${ssh_opts:-"-o StrictHostKeyChecking=no"}

  test_timeout=${TEST_TIMEOUT:-${test_timeout:-$((60 * 30))}}

  mkdir -p ${tmp_dir}
  mkdir -p ${rpmbuild_tmp_dir}
  mkdir -p ${report_dir}
}

initialize
