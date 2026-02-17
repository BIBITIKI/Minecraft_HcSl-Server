# Discord Webhook設定手順

## 概要

自動停止通知を `server-status` チャンネルに投稿するため、Discord Webhookを設定します。

## 手順

### 1. Discord Webhookを作成

1. Discordで `server-status` チャンネルを開く
2. チャンネル設定（⚙️）→ 連携サービス → Webhooks
3. 「新しいウェブフック」をクリック
4. 名前を設定（例: `Minecraft Server`）
5. アイコンを設定（オプション）
6. 「ウェブフックURLをコピー」をクリック

出力例:
```
https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz
```

### 2. Terraform変数に追加

`terraform.tfvars` に以下を追加:

```hcl
discord_webhook_url = "https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz"
```

### 3. Terraformで再デプロイ

```powershell
cd Minecraft_HcSl-Server\aws-deploy\terraform
terraform apply
```

これで、EC2インスタンスの `user-data.sh` が更新され、次回起動時から自動停止通知が `server-status` チャンネルに投稿されます。

### 4. 既存のサーバーに反映（オプション）

既に起動中のサーバーに反映する場合:

```bash
# SSM Session Managerで接続
aws ssm start-session --target i-0b3b312b21a19f71b

# 環境変数を更新
sudo systemctl stop minecraft-autoshutdown
sudo sed -i 's|DISCORD_WEBHOOK_URL=.*|DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"|' /etc/systemd/system/minecraft-autoshutdown.service
sudo systemctl daemon-reload
sudo systemctl start minecraft-autoshutdown
```

## 確認方法

1. サーバーを起動: `/start`
2. 15分待つ（誰も参加しない）
3. `server-status` チャンネルに自動停止通知が投稿されることを確認

## トラブルシューティング

### 通知が投稿されない

1. Webhook URLが正しいか確認
2. auto-shutdown.shのログを確認:
   ```bash
   sudo tail -f /var/log/minecraft-autoshutdown.log
   ```

3. Webhook URLが環境変数に設定されているか確認:
   ```bash
   sudo systemctl show minecraft-autoshutdown | grep DISCORD_WEBHOOK_URL
   ```

### Webhook URLが間違っている

1. Discordで新しいWebhookを作成
2. `terraform.tfvars` を更新
3. `terraform apply` で再デプロイ

## セキュリティ

- Webhook URLは秘密情報です。GitHubにコミットしないでください
- `terraform.tfvars` は `.gitignore` に追加してください
- Webhook URLが漏洩した場合は、Discordで削除して新しいものを作成してください

## 現在の設定

現在の `discord_webhook_url` は `terraform.tfvars` で確認できます:

```powershell
cd Minecraft_HcSl-Server\aws-deploy\terraform
cat terraform.tfvars | Select-String "discord_webhook_url"
```
