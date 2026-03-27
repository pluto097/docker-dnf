# Docker DNF 服务端部署

基于 Docker Compose 的《地下城与勇士》(DNF) 服务端一键部署解决方案，集成 MySQL 数据库、登录网关和游戏服务端。

本项目集成了以下开源项目：
- **[llnut/DofSlim](https://github.com/llnut/DofSlim)** - 动态缩减服务端内存占用
- **[llnut/dnf-login](https://github.com/llnut/dnf-login)** - 开源登录网关（支持账号注册、登录等功能）

## 📋 项目介绍

本项目使用 Docker 容器化技术一键部署 DNF 服务端，包含以下组件：

- **MySQL 5.6** - 数据库服务，预置完整数据库
- **[llnut/dnf-login](https://github.com/llnut/dnf-login)** - 第三方登录网关（支持账号注册、登录等功能）
- **[llnut/DofSlim](https://github.com/llnut/DofSlim)** - 内存优化，通过 LD_PRELOAD 钩子动态缩减客户端池内存占用，可节省 2.5GB+ 内存
- **DNF 游戏服务端** - 基于 CentOS 7 的完整服务端环境

### 主要特性

- ✅ 一键部署，自动配置
- ✅ 容器隔离，环境干净
- ✅ 数据持久化，重启不丢失
- ✅ 支持多线 PVP
- ✅ 集成 Frida 钩子
- ✅ 支持版本更新
- ✅ 集成 DofSlim 内存优化，大幅降低内存占用
- ✅ 可配置客户端池大小，根据服务器规模灵活调整

## 🔧 环境要求

部署前请确保你的系统已安装：

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

> **[llnut/DofSlim](https://github.com/llnut/DofSlim) 内存优化说明：** 原版服务端 `df_bridge_r` 和 `df_channel_r` 静态分配 1000 个客户端对象，会浪费约 2.5GB 内存。本项目通过 DofSlim 技术动态缩减内存，可通过 `CLIENT_POOL_SIZE` 环境变量配置实际需要的客户端池大小，大幅降低内存占用。

## 🚀 部署方式

### 方式一：快速部署（推荐）

直接使用本项目的 Docker Compose 部署。

#### 1. 修改配置

编辑 `docker-compose.yml` 文件，根据需要修改环境变量：

```yaml
services:
  dnf_mysql:
    image: pluto06199/dnf-mysql:1.0
    container_name: dnf_mysql
    restart: unless-stopped
    ports:
      - 3306:3306/tcp 
      - 5505:5505/tcp           
    environment:
      TZ: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: root123    # MySQL root 密码，game 用户密码也使用此值
      SERVER_IP: dnf_server
      MYSQL_IP: dnf_mysql
      GATE_AES_KEY: a1b2c3d4e5f6789012345678901234567890abcdef0123456789abcdef012345 #自行修改
    volumes:
      - ./mysql_data:/var/lib/mysql
    networks:
      - dnf_net

  dnf_server:
    image: pluto06199/dnf-server:1.0
    container_name: dnf_server
    shm_size: 10g
    restart: unless-stopped
    ports:
      - "22:22"           # 服务器SSH端口
      - 7001:7001/tcp      # df_channel_r
      - 7001:7001/udp      # df_channel_r
      - 7200:7200/tcp      # df_relay_r
      - 7200:7200/udp      # df_relay_r
      - 10011:10011/tcp    # df_game_r[ch.11]
      - 11011:11011/udp    # df_game_r[ch.11]
      #- 10052:10052/tcp    # df_game_r[ch.52] PVP
      #- 11052:11052/udp    # df_game_r[ch.52] PVP
      - 2311:2311/udp      # df_stun_r
      - 2312:2312/udp      # df_stun_r
      - 2313:2313/udp      # df_stun_r
    volumes:
      - ./server_data/root:/root
      - ./server_data/data:/data
      - ./server_data/log:/home/neople/game/log
    environment:
      TZ: Asia/Shanghai
      ROOT_PASSWORD: root123     # 服务器SSH root密码（自行修改）
      PUBLIC_IP: 192.168.200.131       # 本机IP（自行修改）
      CLIENT_POOL_SIZE: 64    # 客户端池大小（DofSlim优化）
      MYSQL_IP: dnf_mysql
    networks:
      - dnf_net

networks:
  dnf_net:
    driver: bridge
```

**重要提示：** `PUBLIC_IP` 必须修改为你的服务器实际 IP 地址，否则客户端无法连接！

#### 2. 启动服务

镜像已经预构建好上传到 Docker Hub，直接拉取启动即可：

```bash
docker compose up -d
```

- `-d` 参数表示后台运行
- 首次启动会自动拉取镜像并初始化数据库，需要一些时间

#### 3. 检查docker启动状态

```bash
docker compose ps
```
两个容器都应该显示 `Up` 状态。


#### 4. 验证服务启动状态

检查 `./server_data/log` 目录下的 `Logxxxxxxxx.init` 文件中是否出现以下内容（五国）：
```
[11:26:18] GeoIP Allow Country Code : CN
[11:26:18] GeoIP Allow Country Code : HK
[11:26:18] GeoIP Allow Country Code : KR
[11:26:18] GeoIP Allow Country Code : MO
[11:26:18] GeoIP Allow Country Code : TW
```

### 方式二：高级部署（自定义构建）

如果你想自定义修改，可以 Fork 项目后自行构建镜像。

#### 1. Fork 并克隆

```bash
git clone https://github.com/<your-username>/docker_dnf.git
cd docker_dnf
```

#### 2. 自定义修改

你可以修改以下内容：
- `Mysql/Dockerfile` - MySQL 镜像构建配置
- `Mysql/mysqlstart.sh` - MySQL 启动脚本
- `Server/Dockerfile` - 服务端镜像构建配置
- `Server/serverstart.sh` - 服务端启动脚本
- `docker-compose.yml` - 服务编排配置

#### 3. 构建镜像

```bash
docker compose build
```

#### 4. 启动服务

```bash
docker compose up -d
```

---

## ⚙️ 环境变量说明

### dnf_mysql 环境变量

| 环境变量 | 必填 | 默认值 | 说明 |
|----------|------|--------|------|
| `TZ` | 否 | `Asia/Shanghai` | 时区 |
| `MYSQL_ROOT_PASSWORD` | 是 | `root123` | MySQL root 用户密码，game 用户密码也使用此值 |
| `SERVER_IP` | 否 | `dnf_server` | 游戏服务端容器名或 IP |
| `MYSQL_IP` | 否 | `dnf_mysql` | MySQL 服务器地址 |
| `GATE_AES_KEY` | 是 | - | AES-256-GCM 加密密钥（64 个十六进制字符 = 32 字节），必须与客户端配置一致 |

> 生成新的 AES Key：`openssl rand -hex 32`

### dnf_server 环境变量

| 环境变量 | 必填 | 默认值 | 说明 |
|----------|------|--------|------|
| `TZ` | 否 | `Asia/Shanghai` | 时区 |
| `ROOT_PASSWORD` | 是 | `root123` | SSH root 用户密码 |
| `PUBLIC_IP` | 是 | - | 服务器公网或内网 IP，客户端连接使用，必须正确设置 |
| `CLIENT_POOL_SIZE` | 否 | `64` | DofSlim 优化 - 客户端池最大并发连接数，调整此值可节省内存 |
| `MYSQL_IP` | 否 | `dnf_mysql` | MySQL 服务器地址 |

### CLIENT_POOL_SIZE 推荐值

| 场景 | 推荐值 | 节省内存 |
|------|--------|----------|
| 单人娱乐 | 3 | ~2.5 GB |
| 小型服务器 | 10-20 | ~2.4 GB |
| 中型服务器 | 128-256 | ~1.5 GB |
| 完全兼容 | 1000 | 0 GB（原版行为） |

---

## 🔐 默认账号密码

| 服务 | 用户名 | 密码 | 说明 |
|------|--------|------|------|
| MySQL root | root | `MYSQL_ROOT_PASSWORD` 环境变量值 | 仅本地登录 |
| MySQL game | game | `MYSQL_ROOT_PASSWORD` 环境变量值 | 远程登录 |
| MySQL game（dnf_server） | game | `uu5!^%jg` | 固定密码 |
| SSH root | root | `ROOT_PASSWORD` 环境变量值 | 远程连接 |

---

## 📱 客户端配置

### 1. 获取客户端(推荐)

客户端可从百度网盘下载：

**链接：** https://pan.baidu.com/s/1AuDJ-VO4A9uToAsrg6ETGw?pwd=sora  
**提取码：** `sora`

### 2. 注册账号

启动客户端登录器，修改连接网关的IP地址，注册账号后即可登录游戏。

---

## 📂 数据持久化

项目使用 Docker 卷进行数据持久化：

| 本地路径 | 容器路径 | 用途 |
|----------|----------|------|
| `./mysql_data` | `/var/lib/mysql` | MySQL 数据目录 |
| `./server_data/root` | `/root` | root 用户目录 |
| `./server_data/data` | `/data` | 数据目录（用于版本更新） |
| `./server_data/log` | `/home/neople/game/log` | 日志目录 |

### 查看日志

本地日志可在 `./server_data/log/` 目录查看。

---

## 🔄 版本更新

本项目支持热更新，有两种更新方式：

### 方法一：通过 data 目录更新（推荐）

1. 将需要更新的四个文件放到本地 `./Server/init/data/` 目录：
   - `df_game_r`
   - `frida.js`
   - `Script.pvf`
   - `publickey.pem`

2. 或者挂载到 `./server_data/data/` 目录：
```
./server_data/data/df_game_r
./server_data/data/frida.js
./server_data/data/Script.pvf
./server_data/data/publickey.pem
```

3. 重启容器：
```bash
docker compose restart dnf_server
```

启动脚本会自动将这些文件复制到 `/home/neople/game/` 目录。

### 方法二：通过 SSH 更新

1. 使用 SSH 连接到容器：
```bash
ssh root@你的服务器IP -p 22
```

2. 输入密码（默认 `root123`）

3. 直接上传文件到 `/home/neople/game/` 目录覆盖

4. 重启服务：
```bash
cd /root
./stop
./run
```

---

## 🔍 常见问题

### 1. 启动后无法连接数据库

**检查：**
```bash
# 查看 MySQL 日志
docker logs dnf_mysql
```

**解决方案：**
- 检查 `mysql_data` 目录权限
- 删除 `mysql_data` 目录，重新启动让其重新初始化
- 检查防火墙是否开放相关端口

### 2. 服务端启动后卡在 MySQL 连接检查

**原因：** 数据库还在初始化中，启动脚本会自动重试 10 次，每次间隔 10 秒。

**解决方案：**
- 耐心等待，首次启动数据库恢复需要较长时间
- 如果仍然失败，查看 MySQL 日志确认问题

### 3. 客户端能登录，但无法进入游戏

**检查：**
- `PUBLIC_IP` 是否正确设置为服务器实际 IP
- 防火墙是否开放相关端口（7001, 7200, 10011, 11011, 2311-2313 UDP/TCP）
- 查看服务端日志 `docker logs dnf_server`

### 4. 如何开启 PVP 频道？

**解决方案：**

编辑 `docker-compose.yml`，取消注释以下两行：
```yaml
#- 10052:10052/tcp    # df_game_r[ch.52]PVP
#- 11052:11052/udp    # df_game_r[ch.52]PVP
```
在run脚本添加启动频道

重启容器：
```bash
docker compose up -d --force-recreate
```

### 5. 忘记 root 密码如何修改？

**解决方案：**

1. 修改 `docker-compose.yml` 中的 `ROOT_PASSWORD`
2. 重建并启动：
```bash
docker compose up -d --force-recreate dnf_server
```

### 6. 如何备份数据库？

**方法一：从容器备份**
```bash
docker exec dnf_mysql mysqldump -u root -proot123 --all-databases > backup.sql
```

**方法二：从本地卷备份**
直接复制 `./mysql_data` 目录即可。

### 7. 容器占用太多内存？

本项目已集成 **[llnut/DofSlim](https://github.com/llnut/DofSlim)** 内存优化，可通过 `CLIENT_POOL_SIZE` 环境变量调整客户端池大小。

在 `docker-compose.yml` 中调整：
```yaml
environment:
  CLIENT_POOL_SIZE: 64
```

### 8. 修改 AES Key

编辑 `docker-compose.yml` 修改 `GATE_AES_KEY`，然后重启：
```bash
docker compose up -d --force-recreate dnf_mysql
```

客户端 `Config.toml` 中的 `aes_key` 也要同步修改。

---

## 📝 常用命令

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose stop

# 停止并删除容器（保留数据）
docker compose down

# 查看日志
docker compose logs dnf_server
docker compose logs -f dnf_server  # 实时跟踪

# 重启服务
docker compose restart

# 重启特定容器
docker compose restart dnf_server
docker compose restart dnf_mysql

# 进入容器
docker exec -it dnf_server bash
docker exec -it dnf_mysql bash

# 查看资源占用
docker stats

# 查看端口映射
docker port dnf_server
docker port dnf_mysql
```

---

## 🔐 安全建议

1. **修改默认密码**：首次部署后务必修改 `docker-compose.yml` 中的默认密码
2. **配置防火墙**：只开放必要端口，3306 不建议对公网开放
3. **使用反向代理**：如果需要公网访问登录网关，建议使用 Nginx 反向代理并配置 HTTPS
4. **定期备份**：定期备份数据库和游戏数据

---

## 🗺️ 网络架构

```
客户端
  ├─→ 登录器 → 5505 TCP → 登录网关（dnf_mysql）
  └─→ 游戏客户端 →
        ├→ 7001 TCP/UDP → 频道服务（dnf_server）
        ├→ 7200 TCP/UDP → 转发服务（dnf_server）
        ├→ 10011 TCP / 11011 UDP → 游戏场景（dnf_server）
        └→ 2311-2313 UDP → STUN 服务（dnf_server）

dnf_mysql <-> dnf_server（通过 Docker 内部网络 dnf_net 通信）
```

---

## 📊 服务启动流程

1. **dnf_mysql** 启动流程：
   - 启动 MySQL 服务
   - 首次启动恢复数据库备份
   - 创建数据库用户并授权
   - 更新数据库中的 Server IP 配置
   - 配置 AES Key 和 GAME_SERVER_IP
   - 启动 llnut 登录网关

2. **dnf_server** 启动流程：
   - 设置 SSH root 密码
   - 首次启动解压安装服务端文件
   - 自动替换配置文件中的 IP 和数据库信息
   - 检查 `/data` 目录，如果有新版本文件则更新
   - 等待 MySQL 就绪，重试连接
   - 启动所有游戏服务
   - 启动 SSH 服务保持容器运行

---

## 📜 声明

虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!
虽然支持外网，但是千万别拿来开服。只能拿来学习使用!!!

---

## 💬 沟通交流

欢迎各路大神加入，一起完善项目，成就当年梦，800万勇士冲！

> ⚠️ **重要声明**：群内没有任何收费项目，请勿上当受骗！

QQ 交流群：
- QQ 1群：**852685848** (已满)
- QQ 2群：**418505204** (已满)
- QQ 3群：**954929189** (已满)
- QQ 5群：**738105518** (已满)
- QQ 6群：**933010289**
- QQ 7群：**971177373**

---

## 参考项目

本项目参考了 [llnut/dnf](https://github.com/llnut/dnf)，在此表示感谢！

---

## 🙏 致谢

- [llnut/DofSlim](https://github.com/llnut/DofSlim) - 服务端内存优化
- [llnut/dnf](https://github.com/llnut/dnf) - DNF 容器化部署参考
- [llnut/dnf-login](https://github.com/llnut/dnf-login) - 开源登录网关
- CentOS 官方镜像
- MySQL 官方镜像
