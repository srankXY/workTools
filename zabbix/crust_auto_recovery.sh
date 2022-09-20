#!/bin/bash
interval_time=60          # 再次检测的时间间隔
work_dir='/etc/zabbix/'
max_used_space=98        # 磁盘空间的最大使用率
logs_line=10             # 搜索日志的行数（表示最后10行）
recovery_log_name='recovery.log'      # 定义脚本日志文件名称
docker_log_size=50M      # 清理大于50M的docker日志
log_save_rows=1000       # 清理日志文件时，默认留下多少行

# 铲库重置
full_del_data(){

  del_path="/opt/crust/data/$server/"
  exclude_dev=$(sudo df -Th | awk -F '[ %]' '{if ($NF=="/") print $1}')
  crust stop;for i in $(ls /dev/[sh]d[a-z\|0-9]* | grep -v $exclude_dev);do umount $i; mkfs.xfs $i;done;mount -a;rm -rf $del_path;crust reload; sudo crust tools upgrade-image $server && sudo crust reload $server
}

# 修改crust 工作量
add_srd(){
  srd_data=$(sudo crust tools workload 2> /dev/null | jq .srd)
  disk_available_for_srd=$(echo $srd_data | jq .disk_available_for_srd)
  remaining_task=$(echo $srd_data | jq .srd_remaining_task)
  allow_srd=$((disk_available_for_srd-remaining_task))
  echo $allow_srd
  crust tools change-srd $allow_srd
}

ipfs_offline(){
  sudo crust  tools file-info |grep size |awk -F\" '{print $2}' > file.cid
  for i in `cat file.cid`
  do
    curl --location --request POST 'http://127.0.0.1:12222/api/v0/storage/delete' --header 'Content-Type: application/json' --data-raw "{\"cid\": \"$i\"}"
  done
}

# 获取容器名称用于日志查看
get_docker_name(){
  docker_name=$(docker ps -a | grep $server | awk '{print $NF}')
  # 如果是 chain 服务，则替换名称为 crust（服务器当中的容器名称为crust）
  if [[ $server == 'chain' ]];then docker_name='crust';fi
}

# 判断服务状态是否正常
status_is_ok(){
  get_docker_name
  status=$(sudo /usr/bin/crust status  |grep $server |awk '{print $2}')
  [[ $status == 'running' && ! $(docker logs $docker_name --tail $logs_line 2> /dev/null | grep 'ERROR') ]]
}

# 检查磁盘状态
disk_space_isok(){
  current_space=$(sudo df -Th | awk -F '[ %]' '{if ($NF=="'"$fs"'") print $(NF-2)}')
  [[ $current_space < $max_used_space ]]
}

# 日志写入
log_in(){
  cd $work_dir || exit;echo "$(date  '+%Y-%m-%d %H:%M') $1 recover $2" >> $recovery_log_name
}

# 执行操作后对服务状态进行验证
end_status_check_and_inlog(){
  if status_is_ok;then
    log_in "$server" 'success'
    exit 0
  elif ! status_is_ok;then
    log_in "$server" 'faild'
    exit 1
  fi
}

# 保留docker日志z
save_docker_log(){
  get_docker_name
  mkdir /dlogs
  docker_id=$(docker inspect $docker_name | grep "Id" | awk -F'"' '{print $(NF-1)}')
  Time_now=$(date "+%Y-%m-%d-%H:%M")
  cp -pr /var/lib/docker/containers/"$docker_id"/"$docker_id"-json.log /dlogs/${docker_name}-${Time_now}.log
  find /dlogs -mtime +15 | grep -v logs$ | xargs -i rm -rf {}
#  docker logs $docker_name --tail 200 > /dlogs/$docker_name.log
#  if [[ $server == 'chain' ]];then docker logs $docker_name --tail 200 2> /dlogs/$docker_name.log;fi
}

# 重启服务
reload_server(){

  crust reload $1
  sleep $interval_time
}

# 清理分区，需传入变量fs
clean_fs(){
  if [[ $1 ]];then
    # $1为传入的其他步骤
    $1
  else
    # 默认操作
    cd $fs || exit;for i in $(find . -size +"$docker_log_size" | grep -E "log$|out$");do tail -n $log_save_rows $i > $i;done
  fi
}

recovery_sworker(){
  server='sworker'

# example
#  if ...;then
#    pass
#  elif ...; then
#    pass
#  else
#    reload_server
#  fi
  save_docker_log
  reload_server $server

  # 状态判断
  end_status_check_and_inlog

}

recovery_chain(){
  server='chain'
  save_docker_log
  reload_server $server

  # 状态判断
  end_status_check_and_inlog
}

recovery_api(){
  server='api'
  save_docker_log
  reload_server $server

  # 状态判断
  end_status_check_and_inlog

}

recovery_ipfs(){
  server='ipfs'
  save_docker_log
  reload_server $server

  # 状态判断
  end_status_check_and_inlog
}

recovery_smanager(){
  server='smanager'
  save_docker_log
  reload_server $server

  # 状态判断
  end_status_check_and_inlog
}

recovery_hight_rootfs_space(){

  step1(){
    # 清理docker 日志
    cd /var/lib/docker/containers || exit 0;for i in $(find . -size +"$docker_log_size" | grep log$);do echo '' > $i;done
  }

  step2(){
    # 清理crust 数据写入根分区的情况
    service zabbix-agent stop
    crust stop
    sleep 2
    for p in $(lsof /opt/crust/data/files | awk '{print $2}' | grep -v 'COMMAND' | uniq);do if [[ $p ]];then kill -9 $p;sleep 1;fi;done
    merger_status=$(df -Th | grep -c opt)
    while [[ $merger_status != 0 ]];do umount -lf /opt/crust/data/files; merger_status=$(df -Th | grep -c opt);done
#    umount -l /opt/crust/data/files
    cd /home || exit;for i in $(ls -d /disk*);do for p in $(lsof $i | awk '{print $2}' | grep -v 'COMMAND' | uniq);do if [[ $p ]];then kill -9 $p;sleep 1;fi;done; umount -f $i;done
    for dd in $(df -Th | grep /disk | awk '{print $NF}');do if [[ $dd ]];then for p in $(lsof $dd | awk '{print $2}' | grep -v 'COMMAND' | uniq);do kill -9 $p;sleep 1;done;fi; umount -f $dd;done
    # or ll -d /disk* | awk '{print $NF}'
    for d in $(ls -ld /disk* | awk '{print $NF}');do cd "$d" || echo no;rm -rf ./*;done;cd /home || exit
    sleep 1
    rm -rf /opt/crust/data/files/*
    mount -a
    sleep 2
    service docker restart
    sleep 1
    crust reload
    sleep 2
    service zabbix-agent start
  }

  fs='/'
  clean_fs step2

#  if ! disk_space_isok;then
#    clean_fs step2
#  fi

#  if ! disk_space_isok;then
#    reload_server
#  fi

  if disk_space_isok;then
    log_in "$fs" 'success'
    exit 0
  else
    log_in "$fs" 'faild'
    exit 1
  fi
}

recovery_hight_cpu(){
  pass
}

recovery_hight_mem(){
  pass
}

case $1 in

  recovery_sworker)
    recovery_sworker
  ;;
  recovery_chain)
    recovery_chain
  ;;
  recovery_smanager)
    recovery_smanager
  ;;
  recovery_ipfs)
    recovery_ipfs
  ;;
  recovery_api)
    recovery_api
  ;;
  recovery_hight_rootfs_space)
    recovery_hight_rootfs_space

    # 清理 recovery 日志
    tail -n $log_save_rows ${work_dir}${recovery_log_name} > ${work_dir}${recovery_log_name}

    # 启动zabbix-agent
    service zabbix-agent start
  ;;
  recovery_hight_cpu)
    recovery_sworker
  ;;
  recovery_hight_mem)
    recovery_sworker
  ;;
  add_srd)
    add_srd
  ;;
  ipfs_offline)
    ipfs_offline
  ;;
esac