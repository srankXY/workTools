#!/bin/bash
account=$(curl http://127.0.0.1:12222/api/v0/enclave/id_info | jq .account)
params=$(curl -s -XPOST 'https://crust.webapi.subscan.io/api/scan/extrinsics' --header 'Content-Type: application/json' --data-raw '{"jsonrpc":"2.0", "call": "report_works", "module": "swork", "no_params": false, "page": 0, "row": 1, "signed": "signed", "success": true,"address": '$account'}' | jq -r .data.extrinsics | jq -r .[0].params | sed 's/\\//g' | jq .)
added_files=($(echo $params | jq .[6].value | jq -r .[].col1))
deleted_files=($(echo $params | jq .[7].value | jq -r .[].col1))
input_data='{"added_files": ['
for file in ${added_files[@]}; do input_data="${input_data}\"$(echo $file | xxd -r -p)\","; done
if [ ${#added_files[@]} -ne 0 ]; then input_data=${input_data:0:len-1}; fi
input_data="${input_data}], \"deleted_files\": ["
for file in ${deleted_files[@]}; do input_data="${input_data}\"$(echo $file | xxd -r -p)\","; done
if [ ${#deleted_files[@]} -ne 0 ]; then input_data=${input_data:0:len-1}; fi
input_data="${input_data}]}"
curl -XPOST "http://127.0.0.1:12222/api/v0/file/recover_illegal" --header 'Content-Type: application/json' --data-raw "$input_data"