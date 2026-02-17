# Railway.app URL確認手順

## 問題
自動停止通知が`server-status`チャンネルではなく、別のチャンネルに表示されている。
Railway.appのログに`/notify`エンドポイントのログが表示されていない。

## 原因
Lambda関数の環境変数`DISCORD_BOT_URL`が正しくない可能性がある。

## 確認手順

### 1. Railway.appのURLを確認
1. Railway.appのダッシュボードにアクセス
2. `Node-File-System`プロジェクトを選択
3. `Settings` → `Domains`を確認
4. 表示されているURLをコピー（例: `https://node-file-system-production-xxxx.up.railway.app`）

### 2. Lambda関数の環境変数を更新

現在の設定:
```
DISCORD_BOT_URL=https://minecraft-discord-bot-production.up.railway.app
```

正しいURLに更新する必要があります。

### 3. 更新コマンド

```powershell
# Railway.appの正しいURLを確認後、以下のコマンドを実行
aws lambda update-function-configuration `
  --function-name minecraft-notify-discord `
  --environment "Variables={DISCORD_BOT_URL=https://YOUR_CORRECT_RAILWAY_URL.up.railway.app}" `
  --region ap-northeast-1
```

### 4. テスト

サーバーを起動して、2分間プレイヤーなしで待機し、自動停止通知が`server-status`チャンネルに表示されるか確認。

## 代替案: Webhookを使用

もし上記の方法で解決しない場合は、Discord Webhookを直接使用する方法もあります:

1. Discord `server-status`チャンネルの設定 → Webhooks → 新しいWebhook作成
2. Webhook URLをコピー
3. `auto-shutdown.sh`を修正して、Webhookに直接送信

この方法の方がシンプルで確実です。
