#!/bin/bash
# Configure Minecraft server settings and regenerate world

echo "========================================="
echo "Minecraft Server Configuration"
echo "========================================="

cd /home/ec2-user/minecraft

# Stop Minecraft server
echo "Stopping Minecraft server..."
sudo systemctl stop minecraft.service
sleep 5

# Backup old world to S3
echo "Backing up old world to S3..."
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
if [ -d "world" ]; then
    tar -czf world_backup_${BACKUP_DATE}.tar.gz world/
    # Try to upload to S3 (may fail if permissions not set)
    aws s3 cp world_backup_${BACKUP_DATE}.tar.gz s3://minecraft-server-mods-temp/backups/ --region ap-northeast-1 2>/dev/null || echo "S3 upload skipped (backup saved locally)"
fi

# Remove old world
echo "Removing old world data..."
rm -rf world/
rm -rf world_nether/
rm -rf world_the_end/

# Update server.properties
echo "Updating server.properties..."
sed -i 's/^difficulty=.*/difficulty=hard/' server.properties
sed -i 's/^enable-command-block=.*/enable-command-block=true/' server.properties
sed -i 's/^level-seed=.*/level-seed=/' server.properties

echo "Updated settings:"
grep -E "^(difficulty|enable-command-block|level-seed)=" server.properties

# Create ops.json with BIBITIKI
echo "Adding BIBITIKI as operator..."
cat > ops.json << 'EOF'
[
  {
    "uuid": "ffcdfbad-3762-4ac6-9b11-d2fcd32eef18",
    "name": "BIBITIKI",
    "level": 4,
    "bypassesPlayerLimit": false
  }
]
EOF

echo "ops.json created"
cat ops.json

# Set permissions
chown -R ec2-user:ec2-user /home/ec2-user/minecraft

# Start Minecraft server (will generate new world)
echo "Starting Minecraft server..."
echo "New world will be generated with updated settings..."
sudo systemctl start minecraft.service

echo "========================================="
echo "Configuration complete!"
echo "- Difficulty: Hard"
echo "- Command blocks: Enabled"
echo "- BIBITIKI: Operator (level 4)"
echo "- New world: Generating..."
echo "========================================="
echo "Check logs: sudo journalctl -u minecraft.service -f"
