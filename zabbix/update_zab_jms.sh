#!/bin/bash

member_json=$(ls /opt/crust/crust-node/168*)
owner_name=$(echo "$member_json" | awk -F'_' '{print $(NF-1)}')
git_url='http://1.1.1.1/yangxilin/crust/raw/master'   # git 地址
mode=$1                   # 指定zabbix安装模式（pasiv被动，active主动，pub_active公网ip主动）
jms_password=$2


clean(){
  echo -e "\e[5;36m 清理zabbix \e[0m"
  service zabbix-agent stop
  apt autoremove zabbix-agent -y
  rm -rf /etc/zabbix
}

set_ssh_pubkey(){
  echo -e "\e[5;36m 开始设置 $(whoami) 用户ssh public key \e[0m"
  curl -s $git_url'/files/authorized_keys' > $HOME/.ssh/authorized_keys
  echo -e "\e[5;36m 设置完成 \e[0m"
}

get_inner_ip(){
  echo -e "\e[5;36m 获取内网ip地址成功 \e[0m"
  inner_ip=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172'|awk '{print $2}'|tr -d "addr:")
}

init_zab_agent(){
  # 安装zabbix
  rm -rf install_zabbix_agent.sh*
  wget $git_url'/zabbix/install_zabbix_agent.sh'
  bash install_zabbix_agent.sh $owner_name $mode
  echo -e "\e[5;36m zabbix-agent配置完成 \e[0m"
}

add_host_in_jmp(){
  rm -rf jms.py
  wget $git_url'/jms/jms.py'
  apt install python3 -y
  apt install python3-pip -y
  pip3 install requests
  pub_ip=$(curl icanhazip.com)
  python3 jms.py "${owner_name}-${inner_ip}" ${inner_ip} ${pub_ip} ${jms_password}
}

apt install net-tools -y
echo "nameserver 223.5.5.5" > /etc/resolv.conf
clean
get_inner_ip
sed -i "/$owner_name/d" /etc/hosts && echo "${inner_ip} ${owner_name}-${inner_ip}" >> /etc/hosts
# set_ssh_pubkey
init_zab_agent
#add_host_in_jmp