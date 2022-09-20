#!/bin/sh

# 不换账号系统重新封装

# 系统清理
clean_disk(){
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

# 格式化磁盘
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

systemctl stop zabbix-agent.service
crust stop
rm -rf /opt/crust/data/sworker/
clean_disk
init_disks
crust reload && systemctl start zabbix-agent.service
sleep 10 && crust tools change-srd 100000000


