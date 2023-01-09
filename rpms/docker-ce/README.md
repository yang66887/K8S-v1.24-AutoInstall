rpm for CentOS 7.9 Minimal

    # get lastest rpms
    curl -o /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
    yum clean all
    yum makecache
    yum install --downloadonly --downloaddir=./ docker-ce docker-ce-cli containerd.io docker-compose-plugin
