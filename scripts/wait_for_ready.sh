#!/bin/bash 

base_dir=$(cd $(dirname $0)/.. && pwd)
REDIS_BASH_DIR=${base_dir}/redis-bash
source ${REDIS_BASH_DIR}/redis-bash-lib 2> /dev/null

REDISHOST=localhost
REDISPORT=6379

while getopts ":h:p:" opt
do
    case ${opt} in
        h) REDISHOST=${OPTARG};;
        p) REDISPORT=${OPTARG};;
    esac
done
shift $((${OPTIND} - 1))

NAME=$1

if [ -z "${NAME}" ]
then
    echo "Usage: $(basename ${0}) name"
    exit 1
fi

echo
echo -n "waiting for ${NAME} to be ready..."

while true
do
    
    exec 5>&-
    if [ "${REDISHOST}" != "" ] && [ "${REDISPORT}" != "" ]
    then
        exec 5<>/dev/tcp/${REDISHOST}/${REDISPORT} # open fd
    else
        echo "Wrong arguments"
        exit 255
    fi
    redis-client 5 SUBSCRIBE ${1} > /dev/null # subscribe to the pubsub channel in fd 5
    while true
    do
        unset ARGV
        OFS=${IFS};IFS=$'\n' # split the return correctly
        ARGV=($(redis-client 5))
        IFS=${OFS}
        if [ "${ARGV[0]}" = "message" ] && [ "${ARGV[1]}" = "${1}" ]
        then
            if [ "${ARGV[2]}" = "ready" ]
            then
                echo "ready"
                echo
                exit 0
            fi
        elif [ -z ${ARGV} ]
        then
            sleep 1
            break
        fi
    done
done
