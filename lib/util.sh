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

function vdc_origin_url(){
  (cd ${vdc_dir} && git config --get remote.origin.url)
}
