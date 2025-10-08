#!/bin/bash

# 构建脚本
set -e

echo "=== SSH备份容器构建脚本 ==="

# 检查必需的文件
if [[ ! -f "Dockerfile" ]]; then
    echo "错误: Dockerfile 不存在"
    exit 1
fi

if [[ ! -f "backup.sh" ]]; then
    echo "错误: backup.sh 不存在"
    exit 1
fi

# 检查认证配置
if [[ ! -f "id_rsa" ]]; then
    echo "警告: id_rsa 文件不存在"
    echo "您可以选择以下认证方式:"
    echo ""
    echo "1. 密码认证: 在.env文件中设置BACKUP_SOURCE_PASSWORD"
    echo "2. 密钥认证: 创建SSH密钥对"
    echo "   创建密钥: ssh-keygen -t rsa -b 4096 -f id_rsa"
    echo "   复制公钥: ssh-copy-id -p 19020 -i id_rsa.pub root@192.168.100.1"
    echo ""
    echo "注意: 密码认证优先于密钥认证"
fi

# 构建Docker镜像
echo "构建Docker镜像..."
docker build -t ssh-backup .

echo "构建完成!"
echo ""
echo "使用方法:"
echo "1. 复制环境变量文件: cp .env.example .env"
echo "2. 编辑 .env 文件配置您的参数"
echo "3. 启动容器: docker-compose up -d"
echo "4. 查看日志: docker-compose logs -f"