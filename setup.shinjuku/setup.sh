#!/bin/bash

set -e

function load_setup_config(){
  [[ ! -f ${setup_dir}/setup.conf ]] || . ${setup_dir}/setup.conf
  [[ ! -f ${setup_dir}/setup.${shinjuku_env}.conf ]] || . ${setup_dir}/setup.${shinjuku_env}.conf
}

function load_node_config(){
  local name=$1
  [[ ! -f ${vm_data_dir}/${name}/vm.conf ]] || . ${vm_data_dir}/${name}/vm.conf
  ipaddr=$(eval echo \${${name}_host})
  node_id=$((node_id_begin + node_id_index))
}

function generate_copy_file(){
  local name=$1
  [[ -n "${name}" ]] || { echo "[ERROR] Invalid argument: name:${name}" >&2; return 1; }
  rm -rf ${tmp_dir}/guestroot
  cp -a ${vm_data_dir}/guestroot_common ${tmp_dir}/guestroot
  cp -af ${vm_data_dir}/${name}/guestroot ${tmp_dir}/
  generate_hosts ${name} ${tmp_dir}/guestroot/etc

  (
    cd ${tmp_dir}/guestroot
    echo "[INFO](copyfile) Generating copy.txt"
    find . ! -type d | sed s,^\.,, | egrep -v '^/(.gitkeep|functions.sh|*.swp)' | while read line; do
      echo ${tmp_dir}/guestroot${line} ${line}
    done > ${tmp_dir}/copy.txt
  )
  cat ${tmp_dir}/copy.txt
}

function generate_hosts(){
  local hostname=$1 dest=$2
  [[ -n "${hostname}" ]] || { echo "[ERROR] Invalid argument: hostname:${hostname}" >&2; return 1; }
  [[ -d ${dest} ]] || { echo "[ERROR] Invalid argument: dest:${dest}" >&2; return 1; }

  echo "[INFO](copyfile) Generating hosts"

  cat <<EOS > ${dest}/hosts
127.0.0.1 localhost
127.0.0.1 ${hostname}
EOS

  echo ${amqp_host:-${dcmgr_host}} amqp-server >> ${dest}/hosts
  [[ -z ${redis_host} ]] || echo ${redis_host} redis-server >> ${dest}/hosts
  [[ -z ${vdc_yum_repo_host} ]] || echo ${vdc_yum_repo_host} vdc-yum-repo-server >> ${dest}/hosts
  cat ${dest}/hosts
}

function generate_nictabs(){
  generate_dcmgr_nictab
  generate_hva_nictab
}

function generate_dcmgr_nictab(){
  local target_file=${tmp_dir}/dcmgr.nictab
  cat <<EOS > ${target_file}
ifname=eth0 ip=${dcmgr_host} mask=${vm_netmask} net=${vm_network} bcast=${vm_broadcast} gw=${vm_gateway}
EOS
}

function generate_hva_nictab(){
  local target_file=${tmp_dir}/hva.nictab
  cat <<EOS > ${target_file}
ifname=eth0 bridge=br0
ifname=br0 ip=${hva_host} mask=${vm_netmask} net=${vm_network} bcast=${vm_broadcast} gw=${vm_gateway} iftype=bridge
EOS
}

function check_vm(){
  for name in ${vm_names[*]}; do
    [[ "${name}" = $1 ]] && return 0
  done
  echo "[ERROR] '${1}' not found in '${vm_names[*]}'"
  return 1
}

function each_vm(){
  local function_names=($*)
  for f in ${function_names[*]}; do
    for name in ${vm_names[*]}; do
      ($f $name)
    done
  done
}

function build_vm(){
  local name=$1
  check_vm $name
  load_node_config $name
  local vm_dir=${vm_data_dir}/${name}
  local copy=${tmp_dir}/copy.txt
  local nictab=${tmp_dir}/${name}.nictab
  local script=${vm_dir}/execscript.sh

  echo "build_vm ${name}"

  local version=1
  local arch=$(arch)
  local raw_file_name=${name}.$(date +%Y%m%d).$(printf "%02d" ${version}).${arch}.raw
  local raw_file_path=${image_dir}/${raw_file_name}
  while [[ -f ${raw_file_path} ]]; do
    version=$((${version} + 1))
    raw_file_name=${name}.$(date +%Y%m%d).$(printf "%02d" ${version}).${arch}.raw
    raw_file_path=${image_dir}/${raw_file_name}
  done

  generate_copy_file ${name}
  generate_${name}_nictab

  ${vmbuilder_command} \
    --hostname=${name} \
    --rootsize=${rootsize:-8192} \
    --dns=${dns} \
    --copy=${copy} \
    --execscript=${script} \
    --raw=${raw_file_path} \
    --ssh-key=${ssh_key} \
    --ssh-user-key=${ssh_user_key} \
    --devel-user=${devel_user} \
    --nictab=${nictab}

  echo "[INFO] Modify symlink"
  (
    cd ${image_dir}
    ln -sf ${raw_file_name} ${name}.raw
  )

  local num=$(ls ${image_dir}/${name}.*.raw | wc -l) 
  [[ ${num} -le ${keep_releases} ]] || {
    echo "[INFO] Deleting old vmimages"
    ls -t ${image_dir}/${name}.*.raw | tail -$((${num} - ${keep_releases})) | while read file; do
      echo "rm ${file}"
      rm ${file}
    done
  }

  return 0
}

function start_vm(){
  local name=$1
  check_vm $name
  load_node_config $name
  local image_path=${raw_file:-${image_dir}/${name}.raw}

  echo "start_vm ${name}"
  
  ${kvm_ctl_command} start \
    --name=${name} \
    --drive="file=${file},media=disk,boot=on,index=0,cache=none" \
    --image-path=${image_path} \
    --brname=${brname} \
    --vnc_keymap=${vnc_keymap:-en-us} \
    --vnc_port=$((${vnc_port} + ${node_id})) \
    --monitor_port=$((${monitor_port} + ${node_id})) \
    --serial_port=$((${serial_port} + ${node_id}))

  ${lib_dir}/wait_for_ready.sh -h ${redis_host} ${name}
}

function stop_vm(){
  local name=$1
  load_node_config $name
  local vifname=${name}

  echo "stop_vm ${name}"

  set +e
  ${kvm_ctl_command} stop --monitor_port=$((${monitor_port} + ${node_id}))
  set -e
}

function update_vm(){
  local name=$1
  check_vm $name
  load_node_config $name
  run_ssh ${ipaddr} /opt/axsh/bin/init_vdc.sh -y
  sleep 5
  ${setup_dir}/check_status.sh ${name} ${ipaddr}
}

function install_ssh_authorized_keys(){
  local name=$1
  check_vm $name
  load_node_config $name
  local pub_pem_file=
  find ${setup_dir}/ssh_pub_keys -type f | while read pub_pem_file; do
    key_name=$(cat ${pub_pem_file} | awk '{print $3}')
    echo "installing ssh authorized_keys to: ${name}"
    run_ssh ${ipaddr} grep $key_name ~/.ssh/authorized_keys || {
      run_ssh ${ipaddr} "echo $(cat ${pub_pem_file}) >> ~/.ssh/authorized_keys"
    }
  done
}

function info_vm(){
  local name=$1
  check_vm $name
  ${kvm_ctl_command} info --name=${name}
}

function list_vm(){
  ${kvm_ctl_command} list
}

function prepare_vmimage(){
  ${setup_dir}/prepare-vmimage.sh
}

function prepare(){
  mkdir -p ${tmp_dir}
  mkdir -p ${image_dir}
  each_vm reset_ssh_key
}

function reset_ssh_key(){
  local name=${1}
  load_node_config ${name}
  [[ -f ~/.ssh/known_hosts ]] && ssh-keygen -R ${ipaddr} || :
}

. $(dirname ${BASH_SOURCE[0]})/../lib/initializer.sh

setup_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
shinjuku_env=${SHINJUKU_ENV:-${shinjuku_env:-production}}
load_setup_config

image_dir=${setup_dir}/images/${shinjuku_env}
vm_data_dir=${setup_dir}/vms
tmp_dir=${abs_dirname}/tmp/${kemumaki_env}
vmbuilder_dir=${abs_dirname}/vmbuilder
vmbuilder_command=${vmbuilder_dir}/kvm/rhel/6/vmbuilder.sh
kvm_ctl_command=${vmbuilder_dir}/kvm/rhel/6/misc/kvm-ctl.sh

vnc_port=${vnc_port:-1001}
monitor_port=${monitor_port:-4444}
serial_port=${serial_port:-5555}
brname=${brname:-vboxbr0}
dns=${dns:-8.8.8.8}
vm_names=(dcmgr hva)
keep_releases=${keep_releases:-5}

prepare

[[ -n $1 ]] && {
  command=${1}
  shift
}

case ${command} in
build_vm)
  if [[ -n "${1}" ]]; then
    stop_vm $1
    build_vm $1
  else
    each_vm stop_vm build_vm
  fi
  ;;
start_vm|stop_vm|restart_vm|update_vm|install_ssh_authorized_keys)
  if [[ -n "${1}" ]]; then
    ${command} $1
  else
    each_vm ${command}
  fi
  ;;
info_vm)
  ${command} $1
  ;;
generate_nictabs|list_vm|prepare_vmimage)
  ${command}
  ;;
*)
  each_vm update_vm
  ;;
esac
