FROM centos:7.9.2009

LABEL maintainer="Pluto"

# 复制服务端文件到容器
COPY init/Service_20250526.tar.gz /tmp/Service_20250526.tar.gz

# 复制必要的Script文件和df_game_r
COPY init/qf.tar.gz /tmp/
COPY init/channel_hook.so /tmp/
COPY init/bridge_hook.so /tmp/
COPY init/run /tmp/
COPY init/publickey.pem /tmp/
COPY init/data/readme.md /tmp/

RUN cd /etc/yum.repos.d/ && rm -rf * && sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf && \
    # 添加源
    curl -o CentOS-Base.repo https://raw.githubusercontent.com/1995chen/dnf_util/refs/heads/main/Centos7/CentOS-Base.repo && \
    yum clean all

RUN yum update -y zlib zlib-devel

# 安装组件
RUN yum install -y \
    openssh-server \
    openssh-clients \
    glibc.i686 \
    libgcc.i686 \
    libstdc++.i686 \
    zlib.i686 \
    psmisc \
    net-tools \
    mariadb \
    && yum clean all

# 生成 SSH key
RUN ssh-keygen -A

# SSH 配置
RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 复制启动脚本
COPY serverstart.sh /serverstart.sh
RUN chmod 755 /serverstart.sh

# 设置工作目录为root
WORKDIR /root

ENTRYPOINT ["/serverstart.sh"]
