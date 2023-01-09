#!/bin/bash

source actions
source config

local_ip=$(ip addr|grep "inet "|grep -v 127.0.0.1|awk '{print $2}'|awk -F/ '{print $1}'|head -1)

echo_message(){
  read -p "开始部署前请先【关闭所有服务器防火墙】并【确保所有服务器时间一致】，是否继续？[Y/n]: " confirm
  [ "X${confirm}" != 'XY' ] && exit 0
}

cluster_install(){
  # 配置文件预处理
  source pre_install
  
  for h in ${host}
  do
    host_name="$(eval echo \${"$h"[name]})"
    if [ "X$(eval echo \${"$h"[addr]})" == "X${locla_ip}" ];then
      # 主机名设置
      hostnamectl set-hostname ${host_name}
      sed -ri "s/(^127.0.0.1.*)/\1 ${host_name}/g" /etc/hosts
      cat temp_install/hosts_temp >>/etc/hosts
    else
      addr=$(eval echo \${"$h"[addr]})
      port=$(eval echo \${"$h"[port]})
      password=$(eval echo \${"$h"[password]})
      # SSH检测
      expect_ssh "ssh -p${port} root@${addr} '/bin/true'" "${password}" "/dev/null"
      ssh_check=$?
      log_result "SSH: [${addr}] 连接检测" "${ssh_check}"
      [ ${ssh_check} -ne 0 ] && echo "SSH连接测试不通过，请使用单机模式部署！" && exit 1
      # 主机名设置
      expect_ssh "ssh -p${port} root@${addr} hostnamectl set-hostname ${host_name}" "${password}" "/dev/null"
      expect_ssh "scp -P${port} root@${addr}:/etc/hosts temp_install/" "${password}" "/dev/null"
      sed -ri "s/(^127.0.0.1.*)/\1 ${host_name}/g" temp_install/hosts
      cat temp_install/hosts_temp >>temp_install/hosts
      expect_ssh "scp -P${port} temp_install/hosts root@${addr}:/etc/hosts " "${password}" "/dev/null"
      # 时间设置
      time_dst=`/usr/bin/expect <<EOF|grep -o "[0-9]\{14\}"
spawn -noecho ssh -p${port} root@${addr} "TZ=0 date -d '1 second' '+%Y%m%d%H%M%S'"
expect {
  "assword:" { send "${password}\r" }
}
expect eof
EOF
  `
      # 获取本机当前时间
      time_now="$(TZ=0 date '+%Y%m%d%H%M%S')"
      # 获取本机2秒后的时间
      time_2s="$(TZ=0 date -d '2 second' '+%Y/%m/%d %H:%M:%S')"
      if [ "X${time_dst}" != "X${time_now}" ];then
        /usr/bin/expect <<EOF >/dev/null
spawn -noecho ssh -p${port} root@${addr} "timedatectl set-ntp false;TZ=0 date -s '${time_2s}'"
expect {
  "assword:" { send "${password}\r" }
}
expect eof
EOF
      fi
    fi
  done
  echo
  # 开始部署
  source etcd_install --cluster
  source master_install --cluster
  source node_install --cluster
  source nfs_install --cluster
  source apply_pod --cluster
}

if [ "X$1" != "X--cluster" -a "X$1" != "X--initialize" ];then
  source pre_install
  # 主机名设置
  local_host="$(grep ${local_ip} config|awk -F= '{print $1}')"
  host_name="$(eval echo \${"$local_host"[name]})"
  [ "X$(hostname)" != "X${host_name}" ] && hostnamectl set-hostname ${host_name}
  if [ $(grep ${host_name} /etc/hosts|wc -l) -eq 0 ];then
    sed -ri "s/(^127.0.0.1.*)/\1 ${host_name}/g" /etc/hosts
    cat temp_install/hosts_temp >>/etc/hosts
  fi
fi

case $1 in
  --initialize)
    echo_message
    source pre_install
    ;;
  --local-etcd)
    source etcd_install --local
    ;;
  --local-master)
    source master_install --local
    ;;
  --local-node)
    source node_install --local
    ;;
  --local-nfs)
    source nfs_install --local
    ;;
  --apply-pod)
    source apply_pod --local
    ;;
  --cluster)
    echo_message
    cluster_install
    ;;
  *)
    echo Error
esac
