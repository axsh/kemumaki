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
  
  run_mode=${run_mode:-jenkins}

  # dcmgr settings
  dcmgr_host=${DCMGR_HOST:-${dcmgr_host:-10.0.2.15}}
  dcmgr_port=${DCMGR_PORT:-${dcmgr_port:-9001}}

  # mysql settings
  mysql_host=${mysql_host:-${dcmgr_host}}
  mysql_user=${mysql_user:-root}
  mysql_database=${mysql_database:-wakame_dcmgr}

  # kemumaki
  kemumaki_repo_url=${kemumaki_repo_url:-https://github.com/axsh/kemumaki.git}
  kemumaki_branch=${KEMUMAKI_BRANCH:-${kemumaki_branch:-master}}
  
  # hipchat
  hipchat_notification=${HIPCHAT_NOTIFICATION:-${hipchat_notification:-false}}
  hipchat_token=${HIPCHAT_TOKEN:-${hipchat_token:-}}
  hipchat_room_id=${HIPCHAT_ROOM_ID:-${hipchat_room_id:-}}
  hipchat_from_name=${HIPCHAT_FROM_NAME:-${hipchat_from_name:-}}
  
  # vdc
  vdc_repo_url=${VDC_REPO_URL:-${vdc_repo_url:-https://github.com/axsh/wakame-vdc.git}}
  vdc_branch=${GIT_BRANCH:-${vdc_branch:-master}}
  vdc_dir=${VDC_DIR:-${WORKSPACE:-${vdc_dir:-${abs_dirname}/wakame-vdc}}}

  # vmapp
  vmapp_deploy_dir=${VMAPP_DEPLOY_DIR:-${vmapp_deploy_dir:-/var/www/html/axsh/wakame}}
  vmapp_suite=${VMAPP_DEPLOY_DIR:-${vmapp_suite:-centos6}}

  ssh_opts=${ssh_opts:-"-o StrictHostKeyChecking=no"}

  mkdir -p ${tmp_dir}
  mkdir -p ${rpmbuild_tmp_dir}
  mkdir -p ${report_dir}
}

initialize
