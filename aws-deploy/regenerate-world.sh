#!/bin/bash
# Regenerate Minecraft world with new seed

echo "========================================="
echo "Minecraft World Regeneration Script"
echo "========================================="

cd /home/ec2-user/minecraft

# Stop Minecraft server
echo "Stopping Minecraft server..."
sudo systemctl stop minecraft.service
sleep 5

# Backup old world to S3
echo "Backing up old world to S3..."
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
tar -czf world_backup_${BACKUP_DATE}.tar.gz world/
aws s3 cp world_backup_${BACKUP_DATE}.tar.gz s3://minecraft-server-mods-temp/backups/ --region ap-northeast-1
echo "Backup saved to s3://minecraft-server-mods-temp/backups/world_backup_${BACKUP_DATE}.tar.gz"

# Remove old world
echo "Removing old world data..."
rm -rf world/
rm -rf world_nether/
rm -rf world_the_end/

# Optional: Set new seed in server.properties
# Uncomment and set your desired seed if you want a specific one
# sed -i 's/^level-seed=.*/level-seed=YOUR_SEED_HERE/' server.properties

# Clear seed to generate random
echo "Clearing seed for random generation..."
sed -i 's/^level-seed=.*/level-seed=/' server.properties

# Start Minecraft server (will generate new world)
echo "Starting Minecraft server..."
echo "New world will be generated on startup..."
sudo systemctl start minecraft.service

echo "========================================="
echo "World regeneration initiated!"
echo "Old world backed up to S3"
echo "Server is generating new world..."
echo "Check logs: sudo journalctl -u minecraft.service -f"
echo "========================================="
