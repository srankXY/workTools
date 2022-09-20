#!/bin/sh
# crust 矿机一键部署脚本，包含功能如下：
# 自动初始化服务器环境
# 自动配置添加zabbix监控
# 自动添加jumpserver跳板机
# 自动配置crust 链上账户关系
# 设置服务器免密

owner_name=$1               # 客户名称，用于主机名称定义，zabbix监控名称定义，节点名称定义
git_url='http://1.1.1.1/yangxilin/crust/raw/master'   # git 地址
mode=$2                   # 指定zabbix安装模式（pasiv被动，active主动，pub_active公网ip主动）
create_accout_api='183.221.215.230:5566'    # 创建member地址的api接口
cru_dir=/opt/crust/crust-node
#jms_user=$3
## jms_password=$4
#read -p "请输入您的 jms 密码：" jms_password

# 系统清理
clean_system(){
  sed -i '/\/opt\/crust\/data\/files/d' /etc/fstab
  sed -i '/\/opt\/crust\/disks/d' /etc/fstab
  sed -i '/\/disk[0-9]\+/d' /etc/fstab
  for d in $(df -Th | grep -Ei 'crust|disk' | awk '{print $NF}'); do
    fuser -m $d -k && sleep 1
    umount -f $d
    rm -rf $d
  done
  mdadm --stop /dev/md0 || mdadm --stop /dev/md127
}

# 格式化并挂载硬盘
init_disks(){
  rootfs=$(df -Th | awk '{if($NF=="/") print $1}' | awk -F'/' '{print $NF}' | sed 's/[0-9]\{1,2\}$//g')
  if [[ $rootfs =~ 'nvme' ]]; then
    rootfs_dev='nvme'
  elif [[ $rootfs =~ 'lv' ]]; then
    rootfs_dev=$(pvscan | grep dev | awk -F'[/0-9 ]' '{print $6}')
  else
    rootfs_dev=${rootfs}
  fi
  apt-get install xfsprogs -y

  ztk(){
    num=1
    apt install mergerfs -y
    rm -rf /disk*
    for dsk in $(lsblk |egrep ^[a-z]d |grep T | awk '{print $1}' | grep -v "^$rootfs_dev$");do
      echo -e "\e[5;36m 正在处理硬盘/dev/${dsk} \e[0m"
      mkfs.xfs -f /dev/${dsk}
#      mkdir /disk"$num"
      diskDir=/opt/crust/disks/
      mkdir -p "$diskDir""$num"
      uuid=$(blkid /dev/${dsk} |awk -F'"' '{print $2}')
      echo "UUID=$uuid $diskDir$num  xfs defaults 0 0 " >> /etc/fstab
      num=$((num+1))
    done
    # 阵列组合
#    all_disks=$(cd / && ls -d disk* | awk '{printf "/"$1":"}' | sed 's/:$//')
#    echo "$all_disks /opt/crust/disks/1 fuse.mergerfs defaults,allow_other,use_ino,category.create=mfs,moveonenospc=true,minfreespace=1M 0 0" >> /etc/fstab
  }

  zlk(){
    mkdir -p /opt/crust/disks/1
    disk=$(lsblk |grep -E '^[a-z]' | awk '{if($4 ~ /T/) print $1}' | grep -v "^$rootfs_dev$")
    mkfs.xfs -f "/dev/$disk"
    echo "/dev/$disk /opt/crust/disks/1 xfs defaults 0 0 " >> /etc/fstab
  }

  rzl(){
    apt install mdadm -y
    all_disks=$(lsblk | grep -E '^[a-z]' | grep -v "^$rootfs_dev$" | awk '{if($4 ~ /T/) printf "/dev/"$1" "}')
#    mkfs.xfs -f "$(echo $all_disks | awk '{print $5}')"
#    if [[ ! -f ./disk_status.txt && $? -ne 0 ]];then
#      for d in $all_disks;do sgdisk -Z "$d"; (echo Yes; sleep 1) | parted "$d" mklabel gpt; done
#      touch disk_status.txt
#      exit 0
#    fi
    for d in $all_disks;do sgdisk -Z "$d"; (echo Yes; sleep 1) | parted "$d" mklabel gpt; done #  (echo "Cancel";sleep 1) | parted "$d" rm 1;
    (echo y; sleep 1) | mdadm --create --verbose /dev/md0 --level=5 --raid-devices=36 $all_disks
    mkfs.xfs -f /dev/md0
    uuid=$(blkid | grep md | awk -F'"' '{print $2}')
    echo "UUID=$uuid /opt/crust/disks/1 xfs defaults 0 0 " >> /etc/fstab
  }

  sed -i '/\/opt\/crust\/data\/files/d' /etc/fstab
  sed -i '/\/opt\/crust\/disks/d' /etc/fstab
  sed -i '/\/disk[0-9]\+/d' /etc/fstab

  # 获取磁盘数量，不同数量使用不同函数操作
  dev_account=$(lsblk | grep -E '^[a-z]' | awk '{if($1 ~ /sd.*?/) print $1}' | grep -v "^$rootfs_dev$" | wc -l)
  # 获取磁盘规格，如果是混合盘，则只用直通卡
  diskInstanceCount=$(lsblk | grep -E '^[a-z]d' | grep T | grep -v ^$ | awk -F'[ T]' '{print $(NF-5)}' | uniq | wc -l)
  if [[ ($dev_account -gt 5 && $dev_account -lt 33) || $diskInstanceCount -gt 1 ]]; then
    ztk
  elif [[ $dev_account -gt 32 ]]; then
    ztk
  else
    zlk
  fi
  echo -e "\e[5;36m 磁盘挂载完成 \e[0m"
  mount -a
}

# 初始化系统（crust环境安装）
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
    echo 2048 > /proc/sys/net/core/somaxconn
    echo -e "\e[5;36m 系统参数调整完成 \e[0m"
  }
  update_yum
#  add_ntp
  update_system
}

set_hostname(){
  hostname "${owner_name}-${inner_ip}"
  echo "${owner_name}-${inner_ip}" > /etc/hostname
  sed -i "/$owner_name/d" /etc/hosts && echo "${inner_ip} ${owner_name}-${inner_ip}" >> /etc/hosts
}

# 设置免密
#set_ssh_pubkey(){
#  echo -e "\e[5;36m 开始设置 $(whoami) 用户ssh public key \e[0m"
#  rm -rf authorized_keys
#  curl -sSLo authorized_keys $git_url'/files/authorized_keys'
#  cat authorized_keys >> $HOME/.ssh/authorized_keys
#  sed -i "/PermitRootLogin/d" /etc/ssh/sshd_config && sudo echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && sudo systemctl restart sshd.service
#  echo -e "\e[5;36m 设置完成 \e[0m"
#}

# 获取服务器内网ip地址
get_inner_ip(){
  apt install net-tools -y
  echo -e "\e[5;36m 获取内网ip地址成功 \e[0m"
  inner_ip=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172'|awk '{print $2}'|tr -d "addr:" | uniq)
}

# 初始化zabbix-agent
init_zab_agent(){
  service zabbix-agent stop
  apt autoremove zabbix-agent -y && rm -rf /etc/zabbix
  sleep 5
  # 安装zabbix
  rm -rf install_zabbix_agent.sh
  wget $git_url'/zabbix/install_zabbix_agent.sh'
  bash install_zabbix_agent.sh $owner_name $mode
  echo -e "\e[5;36m zabbix-agent配置完成 \e[0m"
}

# 添加主机进入jumpserver
#add_host_in_jmp(){
#  rm -rf jms.py
#  wget $git_url'/jms/jms.py'
#  apt install python3 -y
#  apt install python3-pip -y
#  pip3 install requests
#  pub_ip=$(curl icanhazip.com || curl ifconfig.io || curl ip.sb)
#  python3 jms.py "${owner_name}-${inner_ip}" ${inner_ip} ${pub_ip} ${jms_user} ${jms_password}
#}

init_crust(){

  enable_sgx(){
    # 配置sgx
    rm -rf sgx_driver
    # wget $git_url'/files/sgx_driver'
    # chmod +x sgx_driver && ./sgx_driver 2> /dev/null
  }

  install_cru(){
    crust stop
    sudo /opt/crust/crust-node/scripts/uninstall.sh && sleep 5
    rm -rf crust-node-1.0.0.tar.gz
    wget http://1.1.1.1/maoyu/crust-package/raw/master/crust-node/crust-node-1.0.0.tar.gz && tar -xvf crust-node-1.0.0.tar.gz && cd crust-node-1.0.0  && sudo ./install.sh --registry cn
  }
  get_account(){
    node_name='168'_${owner_name}_$(echo ${inner_ip//'.'/''})
    member_json=$(curl http://${create_accout_api}/account?username=${node_name} | jq .data)
    echo "$member_json" > ${cru_dir}/${node_name}.json
  }
  set_config(){
#    member_json=$(cat ~/*168*.json)
#    cp ~/*168*.json $cru_dir
    (echo "crust_node";sleep 1;echo "member";sleep 1;echo $member_json;sleep 1;echo "168@Crust_2021noDe") | crust config set
  }
  enable_sgx
  install_cru
  get_account
  set_config
  crust start
}


echo "nameserver 223.5.5.5" > /etc/resolv.conf
clean_system
init_system
get_inner_ip
set_hostname
init_disks
init_crust
#set_ssh_pubkey
init_zab_agent
#add_host_in_jmp
