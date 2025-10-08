FROM alpine:latest

# 安装必要的软件包
RUN apk add --no-cache \
    openssh-client \
    rsync \
    bash \
    tzdata \
    curl \
    sshpass \
    && rm -rf /var/cache/apk/*

# 创建备份脚本目录
RUN mkdir -p /app/scripts

# 复制备份脚本
COPY backup.sh /app/scripts/
RUN chmod +x /app/scripts/backup.sh

# 创建备份目录
RUN mkdir -p /backup

# 设置工作目录
WORKDIR /app

# 设置环境变量默认值
ENV BACKUP_SOURCE_HOST=192.168.100.1
ENV BACKUP_SOURCE_PORT=19020
ENV BACKUP_SOURCE_USER=root
ENV BACKUP_SOURCE_PASSWORD=
ENV BACKUP_SOURCE_PATH=/pig-workdir/pig-services
ENV BACKUP_DEST_PATH=/backup
ENV BACKUP_INTERVAL=3600
ENV BACKUP_PREFIX=pig-services-backup
ENV SSH_KEY_PATH=/app/ssh_key

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep [b]ackup.sh || exit 1

# 启动备份脚本
CMD ["/app/scripts/backup.sh"]