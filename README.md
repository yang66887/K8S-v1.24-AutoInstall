# K8S-v1.24-AutoInstall
**K8S v1.24二进制版离线自动安装脚本**

- 已验证支持的操作系统（可混用）：
  - CentOS Linux release 7.9.2009 (Core)
  - Ubuntu Server 22.04.1 LTS

- 理论上支持但不建议使用的操作系统：
  - CentOS Linux release 7.6.1810 (Core)
  - CentOS Linux release 7.7.1908 (Core)
  - CentOS Linux release 7.8.2003 (Core)

- 组件版本：
  - Kubernetes Version: v1.24.8
  - Etcd Version: v3.5.6
  - Docker-CE Version: v20.10.21
  - CRI-Dockerd Version: v0.2.6
  - CNI-Plugins Version: v1.1.1
  - Nginx Version: v1.22.1
  - Keepalived Version(CentOS): v2.2.7
  - Keepalived Version(Ubuntu): v2.2.4

- 镜像版本：
  - pause Version: v3.6
  - flannel Version: v0.17.0
  - flannel-cni-plugin Version: v1.0.1
  - coredns Version: v1.9.4
  - metrics-server Version: v0.6.2
  - kuboard Version: v2.0.5.5
  - dashboard Version: v2.5.1
  - metrics-scraper Version: v1.0.7
  - stakater/reloader Version: v0.0.113
  - nfs-subdir-external-provisioner Version: v4.0.2

## 配置文件：部署前先配置 config 文件，参数说明如下
- 设备参数：每个 HOSTx 代表1台设备，其后括号内为该设备相关信息，多台设备则定义多个 HOSTx
```shell
[name]="xxx"      # 主机名，要求集群内唯一
[addr]="xxx"      # IP地址
[node]="xxx"      # 节点类型，etcd | master | node | nfs，多种类型以空格分离，nfs建议独立部署，且仅能有1台
[port]="xxx"      # SSH端口
[user]="root"     # SSH账号，必须为root
[password]="xxx"  # SSH密码
[if_name]="xxx"   # 网卡名
[release]="xxx"   # 操作系统版本，CentOS7_9 | Ubuntu22_04
```
    
- Keepalived参数：
```shell
v_ip='xxx'              # 多master节点所使用的虚拟IP
virtual_router_id=xxx   # Keepalived集群id，0-255之间的数字
```
    
- K8S集群参数：以下为默认参数，非必要请勿修改
```shell
cluster_ip_range='10.0.0.0/16'
cluster_ip='10.0.0.1'
cluster_dns='10.0.0.2'
cluster_cidr_range='10.244.0.0/16'
cluster_cidr='10.244.0.1'
node_port_range='30000-35000'
docker0_bip='172.244.0.1/16'
kuboard_port=30000
dashboard_port=30001
```

- 完整 config 配置示例如下：
```shell
# 设备参数
declare -A HOST1 HOST2 HOST3 HOST4
HOST1=([name]="master-1" [addr]="192.168.1.1" [node]="etcd master" [port]="22" [user]="root" [password]="Password1" [if_name]="eth0" [release]="CentOS7_9")
HOST2=([name]="master-2" [addr]="192.168.1.2" [node]="etcd master" [port]="22" [user]="root" [password]="Password2" [if_name]="eth0" [release]="Ubuntu22_04")
HOST3=([name]="node-1" [addr]="192.168.1.3" [node]="etcd node" [port]="22" [user]="root" [password]="Password3" [if_name]="eth0" [release]="CentOS7_9")
HOST4=([name]="nfs-server" [addr]="192.168.1.4" [node]="nfs" [port]="22" [user]="root" [password]="Password4" [if_name]="ens160" [release]="CentOS7_9")
# Keepalived集群参数
v_ip='192.168.1.5'
virtual_router_id=221
# K8S集群参数
cluster_ip_range='10.0.0.0/16'
cluster_ip='10.0.0.1'
cluster_dns='10.0.0.2'
cluster_cidr_range='10.244.0.0/16'
cluster_cidr='10.244.0.1'
node_port_range='30000-35000'
docker0_bip='172.244.0.1/16'
dashboard_port=30000
kuboard_port=30001
```

## 安装参数：
```shell
install.sh --initialize|--local-etcd|--local-master|--local-node|--local-nfs|--apply-pod|--cluster
Usage:
--initialize        # 初始化配置文件
--local-etcd        # 本机安装etcd组件
--local-master      # 本机安装master组件
--local-node        # 本机安装node组件
--local-nfs         # 本机安装nfs组件
--apply-pod         # 创建集群所需基础pod
--cluster           # 自动部署k8s集群
```
    
## 部署说明：分为集群与单机两种模式
***部署前需先关闭所有服务器的防火墙***
- 集群模式：上传部署包至任一服务器
```shell
chmod 755 install.sh        # 部署脚本添加执行权限
./install.sh --cluster      # 开始自动部署，要求所有服务器之间可以直接 ssh 连接
```
    
- 单机模式：上传部署包至所有服务器
```shell
chmod 755 install.sh        # 部署脚本添加执行权限
./install.sh --initialize   # 初始化配置文件，任意一台服务器执行，执行完成后会生成一个【temp_install】文件夹

# 将【config】和【temp_install】拷贝至所有服务器的【install.sh】所在目录下。
# 按节点依次部署【nfs】【etcd】【master】【node】

# 开始部署，命令执行顺序如下：
./install.sh --local-nfs    # config文件中【[node]包含nfs】的服务器上执行，安装NFS服务端
./install.sh --local-nfs    # config文件中【[node]不包含nfs】的服务器上执行，安装NFS客户端
./install.sh --local-etcd   # 所有需部署【etcd】组件的服务器上同时执行, etcd节点最少3台，总数需为单数
./install.sh --local-master # 所有需部署【master】组件的服务器上同时执行
./install.sh --local-node   # 在需部署【node】组件的服务器上执行，建议单台依次部署
./install.sh --apply-pod    # 在【master】节点上执行, 多master节点时在【master-1】节点执行
```
  - PS：单机模式部署时必须严格遵照上述顺序，否则可能导致部署失败

## 卸载参数：
```shell
uninstall.sh --local|--cluster
Usage:    
--local     # 卸载本机k8s组件，nfs server 节点需放在最后卸载    
--cluster   # 自动卸载k8s集群
```
