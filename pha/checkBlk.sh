#!/usr/bin/env bash

get_BlkNum(){
  localNum=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' localhost:${1} | jq .result | jq .number)
  printf %d ${localNum//\"/}
}

check_BlkSync(){
    oldBlkfile='/opt/blk.txt'
    old_blk=$(cat ${oldBlkfile} 2> /dev/null || echo 0)
    new_blk=$(get_BlkNum ${1}) && echo ${new_blk} > ${oldBlkfile}

    if [[ $old_blk -eq $new_blk ]];then phala stop node && phala start;fi
}

case $1 in
check_BlkSync)
  check_BlkSync $2
  ;;
esac

