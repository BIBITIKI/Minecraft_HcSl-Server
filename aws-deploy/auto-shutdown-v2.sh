#!/bin/bash

# プレイヤー不在時の自動停止スクリプト（改良版）
# join/leftイベントを追跡して正確にプレイヤー数を判定

LOG_FILE="/var/log/minecraft-autoshutdown.log"
MINECRAFT_LOG="/minecraft/server/logs/latest.log"
IDLE_TIME=900  # 15分（秒）
CHECK_INTERVAL=60  # 1分ごとにチェック

# プレイヤー追跡用の連想配列（bash 4.0以降）
declare -A players

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ログからプレイヤーの状態を更新
update_player_status() {
    if [ ! -f "$MINECRAFT_LOG" ]; then
        return
    fi
    
    # 最新のjoin/leftイベントを処理
    while IFS= read -r line; do
        # "PlayerName joined the game" パターン
        if [[ "$line" =~ \]:\ ([^\ ]+)\ joined\ the\ game ]]; then
            player="${BASH_REMATCH[1]}"
            players["$player"]=1
            log_message "プレイヤー参加: $player"
        fi
        
        # "PlayerName left the game" パターン
        if [[ "$line" =~ \]:\ ([^\ ]+)\ left\ the\ game ]]; then
            player="${BASH_REMATCH[1]}"
            unset players["$player"]
            log_message "プレイヤー退出: $player"
        fi
    done < <(tail -n 500 "$MINECRAFT_LOG" | grep -E "(joined the game|left the game)")
}

# 現在のプレイヤー数を取得
get_player_count() {
    echo "${#players[@]}"
}

# 現在のプレイヤーリストを取得
get_player_list() {
    if [ "${#players[@]}" -eq 0 ]; then
        echo "なし"
    else
        echo "${!players[@]}"
    fi
}

idle_seconds=0
last_player_count=0

log_message "自動停止監視を開始しました（改良版）"
log_message "15分間プレイヤー不在で自動停止します"

while true; do
    # プレイヤー状態を更新
    update_player_status
    
    player_count=$(get_player_count)
    
    # プレイヤー数が変化した場合はログ出力
    if [ "$player_count" -ne "$last_player_count" ]; then
        player_list=$(get_player_list)
        log_message "プレイヤー数変化: $last_player_count → $player_count (現在: $player_list)"
        last_player_count=$player_count
    fi
    
    if [ "$player_count" -eq 0 ]; then
        idle_seconds=$((idle_seconds + CHECK_INTERVAL))
        
        # 5分ごとに状態をログ出力
        if [ $((idle_seconds % 300)) -eq 0 ]; then
            remaining=$((IDLE_TIME - idle_seconds))
            log_message "プレイヤー不在継続中: ${idle_seconds}秒経過 (残り${remaining}秒で停止)"
        fi
        
        if [ "$idle_seconds" -ge "$IDLE_TIME" ]; then
            log_message "========================================="
            log_message "15分間プレイヤー不在のため、サーバーを停止します"
            log_message "========================================="
            
            # Minecraftサーバーを停止
            systemctl stop minecraft.service
            sleep 5
            
            # EC2インスタンスを停止
            INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
            REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')
            
            log_message "EC2インスタンス停止: $INSTANCE_ID (リージョン: $REGION)"
            aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"
            
            log_message "サーバー停止コマンドを実行しました"
            exit 0
        fi
    else
        # プレイヤーがいる場合、アイドルタイマーをリセット
        if [ "$idle_seconds" -gt 0 ]; then
            player_list=$(get_player_list)
            log_message "プレイヤーが接続中です。アイドルタイマーをリセット (プレイヤー: $player_list)"
        fi
        idle_seconds=0
    fi
    
    sleep "$CHECK_INTERVAL"
done
