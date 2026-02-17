#!/bin/bash

# Auto-shutdown script for Minecraft server
# Stops server after 15 minutes of no players

LOG_FILE="/var/log/minecraft-autoshutdown.log"
MINECRAFT_LOG="/minecraft/server/logs/latest.log"
CHECK_INTERVAL=60  # Check every 1 minute
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# Get instance metadata (once at startup)
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')

# Function to get IDLE_TIME from SSM Parameter Store
get_idle_time() {
    local idle_time=$(aws ssm get-parameter --name "/minecraft/${INSTANCE_ID}/idle_time" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "900")
    
    # Validate IDLE_TIME is a number
    if ! [[ "$idle_time" =~ ^[0-9]+$ ]]; then
        idle_time=900
    fi
    
    echo "$idle_time"
}

# Initial IDLE_TIME
IDLE_TIME=$(get_idle_time)
LAST_CONFIG_CHECK=0
CONFIG_CHECK_INTERVAL=60  # Check for config changes every 1 minute (60 seconds) for faster response

# Player tracking using associative array (bash 4.0+)
declare -A players

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Send Discord notification
send_discord_notification() {
    local message="$1"
    
    if [ -z "$DISCORD_WEBHOOK_URL" ]; then
        log_message "Discord webhook not configured, skipping notification"
        return
    fi
    
    local json_payload=$(cat <<EOF
{
  "content": "$message"
}
EOF
)
    
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "$json_payload" \
         "$DISCORD_WEBHOOK_URL" 2>&1 | tee -a "$LOG_FILE"
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
log_message "Auto-shutdown monitor started (improved version)"
log_message "Server will stop after ${IDLE_TIME} seconds ($(($IDLE_TIME / 60)) minutes) of no players"
log_message "Instance ID: $INSTANCE_ID, Region: $REGION"
log_message "========================================="

while true; do
    # Periodically check for config changes (every 1 minute for faster response)
    current_time=$(date +%s)
    if [ $((current_time - LAST_CONFIG_CHECK)) -ge $CONFIG_CHECK_INTERVAL ]; then
        NEW_IDLE_TIME=$(get_idle_time)
        if [ "$NEW_IDLE_TIME" -ne "$IDLE_TIME" ]; then
            log_message "========================================="
            log_message "Config change detected: IDLE_TIME changed from ${IDLE_TIME}s ($(($IDLE_TIME / 60))min) to ${NEW_IDLE_TIME}s ($(($NEW_IDLE_TIME / 60))min)"
            
            # Config change behavior:
            # - If new IDLE_TIME < current idle_seconds: Reset idle_seconds to prevent immediate shutdown
            # - If new IDLE_TIME >= current idle_seconds: Keep current idle_seconds to preserve wait time
            if [ "$NEW_IDLE_TIME" -lt "$idle_seconds" ]; then
                log_message "New IDLE_TIME is shorter than current idle time. Resetting idle counter to prevent immediate shutdown."
                idle_seconds=0
            else
                log_message "New IDLE_TIME is longer than current idle time. Keeping current idle counter (${idle_seconds}s)."
            fi
            
            log_message "========================================="
            IDLE_TIME=$NEW_IDLE_TIME
        fi
        LAST_CONFIG_CHECK=$current_time
    fi
    
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
            log_message "Stopping server after ${IDLE_TIME} seconds of no players"
            log_message "========================================="
            
            # Send Discord notification via Webhook
            current_time=$(date '+%Y-%m-%d %H:%M:%S')
            idle_minutes=$(($IDLE_TIME / 60))
            
            # Get Discord Webhook URL from SSM Parameter Store
            WEBHOOK_URL=$(aws ssm get-parameter --name "/minecraft/${INSTANCE_ID}/discord_webhook" --region "$REGION" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
            
            if [ -n "$WEBHOOK_URL" ]; then
                log_message "========================================="
                log_message "Sending Discord notification via Webhook"
                log_message "Webhook URL: ${WEBHOOK_URL:0:50}..."
                log_message "========================================="
                
                # Create JSON payload (simple English message to avoid encoding issues)
                json_payload="{\"content\":\"🛑 Server auto-stopped\\n\\nReason: No players for ${idle_minutes} minutes\\nTime: ${current_time}\"}"
                
                log_message "Sending payload: $json_payload"
                
                # Send to Discord Webhook
                response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -H "Content-Type: application/json" -X POST -d "$json_payload" "$WEBHOOK_URL")
                
                if [ $? -eq 0 ]; then
                    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
                    response_body=$(echo "$response" | grep -v "HTTP_CODE:")
                    log_message "Discord notification sent - HTTP Code: $http_code"
                    log_message "Response: $response_body"
                else
                    log_message "Failed to send Discord notification - curl error"
                fi
            else
                log_message "Discord Webhook URL not configured in SSM Parameter Store"
                log_message "Skipping Discord notification"
            fi
            
            # Stop Minecraft server
            systemctl stop minecraft.service
            sleep 5
            
            # Stop EC2 instance
            INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
            
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
