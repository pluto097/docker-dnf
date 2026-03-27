#!/bin/bash

set -e

# 获取 MySQL IP 并导出到环境变量
export MYSQL_IP=$(getent hosts dnf_mysql | awk '{ print $1 }')
export SERVER_IP=$(getent hosts dnf_server | awk '{ print $1 }')
#echo "数据库恢复完成"

echo "授权 MySQL 数据库..."

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOF || exit 1

-- 删除已存在的game用户
DELETE FROM mysql.user WHERE User='game';
-- 限制root用户只能本机访问
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
FLUSH PRIVILEGES;
EOF

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOF || exit 1
-- game@% - 密码使用 MYSQL_ROOT_PASSWORD 环境变量
CREATE USER 'game'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'game'@'%' WITH GRANT OPTION;

-- game@SERVER_IP - 密码固定为 uu5!^%jg
CREATE USER 'game'@'${SERVER_IP}' IDENTIFIED BY 'uu5!^%jg';
GRANT ALL PRIVILEGES ON *.* TO 'game'@'${SERVER_IP}';
FLUSH PRIVILEGES;
EOF

echo "授权完成"

echo "开始写入Server IP..."

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOF || exit 1
USE d_taiwan;
UPDATE db_connect SET db_ip = '${MYSQL_IP}';
FLUSH PRIVILEGES;
EOF

echo "Server IP 写入完成"

