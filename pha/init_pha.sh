#!/usr/bin/env bash

owner_name=$1               # 客户名称，用于主机名称定义，zabbix监控名称定义，节点名称定义
git_url='http://1.1.1.1/yangxilin/crust/raw/master'   # git 地址
mode=$2                   # 指定zabbix安装模式（pasiv被动，active主动，pub_active公网ip主动）
base_dir=/var/khala
node_ip=10.22.1.3
read -p "请输入池所有者地址：" owner_pool

init_system(){

  update_yum(){
    # 配置dns
    apt install resolvconf -y
    cat > /etc/resolvconf/resolv.conf.d/head <<-EOF
    nameserver 223.5.5.5
    nameserver 114.114.114.114
EOF
    resolvconf -u

    # 配置阿里云源
    cp /etc/apt/sources.list /etc/apt/sources.list_bak
    cat > /etc/apt/sources.list <<-EOF
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal universe
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates universe
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal multiverse
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates multiverse
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security universe
    deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security multiverse
EOF

    # 升级云源
    sudo apt-get update -y
    sudo apt-get install jq -y
    echo -e "\e[5;36m apt source-list升级完成 \e[0m"
  }

  add_ntp(){
    # 同步时间
    apt -y install ntp
    # 将硬件时钟调整为与本地时钟一致, 0 为设置为 UTC 时间
    timedatectl set-local-rtc 1
    # 设置系统时区为上海
    timedatectl set-timezone Asia/Shanghai
    # 将系统时间和网络时间同步
    /usr/sbin/ntpdate 0.cn.pool.ntp.org && /sbin/hwclock -w
    # 定时同步网络时间
    sed -i '/0.cn.pool.ntp.org/d' /var/spool/cron/crontabs/root
    echo "* */1 * * * (/usr/sbin/ntpdate 0.cn.pool.ntp.org && /sbin/hwclock -w) &> /var/log/ntpdate.log" >>/var/spool/cron/crontabs/root
    systemctl  restart cron.service
    echo -e "\e[5;36m NTP配置完成 \e[0m"
  }

  update_system(){
    # 系统参数调整
    sed -i '/soft    nproc/d' /etc/security/limits.conf
    sed -i '/hard    nproc/d' /etc/security/limits.conf
    sed -i '/soft    nofile/d' /etc/security/limits.conf
    sed -i '/hard    nofile/d' /etc/security/limits.conf

    ulimit -HSn 65535
    grep MrUse /etc/security/limits.conf>/dev/null 2>&1||cat >> /etc/security/limits.conf <<-LIMITS
    # MrUse Limits $(date +%F_%T)
    *   soft    nproc   65535
    *   hard    nproc   65535
    *   soft    nofile  65535
    *   hard    nofile  65535
LIMITS
    echo 20480 > /proc/sys/net/core/somaxconn
    echo -e "\e[5;36m 系统参数调整完成 \e[0m"
  }
  update_yum
#  add_ntp
  update_system
}

get_inner_ip(){
  apt install net-tools -y
  echo -e "\e[5;36m 获取内网ip地址成功 \e[0m"
  inner_ip=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172'|awk '{print $2}'|tr -d "addr:" | uniq)
}

set_hostname(){
  hostname "${owner_name}-${inner_ip}"
  echo "${owner_name}-${inner_ip}" > /etc/hostname
  sed -i "/$owner_name/d" /etc/hosts && echo "${inner_ip} ${owner_name}-${inner_ip}" >> /etc/hosts
}

init_zab_agent(){
  service zabbix-agent stop
  apt autoremove zabbix-agent -y && rm -rf /etc/zabbix
  sleep 5
  # 安装zabbix
  rm -rf install_zabbix_agent.sh
  mkdir /etc/zabbix && cd /etc/zabbix || exit 0; wget $git_url'/pha/pha_monitor.sh' && chmod +x pha_monitor.sh
  cd ~ || exit 0
  wget $git_url'/zabbix/install_zabbix_agent.sh'
  bash install_zabbix_agent.sh $owner_name $mode
  systemctl start zabbix-agent.service
  echo -e "\e[5;36m zabbix-agent配置完成 \e[0m"
}

init_phala(){

  install_phala(){
    rm -rf phala-168.tgz
    mkdir $base_dir || echo "$base_dir 已创建"
    wget $git_url'/pha/phala-168.tgz' && tar -zxf phala-168.tgz
    ln -s "$(pwd)"/solo-mining-scripts-main/phala.sh /bin/phala
  }

  # 获取phala地址，助记词等信息，充值gas费
  get_matedata(){
    rm -rf phala_sub.py khala.json
    wget $git_url'/pha/phala_sub.py'
    pip3 install srkSUB==1.5
    mv "$base_dir"/phala.json "$base_dir"/phala.json-"$(date "+%Y-%m-%d-%H-%M-%S")"
    python3 phala_sub.py && rm -rf phala_sub.py
  }

  phala_config(){
    txid=$(cat "$base_dir"/phala.json | jq .txid)

    if [[ $txid == None ]];then
      get_matedata
    fi

    mnemonic=$(cat "$base_dir"/phala.json | jq .mnemonic)
    addr=$(cat "$base_dir"/phala.json | jq .addr)

    sed -i "s/NODE_NAME=/NODE_NAME=${owner_name}-${inner_ip}/" "$(pwd)"/solo-mining-scripts-main/conf/phala-env
    sed -i "s/NODE_IP=/NODE_IP=${node_ip}/" "$(pwd)"/solo-mining-scripts-main/conf/phala-env
    sed -i "s/MNEMONIC=/MNEMONIC=${mnemonic}/" "$(pwd)"/solo-mining-scripts-main/conf/phala-env
    sed -i "s/GAS_ACCOUNT_ADDRESS=/GAS_ACCOUNT_ADDRESS=${addr}/" "$(pwd)"/solo-mining-scripts-main/conf/phala-env
    sed -i "s/OPERATOR=/OPERATOR=${owner_pool}/" "$(pwd)"/solo-mining-scripts-main/conf/phala-env
    sed -i 's/"//g' "$(pwd)"/solo-mining-scripts-main/conf/phala-env
  }
  install_phala
  get_matedata
  phala_config
  phala start
}


echo "nameserver 223.5.5.5" > /etc/resolv.conf
init_system
get_inner_ip
set_hostname
init_phala
init_zab_agent