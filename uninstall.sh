#!/bin/bash

source config
source actions
Uninstall_Log='/dev/null'
local_host=$(grep ^HOST config|grep "$(ip addr|grep 'inet '|grep -v 127.0.0.1|awk '{print $2}'|awk -F/ '{print $1}'|head -1)"|awk -F= '{print $1}')
mode="$1"

# 远程部署通道
expect_ssh(){
  Command="$1"
  Password="$2"
  LogFile="$3"
  /usr/bin/expect <<EOF >>${LogFile}
spawn -noecho bash -c "${Command}"
expect {
  "int])?" { send "yes\r";exp_continue }
  "yes/no)?" { send "yes\r";exp_continue }
  "assword:" { send "${Password}\r" }
}
expect eof
catch wait result
exit [lindex \$result 3]
EOF
}

pre_uninstall(){
  if [ ! -d temp_uninstall ];then
    mkdir temp_uninstall
  fi
  
  # etcd
  if [ ! -f temp_uninstall/etcd.uninstall ];then
    cat >temp_uninstall/etcd.uninstall <<EOF
systemctl disable --now etcd 
rm -f /usr/lib/systemd/system/etcd.service 
rm -rf /data/etcd
if [ ! -f /usr/lib/systemd/system/etcd.service -a ! -d /data/etcd ];then
  /bin/true
else
  bin/false
fi
EOF
  fi

  # Keepalived
  if [ ! -f temp_uninstall/keepalived.rh.uninstall ];then
    cat >temp_uninstall/keepalived.rh.uninstall <<EOF
systemctl disable --now keepalived 
rm -rf /usr/lib/systemd/system/keepalived.service 
rm -rf /usr/local/keepalived 
rm -rf /etc/keepalived
if [ ! -f /usr/lib/systemd/system/keepalived.service -a ! -d /usr/local/keepalived -a ! -d /etc/keepalived ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi
  if [ ! -f temp_uninstall/keepalived.de.uninstall ];then
    cat >temp_uninstall/keepalived.de.uninstall <<EOF
systemctl disable --now keepalived 
dpkg --purge keepalived 
rm -rf /etc/keepalived
if [ \$(dpkg -l|grep keepalived &>/dev/null;echo \$?) -ne 0 -a ! -d /etc/keepalived ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Nginx
  if [ ! -f temp_uninstall/nginx.uninstall ];then
    cat >temp_uninstall/nginx.uninstall <<EOF
systemctl disable --now nginx 
rm -rf /usr/lib/systemd/system/nginx.service 
rm -rf /usr/local/nginx
if [ ! -f /usr/lib/systemd/system/nginx.service -a ! -d /usr/local/nginx ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Kubectl
  if [ ! -f temp_uninstall/kubectl.uninstall ];then
    cat >temp_uninstall/kubectl.uninstall <<EOF
rm -f /usr/local/bin/kubectl 
rm -f /data/kubernetes/bin/kubectl 
rm -f /data/kubernetes/ssl/kubectl* 
rm -rf /root/.kube
if [ ! -f /usr/local/bin/kubectl -a ! -f /data/kubernetes/bin/kubectl -a ! -d /root/.kube ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  #Kubelet
  if [ ! -f temp_uninstall/kubelet.uninstall ];then
    cat >temp_uninstall/kubelet.uninstall <<EOF
systemctl disable --now kubelet 
rm -f /usr/lib/systemd/system/kubelet.service
rm -f /data/kubernetes/bin/kubelet
rm -f /data/kubernetes/cfg/kubelet*
rm -f /data/kubernetes/ssl/kubelet*
if [ ! -f /data/kubernetes/bin/kube-apiserver ];then
  rm -f /data/kubernetes/ssl/ca*
fi
if [ ! -f /usr/systemd/system/kubelet.service -a ! -f /data/kubernetes/bin/kubelet ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Kube-proxy
  if [ ! -f temp_uninstall/kube-proxy.uninstall ];then
    cat >temp_uninstall/kube-proxy.uninstall <<EOF
systemctl disable --now kube-proxy
rm -f /usr/lib/systemd/system/kube-proxy.service
rm -f /data/kubernetes/bin/kube-proxy
rm -f /data/kubernetes/cfg/kube-proxy*
rm -f /data/kubernetes/ssl/kube-proxy*
if [ ! -f /usr/systemd/system/kube-proxy.service -a ! -f /data/kubernetes/bin/kube-proxy ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Docker
  if [ ! -f temp_uninstall/docker.rh.uninstall ];then
    cat >temp_uninstall/docker.rh.uninstall <<EOF
docker rmi -f \$(docker images|awk '{print \$3}'|grep -v IMAGE)
systemctl disable --now docker.service
systemctl disable --now docker.socket
rm -rf /etc/docker
sed -ri '/net.bridge.bridge-nf-call-ip.*tables = 1/d' /etc/sysctl.conf
sysctl -p
rpm -e \$(rpm -qa|grep docker)
rm -rf /data/docker
if [ ! -f /usr/systemd/system/docker.service -a ! -d /data/docker -a \$(rpm -qa|grep docker &>/dev/null;echo \$?) -ne 0 ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi
  if [ ! -f temp_uninstall/docker.de.uninstall ];then
    cat >temp_uninstall/docker.de.uninstall <<EOF
docker rmi -f \$(docker images|awk '{print \$3}'|grep -v IMAGE)
systemctl disable --now docker.service
systemctl disable --now docker.socket
rm -rf /etc/docker
sed -ri '/net.bridge.bridge-nf-call-ip.*tables = 1/d' /etc/sysctl.conf
sysctl -p
dpkg --purge \$(dpkg -l|grep docker|awk '{print \$2}') 
rm -rf /data/docker
if [ ! -f /usr/systemd/system/docker.service -a ! -d /data/docker -a \$(dpkg -l|grep docker &>/dev/null;echo \$?) -ne 0 ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Cri-dockerd
  if [ ! -f temp_uninstall/cri-dockerd.uninstall ];then
    cat >temp_uninstall/cri-dockerd.uninstall <<EOF
systemctl disable --now cri-dockerd
rm -f /usr/lib/systemd/system/cri-dockerd.service
rm -f /usr/local/bin/cri-dockerd
rm -f /data/kubernetes/cfg/cri-dockerd.conf
if [ ! -f /usr/systemd/system/cri-dockerd.service -a ! -f /usr/local/bin/cri-dockerd ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # CNI
  if [ ! -f temp_uninstall/cni.uninstall ];then
    cat >temp_uninstall/cni.uninstall <<EOF
rm -rf /opt/cni
rm -rf /etc/cni
if [ ! -d /opt/cni -a ! -d /etc/cni ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Kube-scheduler
  if [ ! -f temp_uninstall/kube-scheduler.uninstall ];then
    cat >temp_uninstall/kube-scheduler.uninstall <<EOF
systemctl disable --now kube-scheduler
rm -f /usr/lib/systemd/system/kube-scheduler.service
rm -f /data/kubernetes/bin/kube-scheduler
rm -f /data/kubernetes/cfg/kube-scheduler*
rm -f /data/kubernetes/ssl/kube-scheduler*
if [ ! -f /usr/systemd/system/kube-scheduler.service -a ! -f /data/kubernetes/bin/kube-scheduler ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Kube-controller-manager
  if [ ! -f temp_uninstall/kube-controller-manager.uninstall ];then
    cat >temp_uninstall/kube-controller-manager.uninstall <<EOF
systemctl disable --now kube-controller-manager
rm -f /usr/lib/systemd/system/kube-controller-manager.service
rm -f /data/kubernetes/bin/kube-controller-manager
rm -f /data/kubernetes/cfg/kube-controller-manager*
rm -f /data/kubernetes/ssl/kube-controller-manager*
if [ ! -f /usr/systemd/system/kube-controller-manager.service -a ! -f /data/kubernetes/bin/kube-controller-manager ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # Kube-apiserver
  if [ ! -f temp_uninstall/kube-apiserver.uninstall ];then
    cat >temp_uninstall/kube-apiserver.uninstall <<EOF
systemctl disable --now kube-apiserver
rm -f /usr/lib/systemd/system/kube-apiserver.service
rm -f /data/kubernetes/bin/kube-apiserver
rm -f /data/kubernetes/cfg/{kube-apiserver.conf,token.csv}
rm -f /data/kubernetes/ssl/ca*
rm -f /data/kubernetes/ssl/etcd*
rm -f /data/kubernetes/ssl/kube-apiserver*
rm -f /data/kubernetes/ssl/kube-proxy*
if [ ! -f /usr/systemd/system/kube-apiserver.service -a ! -f /data/kubernetes/bin/kube-apiserver ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi

  # NFS
  if [ ! -f temp_uninstall/nfs.rh.uninstall ];then
    cat >temp_uninstall/nfs.rh.uninstall <<EOF
umount /data/nfs
rm -rf /data/nfs
sed -ri '/\/data\/nfs/d' /etc/fstab
systemctl disable --now nfs
systemctl disable --now rpcbind
systemctl disable --now rpcbind.socket
rpm -e \$(rpm -qa|egrep 'rpcbind|nfs-utils|quota')
if [ ! -d /data/nfs -a \$(rpm -q nfs-utils &>/dev/null;echo \$?) -ne 0 -a \$(rpm -q rpcbind &>/dev/null;echo \$?) -ne 0 ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi
  if [ ! -f temp_uninstall/nfs.de.uninstall ];then
    cat >temp_uninstall/nfs.de.uninstall <<EOF
umount /data/nfs
rm -rf /data/nfs
sed -ri '/\/data\/nfs/d' /etc/fstab
systemctl disable --now nfs-server
systemctl disable --now rpcbind
systemctl disable --now rpcbind.socket
dpkg --purge \$(dpkg -l|egrep 'nfs-[kc]|rpcbind'|awk '{print \$2}')
if [ ! -d /data/nfs -a \$(dpkg -l|grep nfs-common &>/dev/null;echo \$?) -ne 0 -a \$(dpkg -l|grep rpcbind &>/dev/null;echo \$?) -ne 0 ];then
  /bin/true
else
  /bin/false
fi
EOF
  fi
}

node_uninstall(){
  dst_host=$1
  dst_release=$(eval echo \${"$dst_host"[release]})

  # 本机卸载
  if [ "X${dst_host}" == "X${local_host}" ];then
    bash <temp_uninstall/kube-proxy.uninstall &>${Uninstall_Log}
    kubeproxy_uninstall_check=$?
    log_result "卸载kube-proxy" ${kubeproxy_uninstall_check}
    bash <temp_uninstall/kubelet.uninstall &>${Uninstall_Log}
    kubelet_uninstall_check=$?
    log_result "卸载kubelet" ${kubelet_uninstall_check}
    bash <temp_uninstall/kubectl.uninstall &>${Uninstall_Log}
    kubectl_uninstall_check=$?
    log_result "卸载kubectl" ${kubectl_uninstall_check}
    bash <temp_uninstall/cri-dockerd.uninstall &>${Uninstall_Log}
    cridockerd_uninstall_check=$?
    log_result "卸载cri-dockerd" ${cridockerd_uninstall_check}
    if [ ! -f /data/kubernetes/bin/kube-apiserver ];then
      rm -rf /data/kubernetes &>${Uninstall_Log}
    fi
    bash <temp_uninstall/cni.uninstall &>${Uninstall_Log}
    cni_uninstall_check=$?
    log_result "卸载cni-plugins" ${cni_uninstall_check}
    case ${dst_release} in
      CentOS7_9)
        bash <temp_uninstall/docker.rh.uninstall &>${Uninstall_Log}
        docker_uninstall_check=$?
        log_result "卸载docker" ${docker_uninstall_check}
        ;;
      Ubuntu22_04)
        bash <temp_uninstall/docker.de.uninstall &>${Uninstall_Log}
        docker_uninstall_check=$?
        log_result "卸载docker" ${docker_uninstall_check}
    esac
  # 远程卸载
  else
    dst_addr=$(eval echo \${"$dst_host"[addr]})
    dst_port=$(eval echo \${"$dst_host"[port]})
    dst_password=$(eval echo \${"$dst_host"[password]})
    expect_ssh "scp -pq -P${dst_port} temp_uninstall/{kube-proxy.uninstall,kubelet.uninstall,kubectl.uninstall,cri-dockerd.uninstall,cni.uninstall} root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kube-proxy.uninstall;rm -f kube-proxy.uninstall'" "${dst_password}" "${Uninstall_Log}"
    kubeproxy_uninstall_check=$?
    log_result "卸载kube-proxy" ${kubeproxy_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kubelet.uninstall;rm -f kubelet.uninstall'" "${dst_password}" "${Uninstall_Log}"
    kubelet_uninstall_check=$?
    log_result "卸载kubelet" ${kubelet_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kubectl.uninstall;rm -f kubectl.uninstall'" "${dst_password}" "${Uninstall_Log}"
    kubectl_uninstall_check=$?
    log_result "卸载kubectl" ${kubectl_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <cri-dockerd.uninstall;rm -f cri-dockerd.uninstall'" "${dst_password}" "${Uninstall_Log}"
    cridockerd_uninstall_check=$?
    log_result "卸载cri-dockerd" ${cridockerd_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'test ! -f /data/kubernetes/bin/kube-apiserver && rm -rf /data/kubernetes'" "${dst_password}" "${Uninstall_Log}"
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <cni.uninstall;rm -f cni.uninstall'" "${dst_password}" "${Uninstall_Log}"
    cni_uninstall_check=$?
    log_result "卸载cni-plugins" ${cni_uninstall_check}
    case ${dst_release} in
      CentOS7_9)
        expect_ssh "scp -pq -P${dst_port} temp_uninstall/docker.rh.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
        expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <docker.rh.uninstall;rm -f docker.rh.uninstall'" "${dst_password}" "${Uninstall_Log}"
        docker_uninstall_check=$?
        log_result "卸载docker" ${docker_uninstall_check}
        ;;
      Ubuntu22_04)
        expect_ssh "scp -pq -P${dst_port} temp_uninstall/docker.de.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
        expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <docker.de.uninstall;rm -f docker.de.uninstall'" "${dst_password}" "${Uninstall_Log}"
        docker_uninstall_check=$?
        log_result "卸载docker" ${docker_uninstall_check}
    esac
  fi
}

master_uninstall(){
  dst_host=$1
  dst_release=$(eval echo \${"$dst_host"[release]})
  
  # 本机卸载
  if [ "X${dst_host}" == "X${local_host}" ];then
    bash <temp_uninstall/kube-scheduler.uninstall &>${Uninstall_Log}
    kubescheduler_uninstall_check=$?
    log_result "卸载kube-scheduler" ${kubescheduler_uninstall_check}
    bash <temp_uninstall/kube-controller-manager.uninstall &>${Uninstall_Log}
    kubecontrollermanager_uninstall_check=$?
    log_result "卸载kube-controller-manager" ${kubecontrollermanager_uninstall_check}
    bash <temp_uninstall/kube-apiserver.uninstall &>${Uninstall_Log}
    kubeapiserver_uninstall_check=$?
    log_result "卸载kube-apiserver" ${kubeapiserver_uninstall_check}
    if [ $(which kubectl &>/dev/null;echo $?) -eq 0 ];then
      bash <temp_uninstall/kubectl.uninstall &>${Uninstall_Log}
      kubectl_uninstall_check=$?
      log_result "卸载kubectl" ${kubectl_uninstall_check}
    fi
    if [ ! -f /data/kubernetes/bin/kube-apiserver ];then
      rm -rf /data/kubernetes &>${Uninstall_Log}
    fi
    case ${dst_release} in
      CentOS7_9)
        bash <temp_uninstall/keepalived.rh.uninstall &>${Uninstall_Log}
        keepalived_uninstall_check=$?
        log_result "卸载keepalived" ${keepalived_uninstall_check}
        ;;
      Ubuntu22_04)
        bash <temp_uninstall/keepalived.de.uninstall &>${Uninstall_Log}
        keepalived_uninstall_check=$?
        log_result "卸载keepalived" ${keepalived_uninstall_check}
    esac
    bash <temp_uninstall/nginx.uninstall &>${Uninstall_Log}
    nginx_uninstall_check=$?
    log_result "卸载nginx" ${nginx_uninstall_check}
  # 远程卸载
  else
    dst_addr=$(eval echo \${"$dst_host"[addr]})
    dst_port=$(eval echo \${"$dst_host"[port]})
    dst_password=$(eval echo \${"$dst_host"[password]})
    expect_ssh "scp -pq -P${dst_port} temp_uninstall/{kube-scheduler.uninstall,kube-controller-manager.uninstall,kube-apiserver.uninstall,kubectl.uninstall,nginx.uninstall} root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kube-scheduler.uninstall;rm -f kube-scheduler.uninstall'" "${dst_password}" "${Uninstall_Log}"
    kubescheduler_uninstall_check=$?
    log_result "卸载kube-scheduler" ${kubescheduler_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kube-controller-manager.uninstall;rm -f kube-controller-manager.uninstall'" "${dst_password}" "${Uninstall_Log}"
    kubecontrollermanager_uninstall_check=$?
    log_result "卸载kube-controller-manager" ${kubecontrollermanager_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kube-apiserver.uninstall;rm -f kube-apiserver.uninstall'" "${dst_password}" "${Uninstall_Log}"
    kubeapiserver_uninstall_check=$?
    log_result "卸载kube-apiserver" ${kubeapiserver_uninstall_check}
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'which kubectl'" "${dst_password}" "${Uninstall_Log}"
    kubectl_check=$?
    if [ ${kubectl_check} -eq 0 ];then
      expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <kubectl.uninstall;rm -f kubectl.uninstall'" "${dst_password}" "${Uninstall_Log}"
      kubectl_uninstall_check=$?
      log_result "卸载kubectl" ${kubectl_uninstall_check}
    fi
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'test ! -f /data/kubernetes/bin/kube-apiserver && rm -rf /data/kubernetes'" "${dst_password}" "${Uninstall_Log}"
    case ${dst_release} in
      CentOS7_9)
        expect_ssh "scp -pq -P${dst_port} temp_uninstall/keepalived.rh.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
        expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <keepalived.rh.uninstall;rm -f keepalived.rh.uninstall'" "${dst_password}" "${Uninstall_Log}"
        keepalived_uninstall_check=$?
        log_result "卸载keepalived" ${keepalived_uninstall_check}
        ;;
      Ubuntu22_04)
        expect_ssh "scp -pq -P${dst_port} temp_uninstall/keepalived.de.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
        expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <keepalived.de.uninstall;rm -f keepalived.de.uninstall'" "${dst_password}" "${Uninstall_Log}"
        keepalived_uninstall_check=$?
        log_result "卸载keepalived" ${keepalived_uninstall_check}
    esac
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <nginx.uninstall;rm -f nginx.uninstall'" "${dst_password}" "${Uninstall_Log}"
    nginx_uninstall_check=$?
    log_result "卸载nginx" ${nginx_uninstall_check}
  fi
}

etcd_uninstall(){
  dst_host=$1
  
  # 本机卸载
  if [ "X${dst_host}" == "X${local_host}" ];then
    bash <temp_uninstall/etcd.uninstall &>${Uninstall_Log}
    etcd_uninstall_check=$?
    log_result "卸载etcd" ${etcd_uninstall_check}
  # 远程卸载
  else
    dst_addr=$(eval echo \${"$dst_host"[addr]})
    dst_port=$(eval echo \${"$dst_host"[port]})
    dst_password=$(eval echo \${"$dst_host"[password]})
    expect_ssh "scp -pq -P${dst_port} temp_uninstall/etcd.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
    expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <etcd.uninstall;rm -f etcd.uninstall'" "${dst_password}" "${Uninstall_Log}"
    etcd_uninstall_check=$?
    log_result "卸载etcd" ${etcd_uninstall_check}
  fi
}

nfs_uninstall(){
  dst_host=$1
  dst_release=$(eval echo \${"$dst_host"[release]})
  
  # 本机卸载
  if [ "X${dst_host}" == "X${local_host}" ];then
    case ${dst_release} in
      CentOS7_9)
        bash <temp_uninstall/nfs.rh.uninstall &>${Uninstall_Log}
        nfs_uninstall_check=$?
        log_result "卸载nfs" ${nfs_uninstall_check}
        ;;
      Ubuntu22_04)
        bash <temp_uninstall/nfs.de.uninstall &>${Uninstall_Log}
        nfs_uninstall_check=$?
        log_result "卸载nfs" ${nfs_uninstall_check}
    esac
  # 远程卸载
  else
    dst_addr=$(eval echo \${"$dst_host"[addr]})
    dst_port=$(eval echo \${"$dst_host"[port]})
    dst_password=$(eval echo \${"$dst_host"[password]})
    case ${dst_release} in
      CentOS7_9)
        expect_ssh "scp -pq -P${dst_port} temp_uninstall/nfs.rh.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
        expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <nfs.rh.uninstall;rm -f nfs.rh.uninstall'" "${dst_password}" "${Uninstall_Log}"
        nfs_uninstall_check=$?
        log_result "卸载nfs" ${nfs_uninstall_check}
        ;;
      Ubuntu22_04)
        expect_ssh "scp -pq -P${dst_port} temp_uninstall/nfs.de.uninstall root@${dst_addr}:/root" "${dst_password}" "${Uninstall_Log}"
        expect_ssh "ssh -p${dst_port} root@${dst_addr} 'cd /root;bash <nfs.de.uninstall;rm -f nfs.de.uninstall'" "${dst_password}" "${Uninstall_Log}"
        nfs_uninstall_check=$?
        log_result "卸载nfs" ${nfs_uninstall_check}
    esac
  fi
}

components_select(){
  dst_host=$1
  dst_addr=$(eval echo \${"$dst_host"[addr]})
  echo "################## Uninstall ${dst_addr} Begin ##################"
  components=$(eval echo \${"$dst_host"[node]}|tr ' ' '\n'|sort -r)
  if [ $(echo ${components}|grep nfs|wc -l) -eq 0 ];then
    nfs_uninstall ${dst_host}
  fi
  for component in ${components}
  do
    case ${component} in
      node)
        node_uninstall ${dst_host}
        ;;
      master)
        master_uninstall ${dst_host}
        ;;
      etcd)
        etcd_uninstall ${dst_host}
        ;;
      nfs)
        nfs_uninstall ${dst_host}
    esac
  done
  echo "################## Uninstall ${dst_addr} End ####################"
  echo
}

pre_uninstall

case ${mode} in
  --local)
    if [ "X${local_host}" != 'X' ];then
      components_select ${local_host}
      echo "卸载完成，请手动重启服务器！"
    else
      echo '本机未安装k8s组件'
    fi
    ;;
  --cluster)
    for host in $(grep '^HOST.*=(' config|awk -F= '{print $1}')
    do
      [ $(grep ^${host} config|grep nfs|wc -l) -ne 0 ] && continue
      components_select ${host}
    done
    components_select $(grep '^HOST.*=(' config|grep nfs|awk -F= '{print $1}')
    echo "卸载完成，请手动重启服务器！"
    ;;
  *)
    echo Error
esac
