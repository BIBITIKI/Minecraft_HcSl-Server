# Discord Webhook設定ガイド

## 概要

自動停止通知を`server-status`チャンネルに正しく表示するため、Discord Webhookを使用する方法に変更しました。

## 変更内容

### 以前の方法（問題あり）
```
auto-shutdown.sh → Lambda notify_discord → Railway.app Bot → Discord
```
- Railway.appのURLが正しく設定されていない可能性
- 複雑な経路で通知が届かない

### 新しい方法（シンプル）
```
auto-shutdown.sh → Discord Webhook → server-status チャンネル
```
- 直接Discordに通知を送信
- シンプルで確実

## セットアップ手順

### 1. Discord Webhookを作成

1. Discordで`server-status`チャンネルを開く
2. チャンネル設定（歯車アイコン）→ 連携サービス → Webhooks
3. 「新しいWebhook」をクリック
4. 名前を「Minecraft Auto-Shutdown」に変更
5. 「Webhook URLをコピー」をクリック

Webhook URLの形式:
```
https://discord.com/api/webhooks/1234567890/ABCDEFGHIJKLMNOPQRSTUVWXYZ
```

### 2. Webhook URLをSSM Parameter Storeに保存

```powershell
cd Minecraft_HcSl-Server/aws-deploy
.\setup-discord-webhook.ps1
```

プロンプトが表示されたら、コピーしたWebhook URLを貼り付けてください。

### 3. auto-shutdown.shをEC2にデプロイ

```powershell
.\update-autoshutdown-webhook.ps1
```

このスクリプトは以下を実行します:
- 更新された`auto-shutdown.sh`をEC2にアップロード
- サービスを再起動
- 起動状態を確認

### 4. テスト

1. サーバーを起動: `/start`
2. 2分間プレイヤーなしで待機
3. 自動停止通知が`server-status`チャンネルに表示されることを確認

## トラブルシューティング

### 通知が表示されない場合

1. **Webhook URLが正しいか確認**
   ```powershell
   aws ssm get-parameter --name "/minecraft/i-0b3b312b21a19f71b/discord_webhook" --region ap-northeast-1 --with-decryption --query 'Parameter.Value' --output text
   ```

2. **サービスが起動しているか確認**
   ```powershell
   aws ssm send-command --instance-ids i-0b3b312b21a19f71b --document-name "AWS-RunShellScript" --parameters 'commands=["sudo systemctl status minecraft-autoshutdown.service --no-pager"]' --region ap-northeast-1
   ```

3. **ログを確認**
   ```powershell
   aws ssm send-command --instance-ids i-0b3b312b21a19f71b --document-name "AWS-RunShellScript" --parameters 'commands=["tail -n 50 /var/log/minecraft-autoshutdown.log"]' --region ap-northeast-1
   ```

### Webhook URLを変更する場合

1. Discordで新しいWebhookを作成
2. `setup-discord-webhook.ps1`を再実行
3. `update-autoshutdown-webhook.ps1`でサービスを再起動（不要ですが、念のため）

## 技術詳細

### auto-shutdown.shの変更点

```bash
# 以前: Lambda経由で通知
NOTIFY_URL="https://mf71h6a5f9.execute-api.ap-northeast-1.amazonaws.com/prod/notify?message=${encoded_message}&channel=status"
curl -s "$NOTIFY_URL"

# 新しい: Webhook経由で通知
WEBHOOK_URL=$(aws ssm get-parameter --name "/minecraft/${INSTANCE_ID}/discord_webhook" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
json_payload='{"content": "'"$message"'"}'
curl -s -H "Content-Type: application/json" -X POST -d "$json_payload" "$WEBHOOK_URL"
```

### IAMポリシーの変更

EC2インスタンスロールに以下の権限を追加:
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters"
  ],
  "Resource": "arn:aws:ssm:ap-northeast-1:*:parameter/minecraft/*"
}
```

## メリット

1. **シンプル**: Lambda関数やRailway.app Botを経由しない
2. **確実**: Discord Webhookは公式機能で安定
3. **デバッグしやすい**: ログで直接確認可能
4. **コスト削減**: Lambda呼び出しが1回減る

## 注意事項

- Webhook URLは秘密情報です。SSM Parameter Storeに`SecureString`として保存されます
- Webhook URLを変更した場合は、SSM Parameter Storeを更新してください
- サーバーが停止中の場合、次回起動時に新しいWebhook URLが反映されます
