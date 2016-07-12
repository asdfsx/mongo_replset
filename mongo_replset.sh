#!/bin/bash

TOP_DIR=$(cd $(dirname "$0") && pwd)

if [[ ! -r $TOP_DIR/mongorc ]]; then
    die $LINENO "missing $TOP_DIR/mongorc"
fi
source $TOP_DIR/mongorc

NODE=$NODES
NODEIP=$(echo ${NODE}|awk -F':'  '{print $1}')
NODEPORT=$(echo ${NODE}|awk -F':'  '{print $2}') 

#创建初始化配置
#根据mongorc中的node配置生成repl的节点列表
#在这里配置节点列表，可以避免出现{ _id:0, host:'xxxxxxxxxxx:27017'}这样的节点
REPLCONF="{ _id:'$REPLSET',members:["
i=0
while [ $i -lt ${#NODES[@]} ]
do
    REPLCONF=${REPLCONF}"{ _id:$i, host:'${NODES[$i]}'},"
    let i++
done
REPLCONF=${REPLCONF}"]}"

#初始化replset
ssh ${DEPLOY_USER}@${NODEIP} "docker exec mongonode_${NODEPORT}  mongo admin --eval \"rs.initiate($REPLCONF)\""

#创建用户
ssh ${DEPLOY_USER}@${NODEIP} "docker exec mongonode_${NODEPORT}  mongo admin --eval \"db.createUser({user:'${MONGO_USER}',pwd:'$MONGO_PASSWD',roles:[{role:'root',db:'admin'}]})\""

#查看config
ssh ${DEPLOY_USER}@${NODEIP} "docker exec mongonode_${NODEPORT}  mongo admin --eval \"db.auth('${MONGO_USER}','$MONGO_PASSWD');rs.conf()\""

#添加节点
#有了上边的初始化配置，就不需要一个个的填加节点了
#for n in ${NODES[@]};
#do 
#    ssh ${DEPLOY_USER}@${NODEIP} "docker exec mongonode_${NODEPORT}  mongo admin --eval \"db.auth('${MONGO_USER}','$MONGO_PASSWD');rs.add('$n')\"" 
#done;

#添加arbiter
ssh ${DEPLOY_USER}@${NODEIP} "docker exec mongonode_${NODEPORT}  mongo admin --eval \"db.auth('${MONGO_USER}','$MONGO_PASSWD');rs.addArb('${ARBITER}')\""

ssh ${DEPLOY_USER}@${NODEIP} "docker exec mongonode_${NODEPORT}  mongo admin --eval \"db.auth('${MONGO_USER}','$MONGO_PASSWD');rs.status()\""



