#!/bin/bash
# Setup auto-shutdown with 10 minute idle time

cd /home/ec2-user/minecraft

echo "Creating auto-shutdown script with 10 minute idle time..."
sudo tee /usr/local/bin/minecraft-autoshutdown.sh > /dev/null << 'AUTOSHUTDOWN'
#!/bin/bash

# Auto-shutdown script for Minecraft server
# Stops server after 10 minutes of no players

LOG_FILE="/var/log/minecraft-autoshutdown.log"
MINECRAFT_LOG="/home/ec2-user/minecraft/logs/latest.log"
CHECK_INTERVAL=60  # Check every 1 minute
IDLE_TIME=600  # 10 minutes in seconds

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_player_count() {
    if [ ! -f "$MINECRAFT_LOG" ]; then
        echo "0"
        return
    fi
    
    # Count unique players who joined (more reliable than "players online")
    local recent_joins=$(tail -n 100 "$MINECRAFT_LOG" | grep -c "joined the game")
    local recent_leaves=$(tail -n 100 "$MINECRAFT_LOG" | grep -c "left the game")
    local player_count=$((recent_joins - recent_leaves))
    
    # Ensure non-negative
    if [ $player_count -lt 0 ]; then
        player_count=0
    fi
    
    echo "$player_count"
}

log "========================================="
log "Auto-shutdown monitor started (10 minute idle time)"
log "Instance ID: $INSTANCE_ID, Region: $REGION"
log "========================================="

idle_seconds=0

while true; do
    player_count=$(get_player_count)
    
    if [ "$player_count" -eq 0 ]; then
        idle_seconds=$((idle_seconds + CHECK_INTERVAL))
        remaining=$((IDLE_TIME - idle_seconds))
        log "No players for ${idle_seconds}s (stopping in ${remaining}s)"
        
        if [ $idle_seconds -ge $IDLE_TIME ]; then
            log "========================================="
            log "Stopping server after $IDLE_TIME seconds of no players"
            log "========================================="
            
            # Stop Minecraft service gracefully
            systemctl stop minecraft.service
            
            # Wait a bit for graceful shutdown
            sleep 10
            
            # Stop EC2 instance
            log "Stopping EC2 instance: $INSTANCE_ID (region: $REGION)"
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
            log "Server stop command executed"
            exit 0
        fi
    else
        if [ $idle_seconds -gt 0 ]; then
            log "Players detected ($player_count). Resetting idle timer."
        fi
        idle_seconds=0
    fi
    
    sleep $CHECK_INTERVAL
done
AUTOSHUTDOWN

echo "Setting permissions..."
sudo chmod +x /usr/local/bin/minecraft-autoshutdown.sh

echo "Restarting service..."
sudo systemctl restart minecraft-autoshutdown.service

echo "Checking service status..."
sudo systemctl status minecraft-autoshutdown.service --no-pager

echo "Done! Auto-shutdown will trigger after 10 minutes of no players."
