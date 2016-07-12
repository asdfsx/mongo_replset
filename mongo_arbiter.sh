#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)

if [[ ! -r $TOP_DIR/mongorc ]]; then
    die $LINENO "missing $TOP_DIR/mongorc"
fi
source $TOP_DIR/mongorc

#创建数据目录
mkdir -p ${ARBITER_PATH}/data
mkdir -p ${ARBITER_PATH}/key

#创建keyfile
echo ${KEY} > ${ARBITER_PATH}/key/key
echo ${KEY} > ${ARBITER_PATH}/key/arbkey
chmod 400 ${ARBITER_PATH}/key/key
chmod 400 ${ARBITER_PATH}/key/arbkey

ARBITERIP=$(echo $ARBITER|awk -F':'  '{print $1}') 
ARBITERPORT=$(echo $ARBITER|awk -F':'  '{print $2}') 

#启动mongo
docker run --name mongoarbiter \
           -v ${ARBITER_PATH}:/data/db \
           -p ${ARBITERPORT}:27017 \
           -d mongo --replSet "$REPLSET" --keyFile /data/db/key/arbkey --dbpath /data/db/data --noprealloc
