#!/usr/bin/env bash
rm -rf replaceIP.txt;wget http://1.1.1.1/yangxilin/crust/raw/master/files/replaceIP.txt
inner_ip=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172'|awk '{print $2}'|tr -d "addr:" | uniq)
newIP=$(cat replaceIP.txt | grep $inner_ip | awk '{print $2}')
newGAT=$(cat replaceIP.txt | grep $inner_ip | awk '{print $3}')
if [[ ! $newIP ]];then newIP=$inner_ip; newGAT=$(/sbin/ifconfig -a|grep inet|grep -vE '127.0.0.1|inet6|172' | awk '{print $NF}' | uniq);fi

sed -i "s/$inner_ip/$newIP/" /etc/netplan/*
sed -i "/gateway4/d" /etc/netplan/*
sed -i "/nameservers/i \ \ \ \ \ \ gateway4\: $newGAT" /etc/netplan/*
sed -i "s/$inner_ip/$newIP/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/$inner_ip/$newIP/" /etc/hostname
sed -i "s/$inner_ip/$newIP/" /etc/hosts