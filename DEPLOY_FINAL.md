# 最終デプロイガイド

## 構成概要

### インフラ
- **EC2**: t3a.medium（vCPU: 2, メモリ: 4GB）
- **EBS**: 20GB gp3
- **月額コスト**: 約1,920円（稼働時間により変動）

### 自動停止機能
1. **深夜3時（JST）**: EventBridgeで自動停止
2. **Discord経由**: `/serverstop` コマンドで停止
3. **プレイヤー不在**: 15分間誰もいない場合に自動停止

### 起動方法
- **Discord経由**: `/serverstart` コマンド
- サーバーIPが自動的にDiscordに通知される

## デプロイ手順

### ステップ1: Terraform初期化

```powershell
cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy\terraform
terraform init
```

### ステップ2: 設定確認

`terraform.tfvars`の内容を確認：

```hcl
aws_region = "ap-northeast-1"
instance_type = "t3a.medium"
ebs_volume_size = 20
key_pair_name = "minecraft-server-key"
ssh_cidr = "0.0.0.0/0"
minecraft_memory = 3072
discord_webhook_url = ""  # 後で設定
```

### ステップ3: インフラ構築

```powershell
terraform plan
terraform apply
```

`yes` と入力して実行

### ステップ4: 出力情報を確認

```powershell
terraform output
```

以下の情報をメモ：
- `instance_public_ip`: EC2のPublic IP
- `lambda_start_url`: サーバー起動用URL
- `lambda_stop_url`: サーバー停止用URL

### ステップ5: サーバーファイルをアップロード

```powershell
$PUBLIC_IP = terraform output -raw instance_public_ip

scp -i C:\Kiro\minecraft-server-key.pem -r C:\Kiro\Minecraft_HcSl-Server\* ec2-user@${PUBLIC_IP}:/home/ec2-user/minecraft-server/
```

**注意**: 初回接続時に fingerprint の確認が表示されたら `yes` と入力

### ステップ6: EC2にSSH接続

```powershell
ssh -i C:\Kiro\minecraft-server-key.pem ec2-user@$PUBLIC_IP
```

### ステップ7: サーバーファイルを配置

```bash
# サーバーファイルを正しい場所に移動
sudo cp -r /home/ec2-user/minecraft-server/* /minecraft/server/

# 権限設定
sudo chown -R root:root /minecraft/server

# ファイル確認
ls -la /minecraft/server/
```

以下のファイルがあることを確認：
- server.jar（Forge 1.20.1）
- eula.txt
- server.properties
- mods/（MODファイル）
- world/（ワールドデータ）

### ステップ8: Minecraftサーバー起動

```bash
# サービス起動
sudo systemctl start minecraft.service

# ログ確認
sudo journalctl -u minecraft.service -f
```

「Done」と表示されたら起動完了（Ctrl+Cで終了）

### ステップ9: 自動停止監視を起動

```bash
# 自動停止サービス起動
sudo systemctl start minecraft-autoshutdown.service

# 状態確認
sudo systemctl status minecraft-autoshutdown.service

# ログ確認
sudo tail -f /var/log/minecraft-autoshutdown.log
```

### ステップ10: 動作確認

Minecraftクライアントで接続：
- サーバーアドレス: `$PUBLIC_IP:25565`

### ステップ11: Discord Webhook設定（オプション）

1. Discord Webhookを作成（`DISCORD_SETUP.md`参照）
2. `terraform.tfvars`に追加：
   ```hcl
   discord_webhook_url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
   ```
3. Terraformを再適用：
   ```powershell
   terraform apply
   ```

### ステップ12: Discord Bot設定（オプション）

詳細は `DISCORD_SETUP.md` を参照

## 運用コマンド

### サーバー状態確認

```bash
# EC2にSSH接続
ssh -i C:\Kiro\minecraft-server-key.pem ec2-user@$PUBLIC_IP

# サービス状態
sudo systemctl status minecraft.service

# ログ確認
sudo journalctl -u minecraft.service -f
```

### 手動停止

```bash
# Minecraftサーバー停止
sudo systemctl stop minecraft.service

# EC2インスタンス停止（ローカルから）
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)
```

### 手動起動

```powershell
# EC2インスタンス起動
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Public IP確認（起動後）
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id) --query 'Reservations[0].Instances[0].PublicIpAddress'
```

## トラブルシューティング

### サーバーが起動しない

```bash
# ログ確認
sudo journalctl -u minecraft.service -n 100

# server.jarが存在するか確認
ls -la /minecraft/server/server.jar

# Java確認
java -version
```

### メモリ不足エラー

user-data.shのメモリ設定を確認：
```bash
cat /minecraft/launch.sh
```

### 自動停止が動作しない

```bash
# 自動停止サービス確認
sudo systemctl status minecraft-autoshutdown.service

# ログ確認
sudo tail -f /var/log/minecraft-autoshutdown.log

# IAMロール確認
aws sts get-caller-identity
```

### SSH接続できない

```powershell
# セキュリティグループ確認
aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id)

# キーペアのパス確認
ls C:\Kiro\minecraft-server-key.pem
```

## コスト管理

### 月額コスト概算

**常時稼働の場合:**
- EC2 t3a.medium: 約1,920円/月
- EBS 20GB: 約192円/月
- **合計**: 約2,112円/月

**1日8時間稼働の場合:**
- EC2 t3a.medium: 約640円/月
- EBS 20GB: 約192円/月
- **合計**: 約832円/月

### コスト確認

```powershell
# AWS Cost Explorer（ブラウザ）
# AWS Console → Billing → Cost Explorer

# CLI
aws ce get-cost-and-usage --time-period Start=2026-02-01,End=2026-02-28 --granularity MONTHLY --metrics BlendedCost
```

## バックアップ

### 手動バックアップ

```bash
# ワールドデータをバックアップ
sudo tar -czf /home/ec2-user/minecraft-backup-$(date +%Y%m%d).tar.gz /minecraft/server/world

# ローカルにダウンロード
scp -i C:\Kiro\minecraft-server-key.pem ec2-user@$PUBLIC_IP:/home/ec2-user/minecraft-backup-*.tar.gz C:\Kiro\backups\
```

### 自動バックアップ（S3）

別途設定が必要（オプション）

## クリーンアップ（削除）

すべてのリソースを削除する場合：

```powershell
cd C:\Kiro\Minecraft_HcSl-Server\aws-deploy\terraform
terraform destroy
```

`yes` と入力して実行

## 次のステップ

1. ✅ インフラ構築
2. ✅ サーバーファイルアップロード
3. ✅ Minecraftサーバー起動
4. ⬜ Discord Webhook設定
5. ⬜ Discord Bot設定
6. ⬜ 動作確認

詳細は各ドキュメントを参照：
- `DISCORD_SETUP.md` - Discord連携
- `COST_OPTIMIZATION.md` - コスト最適化
- `QUICK_START.md` - クイックスタート
