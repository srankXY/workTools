#!/usr/bin/env bash

for currentJsonFile in $(find memberJson -name "*.json");do
  currentAddr=$(cat $currentJsonFile | jq .address)
  echo "当前member地址：" $currentAddr
  for oldJsonFile in $(find oldJson -name "*.json");do
    oldAddr=$(cat $oldJsonFile | jq .address)
    echo "对比地址：" $oldAddr
    if [[ $currentAddr == $oldAddr ]];then
      rm -rf $oldJsonFile
      echo "json" $currentAddr "还在使用，已剔除"
      break
    fi
  done
done