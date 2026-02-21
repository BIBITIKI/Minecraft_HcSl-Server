#!/bin/bash
LOG_FILE="/home/ec2-user/minecraft/logs/latest.log"
if [ -f "$LOG_FILE" ]; then
    echo "=== Player Count Detection ==="
    echo ""
    echo "Recent join/leave events:"
    tail -n 500 "$LOG_FILE" | grep -E "joined the game|left the game" | tail -10
    echo ""
    echo "Calculating current players..."
    PLAYERS=$(tail -n 500 "$LOG_FILE" | grep -E "joined the game|left the game" | awk '{
        for(i=1; i<=NF; i++) {
            if($i == "joined" || $i == "left") {
                player = $(i-1)
                action = $i
                players[player] = action
            }
        }
    }
    END {
        count = 0
        for(p in players) {
            if(players[p] == "joined") {
                print p " is online" > "/dev/stderr"
                count++
            }
        }
        print count
    }')
    echo ""
    echo "Current Players: $PLAYERS"
else
    echo "Log file not found"
fi
