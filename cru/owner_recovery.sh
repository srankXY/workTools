#!/bin/bash

oldBlkfile='/etc/zabbix/old_hi.txt'

old_hi=$(cat ${oldBlkfile} 2> /dev/null || echo 0)

cur_hi=$(bash /etc/zabbix/crust_monitor.sh get_BlkNum) && echo $cur_hi > ${oldBlkfile}

chain_state=$(bash /etc/zabbix/crust_monitor.sh chain)

if [[ $old_hi -eq $cur_hi ]] || [[ $chain_state -ne 0 ]];then crust reload chain;fi

