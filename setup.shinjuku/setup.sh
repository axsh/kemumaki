#!/bin/bash

set -e

function load_node_config(){
  local name=$1
  [[ ! -f ${vm_data_dir}/${name}/vm.conf ]] || . ${vm_data_dir}/${name}/vm.conf
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
  [[ -z ${amqp_host} ]] || echo ${amqp_host} amqp-server >> ${dest}/hosts
  [[ -z ${redis_host} ]] || echo ${redis_host} redis-server >> ${dest}/hosts
  [[ -z ${vdc_yum_repo_host} ]] || echo ${vdc_yum_repo_host} vdc-yum-repo-server >> ${dest}/hosts
  cat ${dest}/hosts
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
  local script=${vm_dir}/execscript.sh
  # TODO versioning

  echo "build_vm ${name}"

  local version=1
  local arch=$(arch)
  local raw_file=${image_dir}/${name}.$(date +%Y%m%d).$(printf "%02d" ${version}).${arch}.raw
  while [[ -f ${raw_file} ]]; do
    version=$((${version} + 1))
    raw_file=${image_dir}/${name}.$(date +%Y%m%d).$(printf "%02d" ${version}).${arch}.raw
  done

  generate_copy_file ${name}

  ${vmbuilder_command} \
    --hostname=${name} \
    --rootsize=${rootsize:-8192} \
    --dns=${dns} \
    --copy=${copy} \
    --execscript=${script} \
    --raw=${raw_file} \
    --ssh-key=${ssh_key} \
    --ssh-user-key=${ssh_user_key} \
    --devel-user=${devel_user} \
    --nictab=${vm_data_dir}/${name}/vm.nictab

  echo "[INFO] Modify symlink"
  ln -sf ${raw_file} ${image_dir}/${name}.raw

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

  ${script_dir}/wait_for_ready.sh -h ${redis_host} ${name}
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
  ssh ${ssh_opts} ${ipaddr} /opt/axsh/bin/init_vdc.sh -y
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

abs_dirname=$(cd $(dirname ${BASH_SOURCE[0]})/../ && pwd)
function_dir=${abs_dirname}/functions
config_dir=${KEMUMAKI_CONFIG_DIR:-${abs_dirname}/config}
. ${function_dir}/util.sh
load_config
set_debug


kemumaki_env=shinjuku
setup_dir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
image_dir=${setup_dir}/images
vm_data_dir=${setup_dir}/vms
tmp_dir=${abs_dirname}/tmp/${kemumaki_env}
script_dir=${abs_dirname}/scripts
vmbuilder_dir=${abs_dirname}/vmbuilder
vmbuilder_command=${vmbuilder_dir}/kvm/rhel/6/vmbuilder.sh
kvm_ctl_command=${vmbuilder_dir}/kvm/rhel/6/misc/kvm-ctl.sh
ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

vnc_port=${vnc_port:-1001}
monitor_port=${monitor_port:-4444}
serial_port=${serial_port:-5555}
brname=${brname:-vboxbr0}
netmask=${netmask:-255.255.255.0}
dns=${dns:-8.8.8.8}
vm_names=(dcmgr hva)
keep_releases=${keep_releases:-5}

mkdir -p ${tmp_dir}

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
start_vm|stop_vm|restart_vm|update_vm)
  if [[ -n "${1}" ]]; then
    ${command} $1
  else
    each_vm ${command}
  fi
  ;;
info_vm)
  ${command} $1
  ;;
list_vm|prepare_vmimage)
  ${command}
  ;;
*)
  echo "[ERROR] no such command: ${command}"
  exit 1
  ;;
esac
