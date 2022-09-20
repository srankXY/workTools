#!/usr/bin/env bash

check_service_status(){
  service=$1
  status=$(docker inspect "$service" | grep -i status | awk -F'"' '{print $(NF-1)}')
  echo "$status"
}

get_BlkNum(){
  localNum=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' localhost:${1} | jq .result | jq .number)
  printf %d ${localNum//\"/}
}

case $1 in
pruntime)
  check_service_status phala-pruntime
  ;;
pherry)
  check_service_status phala-pherry
  ;;
node)
  check_service_status phala-node
  ;;
khala-blk)
  get_BlkNum 9933
  ;;
kusama-blk)
  get_BlkNum 9934
  ;;
esac
