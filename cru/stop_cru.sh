#!/bin/bash
crust start chain; sleep 5
local_hi=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_syncState", "params":[]}' localhost:19933 | jq .result | jq .currentBlock)
rcp_hi=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_syncState", "params":[]}' 120.226.39.50:19933 | jq .result | jq .currentBlock)
if [[ $((rcp_hi-local_hi)) -gt 1000 ]];then systemctl stop zabbix-agent.service; crust stop; fi