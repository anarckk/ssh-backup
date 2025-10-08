# SSH备份容器

一个用于通过SSH连接远程服务器并进行增量备份的Docker容器。

## 功能特性

- 🔐 支持密码和SSH密钥两种认证方式
- 🔄 真正的镜像同步（删除本地多余文件）
- 📈 智能文件覆盖（大小或时间戳不一致时覆盖）
- ⚙️ 完全通过环境变量配置
- 🕒 定时自动备份
- 📁 单一备份目录（需求v3：不需要多个备份版本）
- 🏥 健康检查监控

## 快速开始

### 1. 准备SSH密钥

将您的SSH私钥文件命名为`id_rsa`并放在项目根目录：

```bash
# 复制您的私钥到项目目录
cp /path/to/your/private/key ./id_rsa
```

### 2. 配置环境变量

复制并编辑环境变量文件：

```bash
cp .env.example .env
# 编辑.env文件配置您的参数
```

### 3. 启动容器

```bash
# 构建并启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 环境变量配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `BACKUP_SOURCE_HOST` | 192.168.100.1 | 远程服务器地址 |
| `BACKUP_SOURCE_PORT` | 19020 | SSH端口 |
| `BACKUP_SOURCE_USER` | root | SSH用户名 |
| `BACKUP_SOURCE_PASSWORD` | (空) | SSH密码（优先于密钥） |
| `BACKUP_SOURCE_PATH` | /pig-workdir/pig-services | 备份源路径 |
| `BACKUP_DEST_PATH` | /backup | 备份目标路径 |
| `BACKUP_INTERVAL` | 3600 | 备份间隔（秒） |
| `BACKUP_PREFIX` | pig-services-backup | 备份文件前缀 |
| `SSH_KEY_PATH` | /app/ssh_key | SSH密钥路径 |

### 认证方式优先级

1. **密码认证优先**：如果设置了`BACKUP_SOURCE_PASSWORD`，则使用密码认证
2. **密钥认证备用**：如果未设置密码，则使用SSH密钥文件认证
3. **必须配置一种认证方式**

## 手动运行

如果您想手动运行而不是使用docker-compose：

```bash
# 构建镜像
docker build -t ssh-backup .

# 运行容器
docker run -d \
  --name ssh-backup \
  -v $(pwd)/backup_data:/backup \
  -v $(pwd)/id_rsa:/app/ssh_key:ro \
  -e BACKUP_SOURCE_HOST=192.168.100.1 \
  -e BACKUP_SOURCE_PORT=19020 \
  -e BACKUP_SOURCE_USER=root \
  -e BACKUP_SOURCE_PATH=/pig-workdir/pig-services \
  -e BACKUP_DEST_PATH=/backup \
  -e BACKUP_INTERVAL=3600 \
  -e BACKUP_PREFIX=pig-services-backup \
  -e SSH_KEY_PATH=/app/ssh_key \
  ssh-backup
```

## 备份特性

### 镜像同步策略（需求v3）

- **单一备份目录**：不再保留多个备份版本，只使用一个固定的备份目录
- **文件覆盖**：如果本地有和服务器同名文件，且文件大小或时间戳不一致，直接覆盖本地文件
- **文件删除**：如果服务器删除了文件，本地对应文件也会被删除
- **文件创建**：如果服务器新增了文件，本地会创建对应文件

### 备份文件结构

备份目录结构如下：

```
backup_data/
└── pig-services-backup/
    ├── minecraft/
    └── services/
```

- 使用固定的备份目录名称：`pig-services-backup`
- 每次备份直接镜像同步到同一个目录
- 确保本地备份与远程服务器完全一致

## 监控和日志

### 查看容器状态

```bash
docker-compose ps
docker-compose logs
```

### 健康检查

容器包含健康检查，可以通过以下命令查看：

```bash
docker inspect ssh-backup | jq '.[].State.Health'
```

## 故障排除

### SSH连接问题

1. 确保SSH密钥文件权限正确：
   ```bash
   chmod 600 id_rsa
   ```

2. 检查远程服务器SSH配置是否允许密钥登录

3. 测试SSH连接：
   ```bash
   ssh -p 19020 -i id_rsa root@192.168.100.1
   ```

### 备份失败

1. 检查源路径是否存在且可读
2. 检查目标路径是否有写入权限
3. 查看容器日志了解详细错误信息

## 安全注意事项

- 🔒 SSH密钥文件以只读方式挂载
- 🚫 不要在代码中硬编码密码或敏感信息
- 📝 定期轮换SSH密钥
- 🔄 监控备份作业状态