#!/bin/bash

db_tgz="http://10.4.2.6:8080/db.tgz"    # db.tgz文件下载地址（tgz中需连db目录一起打包）

crust start chain; sleep 5
# local_hi=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_syncState", "params":[]}' localhost:19933 | jq .result | jq .currentBlock)
rcp_hi=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_syncState", "params":[]}' 120.226.39.50:19933 | jq .result | jq .currentBlock)

if ! [[ $local_hi ]]; then local_hi=0;fi

if [[ $((rcp_hi-local_hi)) -gt 1000 ]];then
  systemctl stop zabbix-agent.service
  crust stop; sleep 2
  cd /opt/crust/data/chain/chains/crust/ && rm -rf ./db
  wget -O db.tgz ${db_tgz} && tar -zxf db.tgz && rm -rf db.tgz

  crust reload; sleep 2
  systemctl start zabbix-agent.service
fi
curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_addReservedPeer", "params":["/ip4/10.4.2.6/tcp/30888/p2p/12D3KooWHnLjSMejJp1Hfc3CXDuhkjd9oZPGn6auvFWGi6UgYE42"]}' localhost:19933


