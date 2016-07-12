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

# 复制arbiter部署文件到arbiter节点
ssh ${DEPLOY_USER}@${ARBITERIP} "mkdir -p ${DEPLOY_DICTORY}/bin"
scp ${TOP_DIR}/mongo_arbiter.sh ${DEPLOY_USER}@${ARBITERIP}:${DEPLOY_DICTORY}/bin
scp ${TOP_DIR}/mongorc ${DEPLOY_USER}@${ARBITERIP}:${DEPLOY_DICTORY}/bin 

# 复制node部署文件到node节点
for node in ${NODES[@]};
do
    nodeip=$(echo ${node}|awk -F':'  '{print $1}')
    ssh ${DEPLOY_USER}@${nodeip} "mkdir -p ${DEPLOY_DICTORY}/bin"
    scp ${TOP_DIR}/mongo_node.sh ${DEPLOY_USER}@${nodeip}:${DEPLOY_DICTORY}/bin
    scp ${TOP_DIR}/mongorc ${DEPLOY_USER}@${nodeip}:${DEPLOY_DICTORY}/bin
done;

#启动arbiter
ssh ${DEPLOY_USER}@${ARBITERIP} "${DEPLOY_DICTORY}/bin/mongo_arbiter.sh"

#启动node
for node in ${NODES[@]};
do
    nodeip=$(echo $node|awk -F':'  '{print $1}')
    ssh ${DEPLOY_USER}@${nodeip} "${DEPLOY_DICTORY}/bin/mongo_node.sh $node"
done; 


${TOP_DIR}/mongo_replset.sh
