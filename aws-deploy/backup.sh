#!/bin/bash

# バックアップスクリプト
BACKUP_DIR="/home/ec2-user/minecraft-backups"
WORLD_DIR="/home/ec2-user/minecraft-server/world"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/minecraft-backup-$DATE.tar.gz"

mkdir -p $BACKUP_DIR

# ワールドデータをバックアップ
tar -czf $BACKUP_FILE $WORLD_DIR

# 7日以上前のバックアップを削除
find $BACKUP_DIR -name "minecraft-backup-*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE"
