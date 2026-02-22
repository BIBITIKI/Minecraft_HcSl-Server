#!/bin/bash
# Fix player detection to handle long play sessions

echo "========================================="
echo "Fixing Player Detection Logic"
echo "========================================="

cd /home/ec2-user/minecraft

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)

echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

# Get idle time from SSM
IDLE_TIME=$(aws ssm get-parameter --name "/minecraft/${INSTANCE_ID}/idle_time" --region $REGION --query "Parameter.Value" --output text 2>/dev/null)
if [ -z "$IDLE_TIME" ] || [ "$IDLE_TIME" == "None" ]; then
    IDLE_TIME=600  # Default 10 minutes
fi

echo "Idle time: $IDLE_TIME seconds ($((IDLE_TIME / 60)) minutes)"

# Create improved auto-shutdown script with better player detection
echo "Creating improved auto-shutdown script..."
sudo tee /usr/local/bin/minecraft-autoshutdown.sh > /dev/null << 'AUTOSHUTDOWN'
#!/bin/bash

# Auto-shutdown script for Minecraft server
# Improved player detection for long play sessions

LOG_FILE="/var/log/minecraft-autoshutdown.log"
MINECRAFT_LOG="/home/ec2-user/minecraft/logs/latest.log"
CHECK_INTERVAL=60  # Check every 1 minute

# Get instance metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)

# Get idle time from SSM Parameter Store
IDLE_TIME=$(aws ssm get-parameter --name "/minecraft/${INSTANCE_ID}/idle_time" --region $REGION --query "Parameter.Value" --output text 2>/dev/null)

if [ -z "$IDLE_TIME" ] || [ "$IDLE_TIME" == "None" ]; then
    IDLE_TIME=600  # Default 10 minutes
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_player_count() {
    if [ ! -f "$MINECRAFT_LOG" ]; then
        echo "0"
        return
    fi
    
    # Use entire log file to track all players
    # Get the last action (joined/left) for each unique player
    local player_count=$(grep -E "joined the game|left the game" "$MINECRAFT_LOG" | \
        awk '{
            # Extract player name (word before "joined" or "left")
            for(i=1; i<=NF; i++) {
                if($i == "joined" || $i == "left") {
                    player = $(i-1)
                    action = $i
                    # Store the last action for this player
                    players[player] = action
                }
            }
        }
        END {
            count = 0
            for(p in players) {
                if(players[p] == "joined") {
                    count++
                }
            }
            print count
        }')
    
    echo "$player_count"
}

log "========================================="
log "Auto-shutdown monitor started (improved player detection)"
log "Instance ID: $INSTANCE_ID, Region: $REGION"
log "Idle time: $IDLE_TIME seconds ($((IDLE_TIME / 60)) minutes)"
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
            
            # Wait for graceful shutdown
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

echo "Restarting auto-shutdown service..."
sudo systemctl restart minecraft-autoshutdown.service

echo "Checking service status..."
sudo systemctl status minecraft-autoshutdown.service --no-pager | head -15

echo ""
echo "========================================="
echo "Player detection improved!"
echo "Now tracks all players in entire log file"
echo "Idle time: $IDLE_TIME seconds ($((IDLE_TIME / 60)) minutes)"
echo "========================================="
