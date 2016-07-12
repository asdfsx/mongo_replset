#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)
NODEIP=$(echo $1|awk -F':'  '{print $1}')
NODEPORT=$(echo $1|awk -F':'  '{print $2}')
 
echo $1 $NODEIP

if [[ ! -r $TOP_DIR/mongorc ]]; then
    die $LINENO "missing $TOP_DIR/mongorc"
fi
source $TOP_DIR/mongorc

#创建数据目录 
mkdir -p  ${NODE_PATH}_${NODEPORT}/data
mkdir -p  ${NODE_PATH}_${NODEPORT}/key

#创建keyfile
echo ${KEY} > ${NODE_PATH}_${NODEPORT}/key/key
echo ${KEY} > ${NODE_PATH}_${NODEPORT}/key/arbkey
chmod 400 ${NODE_PATH}_${NODEPORT}/key/key
chmod 400 ${NODE_PATH}_${NODEPORT}/key/arbkey
echo "${NODE_PATH}_${NODEPORT}"
#启动mongo
docker run --name mongonode_${NODEPORT} \
           -v ${NODE_PATH}_${NODEPORT}:/data/db \
           -p ${NODEPORT}:27017 \
           -d mongo --replSet "$REPLSET" --keyFile /data/db/key/key --dbpath /data/db/data --auth --noprealloc 
