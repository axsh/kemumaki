#!/bin/bash

set -e

function check(){
  local name=$1
  local ip=$2

  echo --------------------
  echo ${name} services
  echo --------------------

  echo -n connect to ${ip}...
  ssh -q root@${ip} -C ":"
  if [ $? -ne 0 ]; then
    echo failure
    return 1
  fi
  echo success

  local services= status= status_line= job_id=
  for service in $(eval echo \$\{${name}_services[@]\})
  do
    echo -ne "vdc-${service}\t"
    status_line=$(ssh root@${ip} -C "initctl list | grep vdc-${service}" 2>/dev/null)
    status=$(echo ${status_line} | awk '{print $2}' | sed -e 's/,//')
    [[ ${status} =~ \(.*\) ]] && {
      # service which started with ID
      # ex) vdc-hva-worker (openvz64) start/running
      job_id=$(echo ${status} | sed 's/[()]//g')
      status=$(echo ${status_line} | awk '{print $3}' | sed -e 's/,//')
    }

    if [[ -z $(echo $status | grep -o 'start/running') ]]; then
      error=y
    fi
    echo ${status}
  done
  echo 
}

dcmgr_services="
admin
auth
proxy
collector
webui
dcmgr
metadata
"
#nwmongw
#nsa
#sta

hva_services=(hva hva-worker)

error=

name=$1
ip=$2

check ${name} ${ip}

if [[ "${error}" = "y" ]]; then
  echo "[ERROR] check status failed." >&2
  exit 1
fi
echo "check status was successful."
