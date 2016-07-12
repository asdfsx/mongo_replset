#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)

if [[ ! -r $TOP_DIR/mongorc ]]; then
    die $LINENO "missing $TOP_DIR/mongorc"
fi
source $TOP_DIR/mongorc

function die {
    local exitcode=$?
    set +o xtrace
    local line=$1; shift
    if [ $exitcode == 0 ]; then
        exitcode=1
    fi
    err $line "$*"
    # Give buffers a second to flush
    sleep 1
    exit $exitcode
}

# Prints line number and "message" in error format
# err $LINENO "message"
function err {
    local exitcode=$?
    local xtrace=$(set +o | grep xtrace)
    set +o xtrace
    local msg="[ERROR] ${BASH_SOURCE[2]}:$1 $2"
    echo $msg 1>&2;
    if [[ -n ${LOGDIR} ]]; then
        echo $msg >> "${LOGDIR}/error.log"
    fi
    $xtrace
    return $exitcode
}

function _ssh_check {
    local FLOATING_IP=$1
    local DEFAULT_INSTANCE_USER=$2
    local ACTIVE_TIMEOUT=$3
    local probe_cmd=""
    if ! timeout $ACTIVE_TIMEOUT sh -c "while ! ssh ${DEFAULT_INSTANCE_USER}@${FLOATING_IP} echo ssh_check $FLOATING_IP success; do sleep 1; done"; then
        die $LINENO "server didn't become ssh-able!"
    fi
}

# 检查ssh
ARBITERIP=$(echo $ARBITER|awk -F':'  '{print $1}')
_ssh_check $ARBITERIP $DEPLOY_USER $ACTIVE_TIMEOUT

for node in ${NODES[@]};
do
    nodeip=$(echo $node|awk -F':'  '{print $1}')
    _ssh_check $nodeip $DEPLOY_USER $ACTIVE_TIMEOUT
done;

#启动arbiter
ssh ${DEPLOY_USER}@${ARBITERIP} "docker kill mongoarbiter"
ssh ${DEPLOY_USER}@${ARBITERIP} "docker rm -v mongoarbiter"
ssh ${DEPLOY_USER}@${ARBITERIP} "rm -rf ${ARBITER_PATH}"

#启动node
for node in ${NODES[@]};
do
    nodeip=$(echo $node|awk -F':'  '{print $1}')
    nodeport=$(echo $node|awk -F':'  '{print $2}')
    ssh ${DEPLOY_USER}@${nodeip} "docker kill mongonode_${nodeport}"
    ssh ${DEPLOY_USER}@${nodeip} "docker rm -v mongonode_${nodeport}"
    ssh ${DEPLOY_USER}@${ARBITERIP} "rm -rf ${NODE_PATH}_${nodeport}" 
done; 
