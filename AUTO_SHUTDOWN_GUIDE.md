# 自動停止機能ガイド

## 概要

サーバーは以下の条件で自動停止します：

1. **深夜3時（JST）**: EventBridgeで定時停止
2. **Discord経由**: `/serverstop` コマンドで手動停止
3. **プレイヤー不在**: 15分間誰もいない場合に自動停止

## プレイヤー不在判定の仕組み

### 改良版の判定ロジック

従来の `players online` カウントではなく、**join/leftイベントを追跡**して正確に判定します。

#### ログパターン
```
[18:27:43] [Server thread/INFO]: BIBITIKI joined the game
[18:27:53] [Server thread/INFO]: BIBITIKI left the game
```

#### 判定方法
1. `joined the game` イベントでプレイヤーを追加
2. `left the game` イベントでプレイヤーを削除
3. プレイヤーリストが空になったら15分カウント開始
4. 15分経過で自動停止

### テスト方法

ローカルでログファイルを使ってテスト：

```powershell
cd C:\Kiro\Minecraft_HcSl-Server

# テスト実行
$players = @{}
Get-Content logs\latest.log | ForEach-Object {
    if ($_ -match '\]:\s+(\S+)\s+joined\s+the\s+game') {
        $players[$Matches[1]] = $true
        Write-Host "[JOIN] $($Matches[1])" -ForegroundColor Green
    }
    if ($_ -match '\]:\s+(\S+)\s+left\s+the\s+game') {
        $players.Remove($Matches[1]) | Out-Null
        Write-Host "[LEFT] $($Matches[1])" -ForegroundColor Yellow
    }
}

Write-Host "現在のプレイヤー数: $($players.Count)"
if ($players.Count -eq 0) {
    Write-Host "✅ 全員退出しています" -ForegroundColor Green
} else {
    Write-Host "❌ プレイヤー接続中: $($players.Keys -join ', ')" -ForegroundColor Red
}
```

## 自動停止スクリプトの動作

### EC2上での動作

```bash
# ログ確認
sudo tail -f /var/log/minecraft-autoshutdown.log
```

### ログ出力例

```
[2026-02-15 18:27:43] 自動停止監視を開始しました（改良版）
[2026-02-15 18:27:43] 15分間プレイヤー不在で自動停止します
[2026-02-15 18:27:43] プレイヤー参加: BIBITIKI
[2026-02-15 18:27:43] プレイヤー数変化: 0 → 1 (現在: BIBITIKI)
[2026-02-15 18:27:53] プレイヤー退出: BIBITIKI
[2026-02-15 18:27:53] プレイヤー数変化: 1 → 0 (現在: なし)
[2026-02-15 18:32:53] プレイヤー不在継続中: 300秒経過 (残り600秒で停止)
[2026-02-15 18:37:53] プレイヤー不在継続中: 600秒経過 (残り300秒で停止)
[2026-02-15 18:42:53] =========================================
[2026-02-15 18:42:53] 15分間プレイヤー不在のため、サーバーを停止します
[2026-02-15 18:42:53] =========================================
[2026-02-15 18:42:58] EC2インスタンス停止: i-1234567890abcdef0 (リージョン: ap-northeast-1)
[2026-02-15 18:42:58] サーバー停止コマンドを実行しました
```

## 運用コマンド

### サービス状態確認

```bash
# 自動停止サービスの状態
sudo systemctl status minecraft-autoshutdown.service

# Minecraftサーバーの状態
sudo systemctl status minecraft.service
```

### ログ確認

```bash
# リアルタイムログ
sudo tail -f /var/log/minecraft-autoshutdown.log

# 最新100行
sudo tail -n 100 /var/log/minecraft-autoshutdown.log

# 特定のパターンを検索
sudo grep "プレイヤー" /var/log/minecraft-autoshutdown.log
```

### サービス再起動

```bash
# 自動停止サービスを再起動
sudo systemctl restart minecraft-autoshutdown.service

# ログをクリア
sudo truncate -s 0 /var/log/minecraft-autoshutdown.log
```

## トラブルシューティング

### 自動停止が動作しない

#### 1. サービスが起動しているか確認

```bash
sudo systemctl status minecraft-autoshutdown.service
```

停止している場合：
```bash
sudo systemctl start minecraft-autoshutdown.service
```

#### 2. ログファイルが存在するか確認

```bash
ls -la /minecraft/server/logs/latest.log
```

#### 3. IAMロールの権限確認

```bash
# EC2インスタンスがIAMロールを持っているか確認
aws sts get-caller-identity

# 停止権限があるか確認
aws ec2 describe-instances --instance-ids $(ec2-metadata --instance-id | cut -d " " -f 2)
```

権限エラーの場合、Terraformで作成したIAMロールが正しくアタッチされているか確認。

#### 4. スクリプトのデバッグ

```bash
# スクリプトを手動実行
sudo /usr/local/bin/minecraft-autoshutdown.sh
```

### プレイヤーがいるのに停止される

ログパターンが変わった可能性があります。

```bash
# 最新のログを確認
tail -n 100 /minecraft/server/logs/latest.log | grep -E "(joined|left)"
```

パターンが異なる場合、スクリプトの正規表現を修正：
```bash
sudo nano /usr/local/bin/minecraft-autoshutdown.sh
```

### 15分より早く停止される

タイマーがリセットされていない可能性があります。

```bash
# ログで確認
sudo grep "アイドルタイマーをリセット" /var/log/minecraft-autoshutdown.log
```

## カスタマイズ

### 待機時間の変更

デフォルトは15分（900秒）ですが、変更可能です。

```bash
sudo nano /usr/local/bin/minecraft-autoshutdown.sh
```

以下の行を変更：
```bash
IDLE_TIME=900  # 15分 → 例: 1800 (30分)
```

変更後、サービスを再起動：
```bash
sudo systemctl restart minecraft-autoshutdown.service
```

### チェック間隔の変更

デフォルトは1分（60秒）ごとにチェックします。

```bash
CHECK_INTERVAL=60  # 1分 → 例: 30 (30秒)
```

## 自動停止の無効化

一時的に無効化する場合：

```bash
# サービス停止
sudo systemctl stop minecraft-autoshutdown.service

# 自動起動を無効化
sudo systemctl disable minecraft-autoshutdown.service
```

再度有効化する場合：

```bash
sudo systemctl enable minecraft-autoshutdown.service
sudo systemctl start minecraft-autoshutdown.service
```

## まとめ

### 改良点
- ✅ `joined the game` / `left the game` イベントを追跡
- ✅ プレイヤーごとに状態を管理
- ✅ 正確なプレイヤー数判定
- ✅ 詳細なログ出力
- ✅ 5分ごとの進捗表示

### 動作確認済み
- ✅ ローカルログでテスト成功
- ✅ プレイヤー参加/退出を正確に追跡
- ✅ 全員退出時に正しく判定

デプロイ後、実際のサーバーで動作確認してください。
