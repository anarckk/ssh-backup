#!/bin/bash

# 设置错误处理
set -euo pipefail

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 错误处理函数
error_exit() {
    log "ERROR: $1"
    exit 1
}

# 检查必需的环境变量
check_env_vars() {
    local required_vars=("BACKUP_SOURCE_HOST" "BACKUP_SOURCE_PORT" "BACKUP_SOURCE_USER" "BACKUP_SOURCE_PATH" "BACKUP_DEST_PATH")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error_exit "环境变量 $var 未设置"
        fi
    done
}

# 检查认证方式
check_auth_method() {
    if [[ -n "${BACKUP_SOURCE_PASSWORD:-}" ]]; then
        echo "password"
    elif [[ -f "${SSH_KEY_PATH:-}" ]]; then
        echo "key"
    else
        error_exit "未配置认证方式：请设置BACKUP_SOURCE_PASSWORD或挂载SSH密钥文件"
    fi
}

# 检查SSH连接
check_ssh_connection() {
    local auth_method="$1"
    
    log "检查SSH连接..."
    
    if [[ "$auth_method" == "password" ]]; then
        sshpass -p "$BACKUP_SOURCE_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p "$BACKUP_SOURCE_PORT" "$BACKUP_SOURCE_USER@$BACKUP_SOURCE_HOST" "echo 'SSH连接成功'" || error_exit "SSH连接失败"
    elif [[ "$auth_method" == "key" ]]; then
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p "$BACKUP_SOURCE_PORT" -i "$SSH_KEY_PATH" "$BACKUP_SOURCE_USER@$BACKUP_SOURCE_HOST" "echo 'SSH连接成功'" || error_exit "SSH连接失败"
    fi
    
    log "SSH连接成功"
}

# 创建镜像同步备份
create_mirror_backup() {
    local auth_method="$1"
    local backup_path="$BACKUP_DEST_PATH/$BACKUP_PREFIX"
    
    log "开始镜像同步备份到: $backup_path"
    
    # 创建备份目录
    mkdir -p "$backup_path"
    
    log "执行镜像同步rsync命令..."
    
    # 执行镜像同步备份
    if [[ "$auth_method" == "password" ]]; then
        sshpass -p "$BACKUP_SOURCE_PASSWORD" rsync -avz --delete --progress -e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p $BACKUP_SOURCE_PORT" "$BACKUP_SOURCE_USER@$BACKUP_SOURCE_HOST:$BACKUP_SOURCE_PATH/" "$backup_path/" || error_exit "rsync镜像同步失败"
    elif [[ "$auth_method" == "key" ]]; then
        rsync -avz --delete --progress -e "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p $BACKUP_SOURCE_PORT -i $SSH_KEY_PATH" "$BACKUP_SOURCE_USER@$BACKUP_SOURCE_HOST:$BACKUP_SOURCE_PATH/" "$backup_path/" || error_exit "rsync镜像同步失败"
    fi
    
    log "镜像同步备份完成: $backup_path"
    
    # 显示备份统计信息
    local backup_size=$(du -sh "$backup_path" | cut -f1)
    local file_count=$(find "$backup_path" -type f | wc -l)
    log "备份统计: 大小=$backup_size, 文件数=$file_count"
}

# 清理旧备份（需求v3：不需要多个备份，此函数为空）
cleanup_old_backups() {
    log "需求v3：使用单一备份目录，无需清理旧备份"
}

# 主函数
main() {
    log "=== SSH备份容器启动 ==="
    
    # 检查环境变量
    check_env_vars
    
    # 检查备份目标目录是否存在
    if [[ ! -d "$BACKUP_DEST_PATH" ]]; then
        error_exit "备份目标目录不存在: $BACKUP_DEST_PATH"
    fi
    
    # 确定认证方式
    local auth_method=$(check_auth_method)
    log "使用${auth_method}认证方式"
    
    # 如果是密钥认证，检查密钥文件权限
    if [[ "$auth_method" == "key" ]]; then
        if [[ ! -f "$SSH_KEY_PATH" ]]; then
            error_exit "SSH密钥文件不存在: $SSH_KEY_PATH"
        fi
        chmod 600 "$SSH_KEY_PATH"
        log "SSH密钥权限设置完成"
    fi
    
    # 检查sshpass（如果使用密码认证）
    if [[ "$auth_method" == "password" ]]; then
        log "检查sshpass..."
        if ! command -v sshpass &> /dev/null; then
            error_exit "sshpass未安装，请确保Docker镜像已正确构建"
        fi
        log "sshpass已就绪"
    fi
    
    # 无限循环执行备份
    while true; do
        log "开始备份周期"
        
        # 检查SSH连接
        check_ssh_connection "$auth_method"
        
        # 创建镜像同步备份
        create_mirror_backup "$auth_method"
        
        # 清理旧备份
        cleanup_old_backups
        
        log "备份完成，等待 $BACKUP_INTERVAL 秒后继续..."
        sleep "$BACKUP_INTERVAL"
    done
}

# 捕获信号，优雅退出
trap 'log "收到退出信号，正在退出..."; exit 0' SIGTERM SIGINT

# 运行主函数
main