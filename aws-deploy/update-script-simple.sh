#!/bin/bash
set -e

INSTANCE_ID="i-0b3b312b21a19f71b"
REGION="ap-northeast-1"

echo "=== Updating auto-shutdown script on EC2 instance ==="
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"
echo ""

# Create the update command
cat > /tmp/update-autoshutdown.sh << 'UPDATE_SCRIPT'
#!/bin/bash
set -e

echo "Stopping minecraft-autoshutdown service..."
systemctl stop minecraft-autoshutdown.service

echo "Backing up old script..."
cp /usr/local/bin/minecraft-autoshutdown.sh /usr/local/bin/minecraft-autoshutdown.sh.backup.$(date +%Y%m%d-%H%M%S)

echo "Downloading new script from local..."
# The new script content will be embedded here
cat > /usr/local/bin/minecraft-autoshutdown.sh << 'AUTOSHUTDOWN_EOF'
#!/bin/bash

# Auto-shutdown script for Minecraft server
# Stops server after configurable idle time

LOG_FILE="/var/log/minecraft-autoshutdown.log"
MINECRAFT_LOG="/minecraft/server/logs/latest.log"
CHECK_INTERVAL=60  # Check every 1 minute
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# Get IDLE_TIME from SSM Parameter Store (default: 900 seconds = 15 minutes)
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')
IDLE_TIME=$(aws ssm get-parameter --name "/minecraft/${INSTANCE_ID}/idle_time" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "900")

# Validate IDLE_TIME is a number
if ! [[ "$IDLE_TIME" =~ ^[0-9]+$ ]]; then
    IDLE_TIME=900
fi

# Player tracking using associative array (bash 4.0+)
declare -A players

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Update player status from log
update_player_status() {
    if [ ! -f "$MINECRAFT_LOG" ]; then
        return
    fi
    
    # Process recent join/left events
    while IFS= read -r line; do
        # "PlayerName joined the game" pattern
        if [[ "$line" =~ \]:\ ([^\ ]+)\ joined\ the\ game ]]; then
            player="${BASH_REMATCH[1]}"
            players["$player"]=1
            log_message "Player joined: $player"
        fi
        
        # "PlayerName left the game" pattern
        if [[ "$line" =~ \]:\ ([^\ ]+)\ left\ the\ game ]]; then
            player="${BASH_REMATCH[1]}"
            unset players["$player"]
            log_message "Player left: $player"
        fi
    done < <(tail -n 500 "$MINECRAFT_LOG" | grep -E "(joined the game|left the game)")
}

# Get current player count
get_player_count() {
    echo "${#players[@]}"
}

# Get current player list
get_player_list() {
    if [ "${#players[@]}" -eq 0 ]; then
        echo "none"
    else
        echo "${!players[@]}"
    fi
}

idle_seconds=0
last_player_count=0

log_message "========================================="
log_message "Auto-shutdown monitor started (NEW VERSION with SSM + Discord Bot)"
log_message "Server will stop after ${IDLE_TIME} seconds ($(($IDLE_TIME / 60)) minutes) of no players"
log_message "Instance ID: $INSTANCE_ID, Region: $REGION"
log_message "========================================="

while true; do
    # Update player status
    update_player_status
    
    player_count=$(get_player_count)
    
    # Log when player count changes
    if [ "$player_count" -ne "$last_player_count" ]; then
        player_list=$(get_player_list)
        log_message "Player count changed: $last_player_count -> $player_count (current: $player_list)"
        last_player_count=$player_count
    fi
    
    if [ "$player_count" -eq 0 ]; then
        idle_seconds=$((idle_seconds + CHECK_INTERVAL))
        
        # Log status every 5 minutes
        if [ $((idle_seconds % 300)) -eq 0 ]; then
            remaining=$((IDLE_TIME - idle_seconds))
            log_message "No players for ${idle_seconds}s (stopping in ${remaining}s)"
        fi
        
        if [ "$idle_seconds" -ge "$IDLE_TIME" ]; then
            log_message "========================================="
            log_message "Stopping server after ${IDLE_TIME} seconds ($(($IDLE_TIME / 60)) minutes) of no players"
            log_message "========================================="
            
            # Send Discord notification via Lambda
            current_time=$(date '+%Y-%m-%d %H:%M:%S')
            message="🛑 **Minecraftサーバーが自動停止しました**\n\n理由: プレイヤー不在$(($IDLE_TIME / 60))分経過\n停止時刻: $current_time"
            
            # URL encode the message
            encoded_message=$(echo -n "$message" | jq -sRr @uri)
            
            # Call Lambda function via API Gateway
            NOTIFY_URL="https://mf71h6a5f9.execute-api.${REGION}.amazonaws.com/prod/notify?message=${encoded_message}&channel=status"
            
            log_message "Sending notification to: $NOTIFY_URL"
            curl -s "$NOTIFY_URL" || log_message "Failed to send Discord notification"
            
            # Stop Minecraft server
            systemctl stop minecraft.service
            sleep 5
            
            # Stop EC2 instance
            log_message "Stopping EC2 instance: $INSTANCE_ID (region: $REGION)"
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
            
            log_message "Server stop command executed"
            exit 0
        fi
    else
        # Reset idle timer when players are online
        if [ "$idle_seconds" -gt 0 ]; then
            player_list=$(get_player_list)
            log_message "Players online. Resetting idle timer (players: $player_list)"
        fi
        idle_seconds=0
    fi
    
    sleep "$CHECK_INTERVAL"
done
AUTOSHUTDOWN_EOF

echo "Setting permissions..."
chmod +x /usr/local/bin/minecraft-autoshutdown.sh

echo "Restarting minecraft-autoshutdown service..."
systemctl start minecraft-autoshutdown.service

echo "Checking service status..."
systemctl status minecraft-autoshutdown.service --no-pager || true

echo "Tailing log (last 30 lines)..."
tail -n 30 /var/log/minecraft-autoshutdown.log || echo "Log file not found yet"

echo ""
echo "=== Script update completed successfully! ==="
echo "New version features:"
echo "  - Reads IDLE_TIME from SSM Parameter Store"
echo "  - Sends notifications to server-status channel via Discord Bot"
echo "  - Improved logging with instance ID and region"
UPDATE_SCRIPT

# Send the command via SSM
echo "Sending update command via SSM..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --document-name "AWS-RunShellScript" \
    --comment "Update auto-shutdown script to new version" \
    --parameters 'commands=["bash /tmp/update-autoshutdown.sh"]' \
    --output json > /tmp/ssm-command-result.json

COMMAND_ID=$(cat /tmp/ssm-command-result.json | grep -o '"CommandId": "[^"]*"' | cut -d'"' -f4)

echo "Command sent! Command ID: $COMMAND_ID"
echo "Waiting 10 seconds for command to execute..."
sleep 10

echo ""
echo "=== Fetching command output ==="
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --output text \
    --query 'StandardOutputContent'

echo ""
echo "=== Checking for errors ==="
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --output text \
    --query 'StandardErrorContent'

echo ""
echo "=== Update Complete ==="
