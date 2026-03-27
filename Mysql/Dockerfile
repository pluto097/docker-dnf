FROM mysql:5.6

LABEL maintainer="Pluto"

# 复制配置
COPY initdb/my.cnf /etc/mysql/conf.d/my.cnf

# 复制脚本和sql文件
# COPY initdb.sh /docker-entrypoint-initdb.d/
COPY initdb/dnfsql_5.6.51_20250526.sql /tmp/

# 复制llnut网关
COPY llnutgate/ /root/
COPY data/privatekey.pem /data/
# 只需要执行权限
# RUN chmod +x /docker-entrypoint-initdb.d/*.sh

# 复制启动脚本
COPY mysqlstart.sh /mysqlstart.sh
RUN chmod +x /mysqlstart.sh

ENTRYPOINT ["/mysqlstart.sh"]