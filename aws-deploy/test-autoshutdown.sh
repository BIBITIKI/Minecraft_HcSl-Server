#!/bin/bash

# 自動停止スクリプトのテスト用
# ローカルでログファイルを使ってプレイヤー判定をテスト

MINECRAFT_LOG="$1"

if [ -z "$MINECRAFT_LOG" ]; then
    echo "使用方法: $0 <minecraft-log-file>"
    echo "例: $0 C:/Kiro/Minecraft_HcSl-Server/logs/latest.log"
    exit 1
fi

if [ ! -f "$MINECRAFT_LOG" ]; then
    echo "エラー: ログファイルが見つかりません: $MINECRAFT_LOG"
    exit 1
fi

echo "========================================="
echo "自動停止スクリプト テスト"
echo "ログファイル: $MINECRAFT_LOG"
echo "========================================="
echo ""

# プレイヤー追跡用の連想配列
declare -A players

# ログからプレイヤーの状態を更新
update_player_status() {
    while IFS= read -r line; do
        # "PlayerName joined the game" パターン
        if [[ "$line" =~ \]:\ ([^\ ]+)\ joined\ the\ game ]]; then
            player="${BASH_REMATCH[1]}"
            players["$player"]=1
            echo "[JOIN] $player が参加しました"
        fi
        
        # "PlayerName left the game" パターン
        if [[ "$line" =~ \]:\ ([^\ ]+)\ left\ the\ game ]]; then
            player="${BASH_REMATCH[1]}"
            unset players["$player"]
            echo "[LEFT] $player が退出しました"
        fi
    done < <(grep -E "(joined the game|left the game)" "$MINECRAFT_LOG")
}

# プレイヤー状態を更新
update_player_status

echo ""
echo "========================================="
echo "最終結果"
echo "========================================="
echo "現在のプレイヤー数: ${#players[@]}"

if [ "${#players[@]}" -eq 0 ]; then
    echo "現在のプレイヤー: なし"
    echo ""
    echo "✅ 全員退出しています。15分後に自動停止します。"
else
    echo "現在のプレイヤー: ${!players[@]}"
    echo ""
    echo "❌ プレイヤーが接続中です。自動停止しません。"
fi

echo ""
