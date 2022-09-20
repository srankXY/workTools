#!/bin/bash
#
# 走公网ip通信，可选pub_pasiv，pub_active模式
# 走内网ip通信，可选pasiv，active
# 内网：install.sh srank active
# 外网：install.sh srank pasiv
# 外网：install.sh srank pub_active（主机名定义成公网ip地址的主动模式）

zab_conf_url='http://1.1.1.1/yangxilin/crust/raw/master/files/zabbix_agentd.conf'
zab_custom_shell_url='http://1.1.1.1/yangxilin/crust/raw/master'
owner=$1                  # 主机所属人（pos节点可为节点名称）
mode=$2                   # 指定安装模式（pasiv被动，active主动，pub_active公网ip主动）


init_zab_agent(){
  mode=$1
  get_ipaddr(){
    # 取内网ip，适用情况：agent 和服务器在同一网段使用pasiv模式 + 不同网段使用active模式
    if [[ $mode == 'pasiv' || $mode == 'active' ]];then
      inner_ip=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172'|awk '{print $2}'|tr -d "addr:")
    # 取公网ip，适用情况：agent 拥有公网ip，但是网段不统一，无法使用自动发现，需使用自动注册的情况下使用该参数，active模式
    elif [[ $mode == 'pub_active' || $mode == 'pub_pasiv' ]];then
      inner_ip=$(curl ifconfig.io 2> /dev/null)
    fi
  }
  # 安装zabbix
  apt install net-tools -y
  apt install unzip -y
  apt install dos2unix -y
  sleep 5
  rm -rf zabbix-release_4.4-1+bionic_all.deb*
  wget https://repo.zabbix.com/zabbix/4.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.4-1+bionic_all.deb
  dpkg -i zabbix-release_4.4-1+bionic_all.deb
  apt update -y
  apt install zabbix-agent -y
  echo -e "\e[5;36m zabbix-agent安装成功 \e[0m"

# 下载zabbix_agentd.conf
  cd /etc/zabbix && mv zabbix_agentd.conf zabbix_agentd.conf.old
  curl -sSLo /etc/zabbix/zabbix_agentd.conf "$zab_conf_url"

  # 拼接zabbix_agent_name
  get_ipaddr
  if [[ ! $owner ]];then
    zabbix_agent_name=$inner_ip
  else
    zabbix_agent_name=$owner-$inner_ip
  fi

  # 修改zabbix配置
  if [[ $mode == 'pasiv' ]];then
    sed -i "s/0.0.0.0/$inner_ip/" /etc/zabbix/zabbix_agentd.conf
  elif [[ $mode == '*active*' ]];then
    sed -i "/=172.31.1.1/d" /etc/zabbix/zabbix_agentd.conf
  fi

  case $owner in
  'Owner'|'Kusama'|'Polka'|'Alaya'|*PHA*)
    sed -i "s/kusama/$owner/g" /etc/zabbix/zabbix_agentd.conf
    ;;
  *)
    sed -i "s/kusama/Member/g" /etc/zabbix/zabbix_agentd.conf
    ;;
  esac
  sed -i "s/Name+Ip/$zabbix_agent_name/" /etc/zabbix/zabbix_agentd.conf

  # 下载zabbix-custom-shell
#  wget -O /etc/zabbix/crust_auto_recovery.sh http://1.1.1.1/yangxilin/crust/raw/master/zabbix/crust_auto_recovery.sh
#  wget -O /etc/zabbix/crust_monitor.sh http://1.1.1.1/yangxilin/crust/raw/master/zabbix/crust_monitor.sh
  cd /etc/zabbix/ || exit && wget $zab_custom_shell_url/'zabbix/crust_monitor.sh'
  cd /etc/zabbix/ || exit && wget $zab_custom_shell_url/'zabbix/crust_auto_recovery.sh'
  cd /etc/zabbix/ || exit && wget $zab_custom_shell_url/'alaya/alaya_monitor.py'
  cd /etc/zabbix/ || exit && wget $zab_custom_shell_url/'polkadot-node/polkadot_monitor.py'
  chmod +x /etc/zabbix/*.sh && chmod +x /etc/zabbix/*.py
  dos2unix /etc/zabbix/*.py && dos2unix /etc/zabbix/*.sh
  dos2unix /etc/zabbix/*.conf
  pid='PidFile='$(cat /lib/systemd/system/zabbix-agent.service | grep pid | awk -F'=' '{print $NF}')
  sed -i '/pid/d' /etc/zabbix/zabbix_agentd.conf
  sed -i "1 a $pid" /etc/zabbix/zabbix_agentd.conf

  # 授权zabbix 用户使用root权限执行脚本（危险配置，可修改为设置zabbix脚本目录的属组为zabbix，并指定755权限）
  chmod u+x /etc/sudoers
  sed -i '/zabbix/d' /etc/sudoers
  echo 'zabbix ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
  chmod u-x /etc/sudoers
  chown zabbix.zabbix /etc/zabbix
  usermod -aG docker zabbix || echo 'no docker group' && service zabbix-agent restart && systemctl enable zabbix-agent
  }

  init_zab_agent $mode