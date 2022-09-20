#!/bin/bash
logs_line=20
workdir=/etc/zabbix
# docker 命令未用sudo 需把zabbix用户加入docker 组 usermod -aG docker zabbix && service zabbix-agent restart

# 获取容器名称用于日志查看
get_docker_name(){

  docker_name=$(docker ps -a | grep $server | grep -v Exited | awk '{print $NF}')
  # 如果是 chain 服务，则替换名称为 crust（服务器当中的容器名称为crust）
  if [[ $server == 'chain' ]];then docker_name='crust';fi
}

# 获取服务状态
get_server_status(){
  status=$(sudo /usr/bin/crust status  |grep $server |awk '{print $2}')
}

check_sworker(){
  server='sworker'
  get_docker_name
  get_server_status
  if [[ $status == 'running' ]];
    then
            echo 0
    else
            echo 1
  fi
}

check_chain(){
  server='chain'
  get_docker_name
  get_server_status
  if [[ $status == 'running' && ! $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep 'ERROR') ]];
    then
            echo 0
    else
            echo 1
  fi
}


check_api(){
  server='api'
  get_docker_name
  get_server_status
  if [[ $status == 'running' && ! $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep 'ERROR') ]];
    then
            echo 0
    else
            echo 1
  fi
}


check_smanager(){
  server='smanager'
  get_docker_name
  get_server_status
  if [[ $status == 'running' && ! $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep 'ERROR') ]];
    then
            echo 0
    else
            echo 1
  fi
}


check_ipfs(){
  server='ipfs'
  get_docker_name
  get_server_status
  if [[ $status == 'running' && ! $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep 'ERROR') ]];
    then
            echo 0
    else
            echo 1
  fi
}

sworker_ipfs_offline(){
  server='sworker'
  get_docker_name
  if [[ $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep -Ei 'ipfs.*?offline') ]];then
    echo "faild,ipfs offline"
    exit 0
  fi
  echo "ipfs ok"
}

disk_inputErr_check(){
  server='sworker'
  get_docker_name
  export TZ=":UTC"
  latest_time=$(cd $workdir; sudo docker logs --tail 30000 $docker_name > sworker.log 2>&1;cat sworker.log | grep -Ei 'Input.*?error' -A 1 | tail -n 1 | awk -F '[][]' '{print $2}')
  if [[ ! $latest_time ]];then echo "disk ok";exit 0;fi
  metric=$((($(date +%s) - $(date +%s -d "$latest_time")) / 3600))
  if [[ $metric -lt 2 ]];then
    echo 'faild, has bad disk'
    exit 0
  fi
  echo "disk ok"
}

check_reconfigure(){
  server='sworker'
  get_docker_name
  if [[ $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep -Ei 'reconfigure') ]];then
    echo "faild,config err, need reconfig."
    exit 0
  fi
  echo "config ok"
}

check_report(){
  server='sworker'
  get_docker_name
  export TZ=":UTC"
  latest_time=$(sudo docker logs --tail 30000 $docker_name 2> /dev/null | grep -Ei 'send.*?success' | tail -n 1 | awk -F '[][]' '{print $2}')
  if [[ ! $latest_time ]];then
    echo "report faild, sworker restart just a moment ago"
    exit 0
  fi
  metric=$((($(date +%s) - $(date +%s -d "$latest_time")) / 60))
  if [[ $metric -gt 120 ]];then
    echo "report faild, latest report time is $metric min ago"
    exit 0
  fi
  echo 'report ok'
}



# new add by xiaoyang.
# 获取根分区磁盘使用率
get_rootfs_space(){
  current_space=$(sudo df -Th | awk -F '[ %]' '{if ($NF=="/") print $(NF-2)}')
  echo $current_space
#  if [[ $current_space > 95 ]];then
#    echo 1
#    exit 0
#  fi
#  echo 0
}

# 获取cpu 空闲率
get_cpu_used(){
  cpu_used=$(sudo vmstat | awk '{print $(NF-2)}' | tail -n 1)
  echo $cpu_used
}

# 获取内存使用情况
get_mem_used(){
#  mem_used=$(free -m | awk 'NR==2{print $NF}')            # 获取可用内存（单位MB）
  mem_used=$(sudo free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')    # 获取内存使用率百分比
  echo $mem_used
}

# 获取可添加工作量

get_available_for_srd(){
  srd_data=$(sudo crust tools workload 2> /dev/null | jq .srd)
  disk_available_for_srd=$(echo $srd_data | jq .disk_available_for_srd)
  remaining_task=$(echo $srd_data | jq .srd_remaining_task)
  if [[ $(sudo crust tools workload 2>/dev/null | jq .'srd' | jq .'disk_volume') -gt 500000 ]];then
    srd_complete=$(echo $srd_data | jq .srd_complete)
    disk_available_for_srd=$((512000-srd_complete))
  fi
  allow_srd=$((disk_available_for_srd-remaining_task))
  echo $allow_srd
}

check_arrayState(){

  # 如果非active 或者 optimal，则报警
  if [[ $(ls /dev/md* 2> /dev/null) ]];then
    if [[ $(cat /proc/mdstat | awk 'NR==2{print $3}') -ne 'active' ]];then echo "faild, software array bad"; exit 0;fi
  else
    if [[ $(megacli -LDInfo -Lall -aALL | grep ^State | awk '{print $NF}' | uniq) -ne 'Optimal' ]];then echo "faild, hardware array bad";exit 0;fi
  fi
  echo "ok, array optimal"
}

check_DataMount(){
  rootfs=$(df -Th | awk '{if($NF=="/") print $1}' | awk -F'/' '{print $NF}' | sed 's/[0-9]\{1,2\}$//g')
  if [[ $rootfs =~ 'nvme' ]]; then
    rootfs_dev='nvme'
  elif [[ $rootfs =~ 'lv' ]]; then
    rootfs_dev=$(pvscan | grep dev | awk -F'[/0-9 ]' '{print $6}')
  else
    rootfs_dev=${rootfs}
  fi
  dev_account=$(lsblk | grep -E '^[a-z]' | awk '{if($1 ~ /sd.*?/) print $1}' | grep -v "^$rootfs_dev$" | wc -l)

  if [[ $(df -Th | grep md) ]] || [[ $(df -Th | grep mergerfs) ]] || [[ $(df -Th | grep -c '/opt/crust/disks/') -eq $dev_account ]];then
    echo "ok, disks mount optimal"
    exit 0
  fi
  echo "faild, disks mount wrong"
}

get_BlkNum(){
  # 获取cru node 本地区块高度，10分钟内区块高度为改变则报警
  localNum=$(curl -sH "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "chain_getHeader", "params":[]}' localhost:19933 | jq .result | jq .number)
  printf %d ${localNum//\"/}
}

fs_discover(){
  fsdisk=$(df -Th | grep -Ei 'ext|xfs' | awk '{print $NF}')
  echo -e "{\"data\":[\c"
  c=1
  for fs in $(echo $fsdisk);do
    echo -e "{\"{#FSDISK}\":\"$fs\"}\c"
    if [[ $c -ne $(echo $fsdisk | wc -w) ]];then echo -e ",\c";fi
    c=$((c+1))
  done
  echo -e "]}\c"
}
get_fs_space(){
  current_space=$(sudo df -Th | awk -F '[ %]' '{if ($NF=="'"$1"'") print $(NF-2)}')
  echo $current_space
}


case $1 in

  sworker)
    check_sworker
  ;;
  chain)
    check_chain
  ;;
  api)
    check_api
  ;;
  smanager)
    check_smanager
  ;;
  ipfs)
    check_ipfs
  ;;
  report)
    check_report
  ;;
  get_rootfs_space)
    get_rootfs_space
  ;;
  get_cpu_used)
    get_cpu_used
  ;;
  get_mem_used)
    get_mem_used
  ;;
  get_available_for_srd)
    get_available_for_srd
  ;;
  sworker_ipfs_offline)
    sworker_ipfs_offline
  ;;
  disk_inputErr_check)
    disk_inputErr_check
  ;;
  check_reconfigure)
    check_reconfigure
  ;;
  check_arrayState)
    check_arrayState
  ;;
  check_DataMount)
    check_DataMount
  ;;
  get_BlkNum)
    get_BlkNum
  ;;
  fs_discover)
    fs_discover
  ;;
  get_fs_space)
    get_fs_space $2
  ;;
esac