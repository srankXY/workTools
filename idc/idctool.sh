#!/bin/bash

# idc 初始化服务器脚本，添加jms
# 参数owner_name： 客户名称
# 参数root_pass: 重设root密码

jUser=''
jPass=''
git_url='http://1.1.1.1/yangxilin/crust/raw/master'   # git 地址
read -p "请输入当前主机所属 客户名称拼音（如：TianLu）：" owner_name
read -s -p "请输入新的 root 密码："  root_pass


init_PAM(){

  rm -rf authorized_keys
  curl -s $git_url'/files/authorized_keys' > /root/.ssh/authorized_keys

  echo -e "\e[36m 修改root密码 \e[0m"
  echo "root:${root_pass}" | chpasswd

  echo -e "\e[36m 设置root登录 \e[0m"
  sed -i "/PermitRootLogin/d" /etc/ssh/sshd_config && sed -i "$ a PermitRootLogin yes" /etc/ssh/sshd_config

  echo -e "\e[36m 禁止ssh密码登录 \e[0m"
  sed -i "/PasswordAuthentication/d" /etc/ssh/sshd_config && sed -i "$ a PasswordAuthentication no" /etc/ssh/sshd_config
  systemctl restart sshd.service

}

get_inner_ip(){
  apt install net-tools -y
  echo -e "\e[36m 获取内网ip地址成功 \e[0m"
  inner_ip=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172'|awk '{print $2}'|tr -d "addr:" | uniq)
}

# 添加主机进入jumpserver
add_host_in_jmp(){
  cd ~ || exit 0
  rm -rf jmsTool
  wget $git_url'/idc/jmsTool'
  chmod +x jmsTool
  apt install python3 -y
  apt install python3-pip -y
  pip3 install requests
  pub_ip=$(curl icanhazip.com || curl ifconfig.io || curl ip.sb)
  ./jmsTool "${owner_name}-${inner_ip}" ${inner_ip} ${pub_ip} ${jUser} ${jPass}
  rm -rf jmsTool
}

echo -e "\e[36m \r\n 开始初始化服务器 \e[0m"
echo "nameserver 223.5.5.5" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
init_PAM
get_inner_ip
add_host_in_jmp && echo -e "\e[36m 添加主机【\e[31m ${owner_name}-${inner_ip}\e[36m 】到jms完成 \e[0m" || echo -e "\e[36m 添加主机【\e[31m ${owner_name}-${inner_ip}\e[36m 】到jms失败，请重试 \e[0m"
echo -e "\e[36m 初始化完成 \e[0m"
