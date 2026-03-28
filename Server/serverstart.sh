#!/bin/bash
set -e

# ---------- 设置 root 密码 ----------
echo "root:${ROOT_PASSWORD}"  | chpasswd

# ---------- 安装服务端文件 ----------
if find /home -name db_info_tw.* 2>/dev/null | grep -q .; then
    echo "服务端文件已存在，跳过安装"
else
    echo "安装服务端文件..."

    tar -zxvf /tmp/Service_20250526.tar.gz -C / && rm /tmp/Service_20250526.tar.gz
    tar -zxvf /tmp/qf.tar.gz -C /tmp && rm /tmp/qf.tar.gz
    cp /tmp/{df_game_r,Script.pvf,frida.so,frida.js,frida.config} /home/neople/game/
    cp /tmp/channel_hook.so /home/neople/channel/
    cp /tmp/bridge_hook.so /home/neople/bridge/
    cp /tmp/run /root/
    cp /home/neople/stop /root/
    cp /tmp/publickey.pem /home/neople/game/
    mkdir -p /data
    cp /tmp/readme.md /data/
    chmod +x /root/{run,stop}

    echo "服务端文件安装完成！"
fi

# 获取 MySQL IP 并导出到环境变量
export MYSQL_IP=$(getent hosts dnf_mysql | awk '{ print $1 }')

# ---------- 配置变量 ----------
PublicIP=${PUBLIC_IP:-${IP}}
MYSQL=${MYSQL_IP:-127.0.0.1}
MYSQLNAME=${MySQLName:-game}
PASSWD=${MySQLPwd:-uu5!^%jg}
PWDKey=${MySQLKey:-20e35501e56fcedbe8b10c1f8bc3595be8b10c1f8bc3595b}
STUNIP=${PUBLIC_IP}

echo
echo "========== 配置汇总 =========="
echo "Public IP:  ${PublicIP}"
echo "MySQL IP:   ${MYSQL}"
echo "MySQL Name: ${MYSQLNAME}"
echo "MySQL Pwd:  ${PASSWD}"
echo "==============================="
echo

# ---------- 配置文件替换 ----------
DIR=$(find /home -name db_info_tw.* | rev | cut -f4- -d/ | rev)
if [ -d "${DIR}" ]; then
    cd ${DIR}
    regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    [[ ! ${STUNIP} =~ $regex ]] && { echo "错误：STUN IP 格式不正确！"; exit 1; }
    [[ ! ${PublicIP} =~ $regex ]] && { echo "错误：Public IP 格式不正确！"; exit 1; }
    [[ ! ${MYSQL} =~ $regex ]] && { echo "错误：MySQL IP 格式不正确！"; exit 1; }

    find . -type f -name "*.cfg" \
        -exec sed -i "s/Public IP/${PublicIP}/g; \
                     s/MySQL IP/${MYSQL}/g; \
                     s/MySQL Name/${MYSQLNAME}/g; \
                     s/MySQL Pwd/${PASSWD}/g; \
                     s/MySQL Key/${PWDKey}/g; \
                     s/^stun_ip= Udp IP/stun_ip = ${STUNIP}/g" {} \;
    echo "配置文件修改完成！"
else
    echo "目录 ${DIR} 不存在,可能是下载失败，请重新尝试！"
    exit 1
fi

#检查/data目录中是否存在指定文件，如果存在则复制到/home/neople/game目录中
TARGET="/home/neople/game"

echo "开始更新版本文件..."

for file in df_game_r frida.js Script.pvf publickey.pem; do
    src="/data/$file"
    dst="$TARGET/$file"

    if [ -f "$src" ]; then
        echo "[OK] 复制 $file -> $TARGET"
        cp "$src" "$dst"
    else
        echo "[SKIP] $file 不存在"
    fi
done

echo "更新完成"

# ---------- 检查 MySQL 连接并启动服务 ----------
echo "正在检查 MySQL 连接..."

MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if mysql -h "${MYSQL}" -u "${MYSQLNAME}" -p"${PASSWD}" -D d_taiwan -e "SELECT db_ip FROM db_connect LIMIT 1;" 2>/dev/null | grep -q "${MYSQL_IP}"; then
        echo "MySQL 连接成功！"
        # 启动服务
        cd /root && ./run
        echo "正在启动服务，请在 log 文件夹中查看启动状态..."
        wait
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "MySQL 连接失败，第 ${RETRY_COUNT} 次重试..."
        sleep 10
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "错误：无法连接到 MySQL 服务器，已达到最大重试次数"
    # exit 1
fi

# ---------- 启动 SSH 并保持容器运行 ----------
echo "SSH 服务启动"
exec /usr/sbin/sshd -D
