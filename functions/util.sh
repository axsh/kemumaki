#!/bin/bash

function checkroot() {
  #
  # Check if we're running as root, and bail out if we're not.
  #
  [[ "${UID}" -ne 0 ]] && {
    echo "[ERROR] Must run as root." >&2
    return 1
  } || :
}

function load_config(){
  [[ ! -f ${config_dir}/kemumaki.conf ]] || . ${config_dir}/kemumaki.conf
  [[ ! -f ${config_dir}/kemumaki.${KEMUMAKI_ENV}.conf ]] || . ${config_dir}/kemumaki.${KEMUMAKI_ENV}.conf
}

function set_debug(){
  [[ ${KEMUMAKI_DEBUG:-${debug}} = true ]] && set -x || :
}
