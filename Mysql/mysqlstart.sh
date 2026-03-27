#!/bin/bash

set -e

echo "启动 MySQL..."
./entrypoint.sh mysqld &

until mysqladmin ping -h "127.0.0.1" --silent; do
  sleep 2
done

# 恢复tmp文件夹中的dnfsql_5.6.51_20250526.sql，仅在第一次启动时执行
if [ -f "/tmp/dnfsql_5.6.51_20250526.sql" ]; then
    echo "正在恢复数据库备份..."
    mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < /tmp/dnfsql_5.6.51_20250526.sql || exit 1
    echo "数据库恢复完成"
    # 删除已恢复的SQL文件
    rm -f "/tmp/dnfsql_5.6.51_20250526.sql"
fi

# 获取 MySQL IP 并导出到环境变量
export MYSQL_IP=$(getent hosts dnf_mysql | awk '{ print $1 }')
export SERVER_IP=$(getent hosts dnf_server | awk '{ print $1 }')

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

-- game@_IP127.0.0.1 - 密码固定为 uu5!^%jg
CREATE USER 'game'@'127.0.0.1' IDENTIFIED BY 'uu5!^%jg';
GRANT ALL PRIVILEGES ON *.* TO 'game'@'127.0.0.1';
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


# 配置 AES Key 和 GAME_SERVER_IP
if [ -n "${GATE_AES_KEY}" ]; then
    ENV_FILE="/root/.env"
    if [ -f "${ENV_FILE}" ]; then
        sed -i "s/^AES_KEY=.*/AES_KEY=${GATE_AES_KEY}/" "${ENV_FILE}"
        echo "已配置 AES Key"
    else
        echo "警告：${ENV_FILE} 不存在，跳过 AES Key 配置"
    fi
else
    echo "未设置 GATE_AES_KEY 环境变量，使用默认 AES Key"
fi

# 配置 GAME_SERVER_IP
if [ -n "${SERVER_IP}" ]; then
    ENV_FILE="/root/.env"
    if [ -f "${ENV_FILE}" ]; then
        sed -i "s/^GAME_SERVER_IP=.*/GAME_SERVER_IP=${SERVER_IP}/" "${ENV_FILE}"
        echo "已配置 GAME_SERVER_IP: ${SERVER_IP}"
    else
        echo "警告：${ENV_FILE} 不存在，跳过 GAME_SERVER_IP 配置"
    fi
else
    echo "未设置 SERVER_IP 环境变量，跳过 GAME_SERVER_IP 配置"
fi

# 复制私钥到容器内
cp /tmp/privatekey.pem /data/

# 检查privatekey_data内是否有privatekey.pem，如果有就复制到/data
if [ -f "/tmp/privatekey_data/privatekey.pem" ]; then
    cp /tmp/privatekey_data/privatekey.pem /data/
    echo "已从 privatekey_data 复制私钥到 /data"
else
    # 复制私钥到容器内
    cp /tmp/privatekey.pem /data/
fi

# 启动网关
cd /root/
./dnf-gate-server
