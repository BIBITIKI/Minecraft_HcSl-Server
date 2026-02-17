#!/bin/bash
set -e

echo "=== Minecraft Server AWS Setup ==="

# システム更新
sudo yum update -y
sudo yum install -y docker git

# Docker起動
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Docker Compose インストール
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# サーバーディレクトリ作成
mkdir -p /home/ec2-user/minecraft-server
cd /home/ec2-user/minecraft-server

echo "=== Setup Complete ==="
echo "Next: Upload server files and run docker-compose up -d"
